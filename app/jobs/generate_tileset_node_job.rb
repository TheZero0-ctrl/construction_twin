# frozen_string_literal: true

require "json"

class GenerateTilesetNodeJob < ApplicationJob
  queue_as :default

  def perform(tileset_version, node)
    path_builder = Tilesets::PathBuilder.new(tileset: tileset_version.tileset)
    store = Tilesets::AtomicFileStore.new
    version = tileset_version.version

    node_id = node.fetch("id")
    bounds = node.fetch("bounds")
    count = node.fetch("building_count")

    manifest = {
      id: node_id,
      bounds: bounds,
      building_count: count,
      geometric_error: node.fetch("geometric_error"),
      refine: node.fetch("refine")
    }

    store.write(
      relative_path: path_builder.staging_node_tileset_path(version: version, node_id: node_id),
      content: JSON.pretty_generate(manifest)
    )

    store.write(
      relative_path: path_builder.staging_node_meta_path(version: version, node_id: node_id),
      content: JSON.generate({ id: node_id, tile_count: count })
    )
  end
end
