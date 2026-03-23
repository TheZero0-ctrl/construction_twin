class CreateTilesets < ActiveRecord::Migration[8.1]
  def change
    create_table :tilesets do |t|
      t.references :project, null: false, foreign_key: true
      t.references :dataset, foreign_key: true
      t.refrence :map_layer, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :layer_type, null: false, default: "buildings"
      t.integer :current_version
      t.integer :latest_generated_version
      t.string :base_path
      t.string :storage_backend, null: false, default: "local"
      t.integer :progress_total_tiles, null: false, default: 0
      t.integer :progress_completed_tiles, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :last_error

      t.timestamps
    end

    add_index :tilesets, %i[project_id layer_type]
    add_check_constraint :tilesets, "progress_total_tiles >= 0", name: "tilesets_progress_total_non_negative"
    add_check_constraint :tilesets, "progress_completed_tiles >= 0", name: "tilesets_progress_completed_non_negative"
  end
end
