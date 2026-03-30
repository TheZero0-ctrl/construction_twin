# frozen_string_literal: true

require "fileutils"
require "open3"
require "securerandom"

class TilesetExporter
  SUPPORTED_LAYER_TYPES = %w[buildings terrain roads].freeze
  SAFE_SQL_IDENTIFIER = /\A[a-z][a-z0-9_]*\z/
  SAFE_DOCKER_IMAGE = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*(?:\/[a-z0-9]+(?:[._-][a-z0-9]+)*)*(?::[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?(?:@sha256:[a-f0-9]{64})?\z/i
  SAFE_DOCKER_NETWORK = /\A[a-zA-Z0-9][a-zA-Z0-9_.:-]*\z/
  SAFE_COMMAND_ARGUMENT = /\A[^\x00\n\r]+\z/

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
          "feature_count" => source_feature_count,
          "revision" => revision
        }
      )
    end
  end

  def export_table_name(revision)
    "layer_export_#{map_layer.id}_#{revision}_#{SecureRandom.hex(4)}"
  end

  def create_export_table!(table_name)
    validated_table_name = validated_sql_identifier(table_name, label: "export table")
    quoted_table = connection.quote_table_name(validated_table_name)
    source_table = connection.quote_table_name(validated_source_feature_table)
    geometry_expression = extrusion_sql
    layer_type_literal = connection.quote(validated_layer_type)
    dataset_id = Integer(dataset.id)

    connection.execute(<<~SQL)
      CREATE TABLE #{quoted_table} AS
      SELECT
        f.id,
        f.name,
        f.height,
        f.base_height,
        #{layer_type_literal}::text AS layer_type,
        #{geometry_expression} AS geom_tile
      FROM #{source_table} f
      WHERE f.dataset_id = #{dataset_id}
      AND f.geom IS NOT NULL
      AND ST_IsValid(f.geom)
    SQL

    index_name = validated_sql_identifier("idx_#{validated_table_name}_geom_tile", label: "export index")
    connection.execute("CREATE INDEX #{connection.quote_table_name(index_name)} ON #{quoted_table} USING gist(ST_Centroid(ST_Envelope(geom_tile)))")

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
                ST_CollectionExtract(ST_Force3DZ(f.geom), 3),
                0,
                0,
                GREATEST(COALESCE(f.height, #{default_height})::double precision, 0.1)
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
            ST_CollectionExtract(ST_Force3DZ(f.geom), 3),
            0,
            0,
            GREATEST(COALESCE(f.height, #{default_height})::double precision, 0.1)
          )
        )::geometry(MultiPolygonZ, 4326)
      SQL
    end
  end

  def run_pg2b3dm!(table_name, output_dir)
    cfg = connection_config
    output_root = Rails.root.join("public", "tilesets")
    output_inside_container = "/tilesets/#{output_dir.relative_path_from(output_root)}"
    docker_cfg = docker_connection_config(cfg)

    command = [
      "docker",
      "run",
      "--rm",
      "--add-host", "host.docker.internal:host-gateway",
      "-v", validated_volume_mapping(output_root),
      "--network", validated_docker_network_mode,
      *docker_env_args(docker_cfg),
      validated_docker_image,
      "--host", validated_command_argument(docker_cfg.fetch(:host, "localhost"), label: "docker host"),
      "--port", validated_port(docker_cfg.fetch(:port, "5432")),
      "--dbname", validated_command_argument(docker_cfg.fetch(:dbname, ""), allow_blank: true, label: "database name"),
      *(docker_cfg[:user].present? ? [ "--username", validated_command_argument(docker_cfg[:user], label: "database user") ] : []),
      "--table", validated_sql_identifier(table_name, label: "export table"),
      "--column", "geom_tile",
      "--attributecolumns", "id,name,height,base_height,layer_type",
      "--subdivision", "QUADTREE",
      "--output", validated_container_output_path(output_inside_container)
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
    return config if validated_docker_network_mode == "host"

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

    [ "-e", "PGPASSWORD=#{validated_command_argument(config[:password], label: 'database password')}" ]
  end

  def validated_layer_type
    layer_type = map_layer.layer_type.to_s
    return layer_type if SUPPORTED_LAYER_TYPES.include?(layer_type)

    raise ArgumentError, "Unsupported layer type for tiles export: #{layer_type}"
  end

  def validated_source_feature_table
    validated_sql_identifier(source_feature_table, label: "source feature table")
  end

  def validated_sql_identifier(value, label: "SQL identifier")
    identifier = value.to_s
    return identifier if identifier.match?(SAFE_SQL_IDENTIFIER)

    raise ArgumentError, "Unsafe #{label}: #{value.inspect}"
  end

  def validated_docker_image
    image = docker_image.to_s
    return image if image.match?(SAFE_DOCKER_IMAGE)

    raise ArgumentError, "Unsafe docker image: #{docker_image.inspect}"
  end

  def validated_docker_network_mode
    network = docker_network_mode.to_s
    return network if network.match?(SAFE_DOCKER_NETWORK)

    raise ArgumentError, "Unsafe docker network: #{docker_network_mode.inspect}"
  end

  def validated_volume_mapping(output_root)
    "#{validated_command_argument(output_root.to_s, label: 'tileset output root')}:/tilesets"
  end

  def validated_container_output_path(path)
    normalized_path = validated_command_argument(path, label: "tileset output path")
    return normalized_path if normalized_path.start_with?("/tilesets/")

    raise ArgumentError, "Unsafe tileset output path: #{path.inspect}"
  end

  def validated_port(value)
    port = value.to_s
    return port if port.match?(/\A\d{1,5}\z/)

    raise ArgumentError, "Unsafe database port: #{value.inspect}"
  end

  def validated_command_argument(value, allow_blank: false, label: "command argument")
    argument = value.to_s
    return argument if allow_blank && argument.empty?
    return argument if argument.match?(SAFE_COMMAND_ARGUMENT)

    raise ArgumentError, "Unsafe #{label}: #{value.inspect}"
  end

  def source_feature_table
    case validated_layer_type
    when "buildings"
      "buildings"
    when "terrain"
      "terrains"
    when "roads"
      "roads"
    else
      raise "Unsupported layer type for tiles export: #{map_layer.layer_type}"
    end
  end

  def source_feature_count
    dataset.public_send(source_feature_table).count
  end

  def default_height
    Dataset.default_height_for(map_layer.layer_type)
  end
end
