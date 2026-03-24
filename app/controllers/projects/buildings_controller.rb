# frozen_string_literal: true

class Projects::BuildingsController < ApplicationController
  DEFAULT_LIMIT = 1000
  MAX_LIMIT = 5000

  before_action :set_project

  def index
    total_count = @project.buildings.count
    limit = requested_limit
    features = building_features(
      @project
        .buildings
        .order(:id)
        .limit(limit)
    )

    render json: {
      type: "FeatureCollection",
      features: features,
      meta: {
        total_count: total_count,
        returned_count: features.size,
        limit: limit,
        truncated: total_count > features.size
      }
    }
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end

  def building_features(buildings)
    buildings
      .select(:id, :name, :height)
      .select("ST_AsGeoJSON(geom)::json AS geometry")
      .map { |building| building_feature(building) }
  end

  def requested_limit
    raw_value = params[:limit].to_i
    return DEFAULT_LIMIT if raw_value <= 0

    [ raw_value, MAX_LIMIT ].min
  end

  def building_feature(building)
    {
      type: "Feature",
      id: building.id,
      geometry: building.geometry,
      properties: {
        id: building.id,
        name: building.name,
        height: building.height&.to_f
      }
    }
  end
end
