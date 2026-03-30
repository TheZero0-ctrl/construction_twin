# frozen_string_literal: true

class Projects::LayersIndexPresenter < Projects::Presenter
  def to_h
    {
      project_id: resource.id,
      layers: layers.map { |layer| layer_payload(layer) }
    }
  end

  private

  def layers
    options.fetch(:layers)
  end

  def fallback_geojson_url
    options.fetch(:fallback_geojson_url)
  end

  def layer_payload(layer)
    Projects::LayerPresenter.new(layer, fallback_geojson_url: fallback_geojson_url).to_h
  end
end
