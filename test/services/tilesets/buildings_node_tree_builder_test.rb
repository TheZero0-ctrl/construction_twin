# frozen_string_literal: true

require "test_helper"

module Tilesets
  class BuildingsNodeTreeBuilderTest < ActiveSupport::TestCase
    setup do
      @tileset = Tileset.create!(map_layer: map_layers(:one_buildings))
      @dataset = @tileset.dataset
      @project = @tileset.project

      create_building(-74.0, 40.0, -73.99, 40.01, 12)
      create_building(-73.98, 40.0, -73.97, 40.01, 25)
    end

    test "returns a root node with bounds and building count" do
      tree = BuildingsNodeTreeBuilder.new(tileset: @tileset, max_depth: 1, min_buildings_per_node: 100).build

      assert_equal "root", tree[:id]
      assert_equal 2, tree[:building_count]
      assert_equal "ADD", tree[:refine]
      assert_in_delta(-74.0, tree[:bounds][:west], 0.01)
      assert_in_delta(40.01, tree[:bounds][:north], 0.01)
    end

    test "splits into children when threshold is exceeded" do
      tree = BuildingsNodeTreeBuilder.new(tileset: @tileset, max_depth: 1, min_buildings_per_node: 1).build

      assert tree[:children].any?
      assert tree[:children].all? { |child| child[:depth] == 1 }
      assert tree[:children].all? { |child| child[:building_count].positive? }
    end

    private

    def create_building(west, south, east, north, height)
      sql = <<~SQL
        ST_Multi(
          ST_GeomFromText(
            'POLYGON((#{west} #{south}, #{east} #{south}, #{east} #{north}, #{west} #{north}, #{west} #{south}))',
            4326
          )
        )
      SQL

      Building.create!(
        project: @project,
        dataset: @dataset,
        height: height,
        geom: Building.connection.select_value("SELECT #{sql}")
      )
    end
  end
end
