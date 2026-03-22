class CreateMapLayers < ActiveRecord::Migration[8.1]
  def change
    create_table :map_layers do |t|
      t.references :project, null: false, foreign_key: true
      t.references :dataset, null: false, foreign_key: true
      t.string :name, null: false
      t.string :layer_type, null: false
      t.string :source, null: false
      t.boolean :visible, null: false, default: true

      t.timestamps
    end

    add_index :map_layers, %i[dataset_id layer_type], unique: true
  end
end
