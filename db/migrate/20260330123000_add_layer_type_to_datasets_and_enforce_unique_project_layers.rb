class AddLayerTypeToDatasetsAndEnforceUniqueProjectLayers < ActiveRecord::Migration[8.1]
  def up
    add_column :datasets, :layer_type, :string, null: false, default: "buildings"

    execute <<~SQL
      WITH ranked_layers AS (
        SELECT
          id,
          dataset_id,
          ROW_NUMBER() OVER (
            PARTITION BY project_id, layer_type
            ORDER BY created_at DESC, id DESC
          ) AS row_num
        FROM map_layers
      )
      DELETE FROM datasets
      WHERE id IN (
        SELECT dataset_id
        FROM ranked_layers
        WHERE row_num > 1
      )
    SQL

    add_index :map_layers, [ :project_id, :layer_type ], unique: true
  end

  def down
    remove_index :map_layers, [ :project_id, :layer_type ]
    remove_column :datasets, :layer_type
  end
end
