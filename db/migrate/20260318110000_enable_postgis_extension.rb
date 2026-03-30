class EnablePostgisExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "postgis" unless extension_enabled?("postgis")
    enable_extension "postgis_sfcgal" if extension_supported?("postgis_sfcgal") && !extension_enabled?("postgis_sfcgal")
  end

  private

  def extension_supported?(name)
    select_value(<<~SQL.squish).present?
      SELECT name
      FROM pg_available_extensions
      WHERE name = #{quote(name)}
    SQL
  end
end
