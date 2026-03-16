class CreateDatasets < ActiveRecord::Migration[8.1]
  def change
    create_table :datasets do |t|
      t.string :status, default: "processing", index: true
      t.string :data_type, null: false
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
