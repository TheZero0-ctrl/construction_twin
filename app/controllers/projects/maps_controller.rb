# frozen_string_literal: true

class Projects::MapsController < ApplicationController
  before_action :set_project

  def show
    @layers = @project.map_layers.order(created_at: :desc)
    @has_layers = @project.map_layers.exists?
    @layers_url = project_layers_path(@project)
    @fallback_buildings_url = project_buildings_path(@project, format: :json, limit: Projects::BuildingsController::MAX_LIMIT)
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end
end
