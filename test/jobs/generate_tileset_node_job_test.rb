# frozen_string_literal: true

require "test_helper"

class GenerateTilesetNodeJobTest < ActiveJob::TestCase
  setup do
    @tileset = Tileset.create!(map_layer: map_layers(:one_buildings))
    @tileset_version = TilesetVersion.create!(tileset: @tileset, version: 1, status: :generating)
    @path_builder = Tilesets::PathBuilder.new(tileset: @tileset)
    @store = Tilesets::AtomicFileStore.new
  end

  teardown do
    FileUtils.rm_rf(Rails.root.join("public", "tilesets"))
  end

  test "writes node payload and metadata to staging paths" do
    node = {
      "id" => "root-0",
      "bounds" => { "west" => -1, "south" => -1, "east" => 1, "north" => 1, "min_height" => 0, "max_height" => 10 },
      "building_count" => 10,
      "geometric_error" => 250.0,
      "refine" => "ADD"
    }

    GenerateTilesetNodeJob.perform_now(@tileset_version, node)

    payload_path = @store.absolute_path_for(@path_builder.staging_node_tileset_path(version: 1, node_id: "root-0"))
    meta_path = @store.absolute_path_for(@path_builder.staging_node_meta_path(version: 1, node_id: "root-0"))

    assert File.exist?(payload_path)
    assert File.exist?(meta_path)
  end
end
