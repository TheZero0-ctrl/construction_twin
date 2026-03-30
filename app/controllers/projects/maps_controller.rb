# frozen_string_literal: true

class Projects::MapsController < ApplicationController
  before_action :set_project

  def show
    @layers = @project.map_layers.order(created_at: :desc)
    @has_layers = @project.map_layers.exists?
    @layers_url = project_layers_path(@project)
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end
end
