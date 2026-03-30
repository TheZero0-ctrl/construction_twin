class CreateMapLayers < ActiveRecord::Migration[8.1]
  def change
    create_table :map_layers do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.references :dataset, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :layer_type, null: false
      t.string :source, null: false
      t.string :status, null: false, default: "pending"
      t.boolean :visible, null: false, default: true
      t.datetime :last_processed_at
      t.text :last_error
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :map_layers, :dataset_id, unique: true
    add_index :map_layers, :status
    add_index :map_layers, [ :project_id, :sort_order ]
  end
end
