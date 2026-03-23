class AddTilesetProgressConsistencyConstraint < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :tilesets,
      "progress_completed_tiles <= progress_total_tiles",
      name: "tilesets_progress_completed_lte_total"
  end
end
