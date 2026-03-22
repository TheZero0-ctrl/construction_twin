class CreateBuildings < ActiveRecord::Migration[8.1]
  def change
    create_table :buildings do |t|
      t.references :project, null: false, foreign_key: true
      t.references :dataset, null: false, foreign_key: true
      t.string :name
      t.decimal :height, precision: 10, scale: 2
      t.multi_polygon :geom, srid: 4326, null: false

      t.timestamps
    end

    add_index :buildings, :geom, using: :gist
  end
end
