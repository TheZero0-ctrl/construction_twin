# frozen_string_literal: true

require "fileutils"
require "open3"
require "tempfile"
require "tmpdir"

class ProcessDatasetJob < ApplicationJob
  SHAPEFILE_ARCHIVE_EXTENSIONS = %w[.shp .shx .dbf .prj .cpg .sbn .sbx .qix .txt].freeze

  def perform(dataset)
    dataset.update!(status: :processing)
    layer = ensure_buildings_layer!(dataset)
    layer.update!(status: :processing, last_error: nil)

    imported_count = import_shapefile!(dataset)
    dataset.update_info_message!("Import completed. #{imported_count} building features were loaded. 3D tile generation started.")
    dataset.update!(status: :completed)
    layer.update!(status: :pending)
    Generate3dTilesJob.perform_later(dataset.id)
  rescue StandardError => error
    dataset.map_layer&.update!(status: :failed, last_error: error.message)
    dataset.update!(status: :failed, info: failure_info(dataset, error)) if dataset&.persisted?
    raise
  end

  private

  def failure_info(dataset, error)
    current_info = dataset.info.is_a?(Hash) ? dataset.info : {}
    current_info.merge("message" => error.message)
  end

  def import_shapefile!(dataset)
    raise ArgumentError, "Dataset file is missing" unless dataset.file.attached?
    raise ArgumentError, "Unsupported dataset type: #{dataset.data_type}" unless dataset.shapefile?

    dataset.buildings.delete_all
    import_table_name = staging_table_name(dataset)
    extract_dir = Dir.mktmpdir("dataset-extract-#{dataset.id}-")
    temp_zip = Tempfile.new([ "dataset-upload-#{dataset.id}-", ".zip" ])
    temp_zip.binmode

    dataset.file.download { |chunk| temp_zip.write(chunk) }
    temp_zip.rewind

    extraction_result = ZipExtractor
      .new(zip_path: temp_zip.path, destination: extract_dir)
      .extract(allowed_extensions: SHAPEFILE_ARCHIVE_EXTENSIONS)

    raise "Failed to unpack dataset archive: #{extraction_result[:error]}" unless extraction_result[:success]

    shapefile_path = locate_shapefile!(extract_dir)
    import_to_staging!(shapefile_path, import_table_name, connection_config)

    imported_count = move_staged_buildings!(dataset)
    update_buildings_layer_name!(dataset, shapefile_path)
    imported_count
  ensure
    temp_zip&.close
    temp_zip&.unlink
    drop_staging_table!(import_table_name) if import_table_name.present?
    FileUtils.rm_rf(extract_dir) if extract_dir.present?
  end

  def locate_shapefile!(extract_dir)
    shapefile_path = Dir.glob(File.join(extract_dir, "**", "*.shp"), File::FNM_CASEFOLD).first
    return shapefile_path if shapefile_path.present?

    raise "No .shp file found inside uploaded archive"
  end

  def ensure_buildings_layer!(dataset)
    layer = dataset.map_layer || dataset.build_map_layer(layer_type: :buildings)
    layer.project = dataset.project
    layer.source = :postgis
    layer.visible = true
    layer.status = :pending
    layer.name = dataset.file.filename.base if layer.name.blank? && dataset.file.attached?
    layer.save!
    layer
  end

  def update_buildings_layer_name!(dataset, shapefile_path)
    ensure_buildings_layer!(dataset).update!(name: File.basename(shapefile_path, ".*"))
  end

  def import_to_staging!(shapefile_path, staging_table, pg_config)
    drop_staging_table!(staging_table)

    stdout, stderr, status = Open3.capture3(
      pg_env(pg_config),
      "ogr2ogr",
      "-f", "PostgreSQL",
      "PG:",
      shapefile_path,
      "-nln", staging_table,
      "-lco", "GEOMETRY_NAME=geom",
      "-nlt", "PROMOTE_TO_MULTI",
      "-t_srs", "EPSG:4326",
      "-overwrite"
    )
    return if status.success?

    raise "Failed to import shapefile with ogr2ogr: #{stderr.presence || stdout}"
  end

  def move_staged_buildings!(dataset)
    table = staging_table_name(dataset)
    name_expr = column_expression(table, %w[name Name NAME])
    height_expr = column_expression(table, %w[height Height HEIGHT elev ELEV z Z], cast: "numeric")
    base_height_expr = column_expression(table, %w[base_height BaseHeight BASE_HEIGHT base_z BaseZ BASE_Z], cast: "numeric")

    connection = ActiveRecord::Base.connection
    now = Time.current
    insert_sql = <<~SQL
      INSERT INTO buildings (project_id, dataset_id, name, height, base_height, geom, created_at, updated_at)
      SELECT
        $1,
        $2,
        #{name_expr},
        GREATEST(COALESCE(#{height_expr}, #{Dataset::DEFAULT_FOOTPRINT_HEIGHT_METERS}), 0.1),
        GREATEST(COALESCE(#{base_height_expr}, 0), 0),
        ST_Multi(
          ST_Translate(
            ST_Force3DZ(geom),
            0,
            0,
            GREATEST(COALESCE(#{base_height_expr}, 0), 0)
          )
        )::geometry(MultiPolygonZ, 4326),
        $3,
        $4
      FROM #{connection.quote_table_name(table)}
      WHERE geom IS NOT NULL
      AND ST_IsValid(geom)
      AND GeometryType(geom) IN ('POLYGON', 'MULTIPOLYGON')
    SQL

    # brakeman:ignore[SQL] Safe: table/columns are constrained and quoted, values are bound parameters.
    connection.exec_insert(insert_sql, "Insert buildings from staged shapefile", [
      ActiveRecord::Relation::QueryAttribute.new("project_id", dataset.project_id.to_i, ActiveRecord::Type::Integer.new),
      ActiveRecord::Relation::QueryAttribute.new("dataset_id", dataset.id.to_i, ActiveRecord::Type::Integer.new),
      ActiveRecord::Relation::QueryAttribute.new("created_at", now, ActiveRecord::Type::DateTime.new),
      ActiveRecord::Relation::QueryAttribute.new("updated_at", now, ActiveRecord::Type::DateTime.new)
    ])
    dataset.buildings.count
  end

  def column_expression(table, candidates, cast: nil)
    conn = ActiveRecord::Base.connection
    columns = conn.columns(table).map(&:name)
    selected = candidates.find { |candidate| columns.include?(candidate) }
    return "NULL" unless selected

    quoted_column = conn.quote_column_name(selected)
    if cast.present?
      return <<~SQL.squish
        CASE
          WHEN NULLIF(#{quoted_column}::text, '') ~ '^-?\\d+(\\.\\d+)?$'
          THEN NULLIF(#{quoted_column}::text, '')::#{cast}
          ELSE NULL
        END
      SQL
    end

    "NULLIF(#{quoted_column}::text, '')"
  end

  def drop_staging_table!(table_name)
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{ActiveRecord::Base.connection.quote_table_name(table_name)}")
  end

  def staging_table_name(dataset)
    "dataset_import_#{dataset.id}"
  end

  def connection_config
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: config[:host].presence || ENV.fetch("PGHOST", "localhost"),
      port: config[:port].presence || ENV.fetch("PGPORT", "5432"),
      dbname: config[:database],
      user: config[:username].presence || ENV["PGUSER"],
      password: config[:password].presence || ENV["PGPASSWORD"]
    }.compact.transform_values(&:to_s)
  end

  def pg_env(config)
    {
      "PGHOST" => config.fetch(:host, "localhost"),
      "PGPORT" => config.fetch(:port, "5432"),
      "PGDATABASE" => config.fetch(:dbname, ""),
      "PGUSER" => config[:user],
      "PGPASSWORD" => config[:password]
    }.compact
  end
end
