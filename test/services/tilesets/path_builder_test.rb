# frozen_string_literal: true

require "test_helper"

module Tilesets
  class PathBuilderTest < ActiveSupport::TestCase
    setup do
      @tileset = Tileset.create!(map_layer: map_layers(:one_buildings))
      @builder = PathBuilder.new(tileset: @tileset)
      @project_id = @tileset.project_id
    end

    test "builds deterministic published paths" do
      assert_equal "tilesets/projects/#{@project_id}/buildings/v3", @builder.published_version_dir(version: 3)
      assert_equal "tilesets/projects/#{@project_id}/buildings/v3/tileset.json", @builder.published_manifest_path(version: 3)
    end

    test "builds deterministic staging paths" do
      assert_equal "tilesets/staging/projects/#{@project_id}/buildings/v7", @builder.staging_version_dir(version: 7)
      assert_equal "tilesets/staging/projects/#{@project_id}/buildings/v7/tileset.json", @builder.staging_manifest_path(version: 7)
    end

    test "rejects non-positive versions" do
      assert_raises(ArgumentError) { @builder.published_manifest_path(version: 0) }
      assert_raises(ArgumentError) { @builder.staging_manifest_path(version: -1) }
    end
  end
end
