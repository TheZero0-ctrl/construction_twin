# frozen_string_literal: true

class Projects::LayerFeaturePresenter < Projects::Presenter
  def to_h
    {
      type: "Feature",
      id: resource.id,
      geometry: resource.geometry,
      properties: {
        id: resource.id,
        name: resource.name,
        height: resource.height&.to_f,
        base_height: resource.base_height&.to_f,
        layer_type: options.fetch(:layer_type),
        layer_name: options.fetch(:layer_name)
      }
    }
  end
end
