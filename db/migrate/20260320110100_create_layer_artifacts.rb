class CreateLayerArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :layer_artifacts do |t|
      t.references :map_layer, null: false, foreign_key: { on_delete: :cascade }
      t.string :format, null: false
      t.string :status, null: false, default: "pending"
      t.string :storage_path, null: false
      t.string :public_url
      t.jsonb :metadata, null: false, default: {}
      t.text :error_message
      t.boolean :active, null: false, default: false
      t.datetime :generated_at

      t.timestamps
    end

    add_index :layer_artifacts,
      [ :map_layer_id, :format, :active ],
      unique: true,
      where: "active = true",
      name: "index_layer_artifacts_active_per_format"
    add_index :layer_artifacts, [ :map_layer_id, :format, :status ]
  end
end
