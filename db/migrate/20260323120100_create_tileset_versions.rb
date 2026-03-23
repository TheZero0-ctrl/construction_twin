class CreateTilesetVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :tileset_versions do |t|
      t.references :tileset, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :status, null: false, default: "pending"
      t.integer :tile_count, null: false, default: 0
      t.string :manifest_path
      t.datetime :published_at
      t.text :error

      t.timestamps
    end

    add_index :tileset_versions, %i[tileset_id version], unique: true
    add_check_constraint :tileset_versions, "version > 0", name: "tileset_versions_version_positive"
    add_check_constraint :tileset_versions, "tile_count >= 0", name: "tileset_versions_tile_count_non_negative"
  end
end
