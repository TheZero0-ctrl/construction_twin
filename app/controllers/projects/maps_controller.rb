# frozen_string_literal: true

class Projects::MapsController < ApplicationController
  BUILDINGS_MAP_LIMIT = 1000

  before_action :set_project

  def show
    @layers = @project.map_layers.order(created_at: :desc)
    @has_buildings = @project.buildings.exists?
    @buildings_url = project_buildings_path(@project, format: :json, limit: BUILDINGS_MAP_LIMIT)
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end
end
