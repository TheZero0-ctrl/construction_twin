class EnableSpatialExtensions < ActiveRecord::Migration[8.1]
  def up
    enable_extension "postgis" unless extension_enabled?("postgis")

    unless extension_available?("postgis_sfcgal")
      raise <<~ERROR
        postgis_sfcgal is not available on this PostgreSQL server.
        Install PostGIS with SFCGAL support on the host, then rerun migrations.
      ERROR
    end

    enable_extension "postgis_sfcgal" unless extension_enabled?("postgis_sfcgal")
  end

  def down
    disable_extension "postgis_sfcgal" if extension_enabled?("postgis_sfcgal")
  end

  private

  def extension_available?(name)
    select_value(<<~SQL.squish).present?
      SELECT name
      FROM pg_available_extensions
      WHERE name = #{quote(name)}
    SQL
  end
end
