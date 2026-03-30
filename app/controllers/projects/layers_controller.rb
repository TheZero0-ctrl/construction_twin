# frozen_string_literal: true

class Projects::LayersController < ApplicationController
  before_action :set_project

  def index
    layers = @project.map_layers.includes(:layer_artifacts).order(:sort_order, :created_at)

    render json: Projects::LayersIndexPresenter.new(
      @project,
      layers: layers,
      fallback_geojson_url: project_buildings_path(@project, format: :json)
    ).to_h
  end

  def update
    layer = @project.map_layers.find(params.expect(:id))
    layer.update!(visible: update_layer_params.fetch(:visible))

    render json: {
      layer: Projects::LayerPresenter.new(
        layer.reload,
        fallback_geojson_url: project_buildings_path(@project, format: :json)
      ).to_h
    }
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end

  def update_layer_params
    params.expect(layer: [ :visible ])
  end
end
