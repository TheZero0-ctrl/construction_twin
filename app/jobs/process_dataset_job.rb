# frozen_string_literal: true

require "fileutils"
require "open3"
require "tempfile"
require "tmpdir"

class ProcessDatasetJob < ApplicationJob
  SHAPEFILE_ARCHIVE_EXTENSIONS = %w[.shp .shx .dbf .prj .cpg .sbn .sbx .qix .txt].freeze
  FEATURE_TABLES = {
    "buildings" => "buildings",
    "terrain" => "terrains",
    "roads" => "roads"
  }.freeze
  FEATURE_ASSOCIATIONS = {
    "buildings" => :buildings,
    "terrain" => :terrains,
    "roads" => :roads
  }.freeze
  SAFE_SQL_IDENTIFIER = /\A[a-z][a-z0-9_]*\z/

  def perform(dataset_id)
    dataset = Dataset.find_by(id: dataset_id)
    return unless dataset

    dataset.update!(status: :processing)
    layer = ensure_layer!(dataset)
    layer.update!(status: :processing, last_error: nil)

    imported_count = import_shapefile!(dataset)
    dataset.update_info_message!("Import completed. #{imported_count} features were loaded. 3D tile generation started.")
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

    dataset.public_send(feature_association_for(dataset.layer_type)).delete_all
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

    imported_count = move_staged_features!(dataset)
    update_layer_name!(dataset, shapefile_path)
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

  def ensure_layer!(dataset)
    layer = dataset.map_layer || dataset.build_map_layer(layer_type: dataset.layer_type)
    layer.project = dataset.project
    layer.layer_type = dataset.layer_type
    layer.source = :postgis
    layer.visible = true
    layer.status = :pending
    layer.name = dataset.file.filename.base if layer.name.blank? && dataset.file.attached?
    layer.save!
    layer
  end

  def update_layer_name!(dataset, shapefile_path)
    ensure_layer!(dataset).update!(name: File.basename(shapefile_path, ".*"))
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

  def move_staged_features!(dataset)
    quoted_staging_table = quoted_staging_table_name(dataset)
    quoted_target_table = quoted_feature_table_name(dataset.layer_type)
    name_expr = column_expression_for(dataset, %w[name Name NAME])
    height_expr = column_expression_for(dataset, %w[height Height HEIGHT elev ELEV z Z], cast: "numeric")
    base_height_expr = column_expression_for(dataset, %w[base_height BaseHeight BASE_HEIGHT base_z BaseZ BASE_Z], cast: "numeric")
    default_height = Float(Dataset.default_height_for(dataset.layer_type))
    source_geom_expr = validated_source_geometry_expression(dataset.layer_type)
    source_geom_filter = validated_source_geometry_filter(dataset.layer_type)

    connection = ActiveRecord::Base.connection
    now = Time.current
    insert_sql = <<~SQL
      INSERT INTO #{quoted_target_table} (project_id, dataset_id, name, height, base_height, geom, created_at, updated_at)
      SELECT
        $1,
        $2,
        #{name_expr},
        GREATEST(COALESCE(#{height_expr}, #{default_height}), 0.1),
        GREATEST(COALESCE(#{base_height_expr}, 0), 0),
        ST_Multi(
          ST_Translate(
            ST_Force3DZ(#{source_geom_expr}),
            0,
            0,
            GREATEST(COALESCE(#{base_height_expr}, 0), 0)
          )
        )::geometry(MultiPolygonZ, 4326),
        $3,
        $4
      FROM #{quoted_staging_table}
      WHERE geom IS NOT NULL
      AND ST_IsValid(geom)
      AND #{source_geom_filter}
    SQL

    connection.exec_insert(insert_sql, "Insert layer features from staged shapefile", [
      ActiveRecord::Relation::QueryAttribute.new("project_id", dataset.project_id.to_i, ActiveRecord::Type::Integer.new),
      ActiveRecord::Relation::QueryAttribute.new("dataset_id", dataset.id.to_i, ActiveRecord::Type::Integer.new),
      ActiveRecord::Relation::QueryAttribute.new("created_at", now, ActiveRecord::Type::DateTime.new),
      ActiveRecord::Relation::QueryAttribute.new("updated_at", now, ActiveRecord::Type::DateTime.new)
    ])
    dataset.public_send(feature_association_for(dataset.layer_type)).count
  end

  def feature_table_name_for(layer_type)
    FEATURE_TABLES.fetch(validated_layer_type(layer_type))
  end

  def feature_association_for(layer_type)
    FEATURE_ASSOCIATIONS.fetch(validated_layer_type(layer_type))
  end

  def source_geometry_filter(layer_type)
    if validated_layer_type(layer_type) == "roads"
      "GeometryType(geom) IN ('POLYGON', 'MULTIPOLYGON', 'LINESTRING', 'MULTILINESTRING')"
    else
      "GeometryType(geom) IN ('POLYGON', 'MULTIPOLYGON')"
    end
  end

  def source_geometry_expression(layer_type)
    return "geom" unless validated_layer_type(layer_type) == "roads"

    <<~SQL.squish
      CASE
        WHEN GeometryType(geom) IN ('LINESTRING', 'MULTILINESTRING')
        THEN ST_Transform(ST_Buffer(ST_Transform(geom, 3857), 2.0), 4326)
        ELSE geom
      END
    SQL
  end

  def quoted_feature_table_name(layer_type)
    ActiveRecord::Base.connection.quote_table_name(validated_sql_identifier(feature_table_name_for(layer_type), label: "feature table"))
  end

  def quoted_staging_table_name(dataset)
    ActiveRecord::Base.connection.quote_table_name(validated_staging_table_name(dataset))
  end

  def column_expression_for(dataset, candidates, cast: nil)
    column_expression(validated_staging_table_name(dataset), candidates, cast: cast)
  end

  def validated_source_geometry_filter(layer_type)
    source_geometry_filter(validated_layer_type(layer_type))
  end

  def validated_source_geometry_expression(layer_type)
    source_geometry_expression(validated_layer_type(layer_type))
  end

  def column_expression(table, candidates, cast: nil)
    conn = ActiveRecord::Base.connection
    safe_table = validated_sql_identifier(table, label: "staging table")
    columns = conn.columns(safe_table).map(&:name)
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

  def validated_staging_table_name(dataset)
    validated_sql_identifier(staging_table_name(dataset), label: "staging table")
  end

  def validated_layer_type(layer_type)
    FEATURE_TABLES.fetch(layer_type.to_s) do
      raise ArgumentError, "Unsupported layer type: #{layer_type}"
    end

    layer_type.to_s
  end

  def validated_sql_identifier(value, label: "SQL identifier")
    identifier = value.to_s
    return identifier if identifier.match?(SAFE_SQL_IDENTIFIER)

    raise ArgumentError, "Unsafe #{label}: #{value.inspect}"
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
