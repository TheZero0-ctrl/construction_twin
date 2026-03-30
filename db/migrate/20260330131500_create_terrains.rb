class CreateTerrains < ActiveRecord::Migration[8.1]
  def change
    create_table :terrains do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.references :dataset, null: false, foreign_key: { on_delete: :cascade }
      t.string :name
      t.decimal :height, precision: 10, scale: 2, null: false, default: 6.0
      t.decimal :base_height, precision: 10, scale: 2, null: false, default: 0
      t.multi_polygon :geom, srid: 4326, has_z: true, null: false

      t.timestamps
    end

    add_index :terrains, :geom, using: :gist
  end
end
