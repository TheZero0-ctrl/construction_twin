# frozen_string_literal: true

require "fileutils"
require "open3"
require "securerandom"

class TilesetExporter
  def initialize(map_layer)
    @map_layer = map_layer
    @dataset = map_layer.dataset
    @project = map_layer.project
    @connection = ActiveRecord::Base.connection
  end

  def export!
    revision = Time.current.utc.strftime("%Y%m%d%H%M%S")
    export_table = export_table_name(revision)
    output_dir = output_directory(revision)
    artifact = create_processing_artifact!(output_dir)

    create_export_table!(export_table)
    run_pg2b3dm!(export_table, output_dir)

    tileset_path = locate_tileset_path(output_dir)

    activate_artifact!(artifact, tileset_path, revision)
  rescue StandardError => error
    artifact&.update!(status: :failed, error_message: error.message)
    raise
  ensure
    drop_export_table!(export_table) if export_table.present?
  end

  private

  attr_reader :map_layer, :dataset, :project, :connection

  def output_directory(revision)
    directory = Rails.root.join("public", "tilesets", "projects", project.id.to_s, "layers", map_layer.id.to_s, "revisions", revision)
    FileUtils.mkdir_p(directory)
    directory
  end

  def create_processing_artifact!(output_dir)
    map_layer.layer_artifacts.create!(
      format: :tiles_3d,
      status: :processing,
      storage_path: relative_public_path(output_dir.join("tileset.json")),
      public_url: relative_public_path(output_dir.join("tileset.json")),
      active: false,
      metadata: {}
    )
  end

  def activate_artifact!(artifact, tileset_path, revision)
    LayerArtifact.transaction do
      map_layer.layer_artifacts.where(format: :tiles_3d, active: true).update_all(active: false)

      artifact.update!(
        status: :ready,
        active: true,
        storage_path: relative_public_path(tileset_path),
        public_url: relative_public_path(tileset_path),
        generated_at: Time.current,
        metadata: {
          "feature_count" => dataset.buildings.count,
          "revision" => revision
        }
      )
    end
  end

  def export_table_name(revision)
    "layer_export_#{map_layer.id}_#{revision}_#{SecureRandom.hex(4)}"
  end

  def create_export_table!(table_name)
    quoted_table = connection.quote_table_name(table_name)
    geometry_expression = extrusion_sql

    connection.execute(<<~SQL)
      CREATE TABLE #{quoted_table} AS
      SELECT
        b.id,
        b.name,
        b.height,
        b.base_height,
        #{geometry_expression} AS geom_tile
      FROM buildings b
      WHERE b.dataset_id = #{dataset.id.to_i}
      AND b.geom IS NOT NULL
      AND ST_IsValid(b.geom)
    SQL

    connection.execute("CREATE INDEX #{connection.quote_table_name("idx_#{table_name}_geom_tile")} ON #{quoted_table} USING gist(ST_Centroid(ST_Envelope(geom_tile)))")

    row_count = connection.select_value("SELECT COUNT(*) FROM #{quoted_table}").to_i
    raise "No valid 3D features available for tile generation" if row_count.zero?
  end

  def drop_export_table!(table_name)
    connection.execute("DROP TABLE IF EXISTS #{connection.quote_table_name(table_name)}")
  end

  def extrusion_sql
    if sfcgal_enabled?
      <<~SQL.squish
        ST_Multi(
          ST_CollectionExtract(
            ST_Force3DZ(
              CG_Extrude(
                ST_CollectionExtract(ST_Force3DZ(b.geom), 3),
                0,
                0,
                GREATEST(COALESCE(b.height, #{Dataset::DEFAULT_FOOTPRINT_HEIGHT_METERS})::double precision, 0.1)
              )
            ),
            3
          )
        )::geometry(MultiPolygonZ, 4326)
      SQL
    else
      <<~SQL.squish
        ST_Multi(
          ST_Translate(
            ST_CollectionExtract(ST_Force3DZ(b.geom), 3),
            0,
            0,
            GREATEST(COALESCE(b.height, #{Dataset::DEFAULT_FOOTPRINT_HEIGHT_METERS})::double precision, 0.1)
          )
        )::geometry(MultiPolygonZ, 4326)
      SQL
    end
  end

  def run_pg2b3dm!(table_name, output_dir)
    cfg = connection_config
    output_root = Rails.root.join("public", "tilesets")
    output_inside_container = "/tilesets/#{output_dir.relative_path_from(output_root)}"
    connection = docker_connection_config(cfg)

    command = [
      "docker",
      "run",
      "--rm",
      "--add-host", "host.docker.internal:host-gateway",
      "-v", "#{output_root}:/tilesets",
      "--network", docker_network_mode,
      *docker_env_args(connection),
      docker_image,
      "--host", connection.fetch(:host, "localhost"),
      "--port", connection.fetch(:port, "5432"),
      "--dbname", connection.fetch(:dbname, ""),
      *(connection[:user].present? ? [ "--username", connection[:user] ] : []),
      "--table", table_name,
      "--column", "geom_tile",
      "--attributecolumns", "id,name,height,base_height",
      "--subdivision", "QUADTREE",
      "--output", output_inside_container
    ]

    stdout, stderr, status = Open3.capture3(*command)
    combined_output = [ stderr, stdout ].compact.join("\n")
    if status.success? && combined_output.exclude?("ERROR(S):")
      return
    end

    raise "pg2b3dm docker run failed: #{combined_output.presence || 'Unknown converter error'}"
  end

  def sfcgal_enabled?
    connection.select_value("SELECT extname FROM pg_extension WHERE extname = 'postgis_sfcgal'").present?
  end

  def docker_image
    ENV.fetch("PG2B3DM_DOCKER_IMAGE", "geodan/pg2b3dm:latest")
  end

  def docker_network_mode
    ENV.fetch("PG2B3DM_DOCKER_NETWORK", "host")
  end

  def docker_connection_config(config)
    return config if docker_network_mode == "host"

    host = config.fetch(:host, "localhost")
    if %w[localhost 127.0.0.1 ::1].include?(host)
      config.merge(host: "host.docker.internal")
    else
      config
    end
  end

  def relative_public_path(path)
    "/#{path.relative_path_from(Rails.root.join("public"))}"
  end

  def locate_tileset_path(output_dir)
    candidates = [
      output_dir.join("tileset.json"),
      output_dir.join("content", "tileset.json")
    ]

    tileset_path = candidates.find(&:exist?)
    return tileset_path if tileset_path

    raise "pg2b3dm completed but tileset.json is missing"
  end

  def connection_config
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: config[:host].presence || ENV.fetch("PGHOST", "localhost"),
      port: config[:port].presence || ENV.fetch("PGPORT", "5432"),
      dbname: config[:database],
      user: config[:username].presence || ENV["PGUSER"].presence || ENV["USER"].presence,
      password: config[:password].presence || ENV["PGPASSWORD"]
    }.compact.transform_values(&:to_s)
  end

  def docker_env_args(config)
    return [] unless config[:password].present?

    [ "-e", "PGPASSWORD=#{config[:password]}" ]
  end
end
