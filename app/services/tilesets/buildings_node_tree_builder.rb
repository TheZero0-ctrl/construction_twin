# frozen_string_literal: true

module Tilesets
  class BuildingsNodeTreeBuilder
    DEFAULT_MAX_DEPTH = 3
    DEFAULT_MIN_BUILDINGS_PER_NODE = 5_000
    INITIAL_GEOMETRIC_ERROR = 500.0

    def initialize(tileset:, max_depth: DEFAULT_MAX_DEPTH, min_buildings_per_node: DEFAULT_MIN_BUILDINGS_PER_NODE)
      @tileset = tileset
      @max_depth = max_depth
      @min_buildings_per_node = min_buildings_per_node
    end

    def build
      root_bounds = dataset_bounds
      return [] if root_bounds.nil?

      build_node(bounds: root_bounds, depth: 0, id: "root")
    end

    private

    attr_reader :tileset, :max_depth, :min_buildings_per_node

    def build_node(bounds:, depth:, id:)
      building_count = count_buildings(bounds)

      node = {
        id: id,
        depth: depth,
        bounds: bounds,
        building_count: building_count,
        geometric_error: node_geometric_error(depth),
        refine: "ADD",
        children: []
      }

      return node if depth >= max_depth
      return node if building_count <= min_buildings_per_node

      children = subdivide(bounds).map.with_index do |child_bounds, index|
        build_node(bounds: child_bounds, depth: depth + 1, id: "#{id}-#{index}")
      end

      node[:children] = children.select { |child| child[:building_count].positive? }
      node
    end

    def count_buildings(bounds)
      return 0 if tileset.dataset_id.blank?

      Building
        .where(dataset_id: tileset.dataset_id)
        .where(
          <<~SQL.squish,
            ST_Intersects(
              buildings.geom,
              ST_MakeEnvelope(?, ?, ?, ?, 4326)
            )
          SQL
          bounds.fetch(:west),
          bounds.fetch(:south),
          bounds.fetch(:east),
          bounds.fetch(:north)
        )
        .count
    end

    def dataset_bounds
      return nil if tileset.dataset_id.blank?

      row = Building
        .where(dataset_id: tileset.dataset_id)
        .pick(
          Arel.sql("ST_XMin(ST_Extent(geom))::float"),
          Arel.sql("ST_YMin(ST_Extent(geom))::float"),
          Arel.sql("ST_XMax(ST_Extent(geom))::float"),
          Arel.sql("ST_YMax(ST_Extent(geom))::float")
        )

      return nil if row.blank? || row.any?(&:nil?)

      {
        west: row[0],
        south: row[1],
        east: row[2],
        north: row[3],
        min_height: 0.0,
        max_height: max_dataset_height
      }
    end

    def max_dataset_height
      Building.where(dataset_id: tileset.dataset_id).maximum(:height).to_f
    end

    def subdivide(bounds)
      mid_x = (bounds[:west] + bounds[:east]) / 2.0
      mid_y = (bounds[:south] + bounds[:north]) / 2.0

      [
        bounds.merge(east: mid_x, north: mid_y),
        bounds.merge(west: mid_x, north: mid_y),
        bounds.merge(east: mid_x, south: mid_y),
        bounds.merge(west: mid_x, south: mid_y)
      ]
    end

    def node_geometric_error(depth)
      INITIAL_GEOMETRIC_ERROR / (2**depth)
    end
  end
end
