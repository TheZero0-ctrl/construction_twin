# frozen_string_literal: true

class Projects::LayersController < ApplicationController
  DEFAULT_LIMIT = 1000
  MAX_LIMIT = 5000

  before_action :set_project

  def index
    layers = @project.map_layers.includes(:layer_artifacts).order(:sort_order, :created_at)

    render json: Projects::LayersIndexPresenter.new(
      @project,
      layers: layers,
      fallback_geojson_url: method(:layer_features_url)
    ).to_h
  end

  def update
    layer = @project.map_layers.find(params.expect(:id))
    layer.update!(visible: update_layer_params.fetch(:visible))

    render json: {
      layer: Projects::LayerPresenter.new(
        layer.reload,
        fallback_geojson_url: layer_features_url(layer)
      ).to_h
    }
  end

  def features
    layer = @project.map_layers.find(params.expect(:id))
    limit = requested_limit
    feature_scope = layer_features_scope(layer)
    total_count = feature_scope.count
    features = feature_scope
      .order(:id)
      .limit(limit)
      .select(:id, :name, :height, :base_height)
      .select("ST_AsGeoJSON(geom)::json AS geometry")

    render json: Projects::LayerFeatureCollectionPresenter.new(
      layer,
      features: features,
      total_count: total_count,
      limit: limit
    ).to_h
  end

  private

  def set_project
    @project = Project.find(params.expect(:project_id))
  end

  def update_layer_params
    params.expect(layer: [ :visible ])
  end

  def layer_features_url(layer)
    features_project_layer_path(@project, layer, format: :json, limit: MAX_LIMIT)
  end

  def layer_features_scope(layer)
    case layer.layer_type
    when "buildings"
      @project.buildings.where(dataset_id: layer.dataset_id)
    when "terrain"
      @project.terrains.where(dataset_id: layer.dataset_id)
    when "roads"
      @project.roads.where(dataset_id: layer.dataset_id)
    else
      @project.buildings.none
    end
  end

  def requested_limit
    raw_value = params[:limit].to_i
    return DEFAULT_LIMIT if raw_value <= 0

    [ raw_value, MAX_LIMIT ].min
  end
end
