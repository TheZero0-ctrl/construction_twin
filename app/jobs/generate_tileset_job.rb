# frozen_string_literal: true

require "json"

class GenerateTilesetJob < ApplicationJob
  queue_as :default

  def perform(tileset)
    tileset_version = nil

    tileset.start_generation!

    version = next_version(tileset)
    tileset_version = tileset.tileset_versions.create!(version: version, status: :generating)
    path_builder = Tilesets::PathBuilder.new(tileset: tileset)
    store = Tilesets::AtomicFileStore.new

    root = Tilesets::BuildingsNodeTreeBuilder.new(tileset: tileset).build
    if root.blank?
      fail_generation(tileset, tileset_version, "No buildings found to generate tiles")
      return
    end

    nodes = flatten_nodes(root)
    total_nodes = nodes.size
    tileset.update_progress!(completed: 0, total: total_nodes)

    nodes.each_with_index do |node, index|
      GenerateTilesetNodeJob.perform_now(tileset_version, node.deep_stringify_keys)
      tileset.update_progress!(completed: index + 1, total: total_nodes)
    end

    manifest = build_manifest(root)
    manifest_path = path_builder.staging_manifest_path(version: version)
    store.write(relative_path: manifest_path, content: JSON.pretty_generate(manifest))

    tileset_version.mark_ready!(tile_count: total_nodes, manifest_path: manifest_path)
    PublishTilesetVersionJob.perform_later(tileset_version)
  rescue StandardError => error
    fail_generation(tileset, tileset_version, error.message)
    raise
  end

  private

  def next_version(tileset)
    (tileset.latest_generated_version || 0) + 1
  end

  def flatten_nodes(node)
    [ node ] + node.fetch(:children).flat_map { |child| flatten_nodes(child) }
  end

  def build_manifest(root)
    {
      asset: {
        version: "1.1"
      },
      geometricError: root.fetch(:geometric_error),
      root: serialize_node(root)
    }
  end

  def serialize_node(node)
    {
      boundingVolume: {
        region: region_from_bounds(node.fetch(:bounds))
      },
      geometricError: node.fetch(:geometric_error),
      refine: node.fetch(:refine),
      children: node.fetch(:children).map { |child| serialize_node(child) }
    }
  end

  def region_from_bounds(bounds)
    [
      to_radians(bounds.fetch(:west)),
      to_radians(bounds.fetch(:south)),
      to_radians(bounds.fetch(:east)),
      to_radians(bounds.fetch(:north)),
      bounds.fetch(:min_height),
      bounds.fetch(:max_height)
    ]
  end

  def to_radians(degrees)
    degrees.to_f * Math::PI / 180.0
  end

  def fail_generation(tileset, tileset_version, message)
    tileset&.fail!(message: message)
    tileset_version&.fail!(message: message)
  end
end
