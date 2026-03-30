# frozen_string_literal: true

class Generate3dTilesJob < ApplicationJob
  def perform(dataset_id)
    dataset = Dataset.includes(:map_layer).find_by(id: dataset_id)
    return unless dataset

    layer = dataset.map_layer
    return unless layer

    layer.update!(status: :processing, last_error: nil)
    dataset.update_info_message!("Building 3D Tiles for layer '#{layer.name}'...")

    TilesetExporter.new(layer).export!

    layer.update!(status: :ready, source: :tiles_3d, last_processed_at: Time.current)
    dataset.update_info_message!("3D Tiles generated for layer '#{layer.name}'.")
  rescue StandardError => error
    dataset&.update_info_message!("3D tile generation failed: #{error.message}")
    layer&.update!(status: :failed, last_error: error.message)
    raise
  end
end
