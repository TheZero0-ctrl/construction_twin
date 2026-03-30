# frozen_string_literal: true

class Projects::BuildingsController < ApplicationController
  DEFAULT_LIMIT = 1000
  MAX_LIMIT = 5000

  before_action :set_project

  def index
    total_count = @project.buildings.count
    limit = requested_limit
    buildings = selected_buildings(limit)

    render json: Projects::BuildingsFeatureCollectionPresenter.new(
      @project,
      buildings: buildings,
      total_count: total_count,
      limit: limit
    ).to_h
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end

  def selected_buildings(limit)
    @project
      .buildings
      .order(:id)
      .limit(limit)
      .select(:id, :name, :height, :base_height)
      .select("ST_AsGeoJSON(geom)::json AS geometry")
  end

  def requested_limit
    raw_value = params[:limit].to_i
    return DEFAULT_LIMIT if raw_value <= 0

    [ raw_value, MAX_LIMIT ].min
  end
end
