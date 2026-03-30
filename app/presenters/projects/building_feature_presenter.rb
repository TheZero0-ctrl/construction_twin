# frozen_string_literal: true

class Projects::BuildingFeaturePresenter < Projects::Presenter
  def to_h
    {
      type: "Feature",
      id: resource.id,
      geometry: resource.geometry,
      properties: {
        id: resource.id,
        name: resource.name,
        height: resource.height&.to_f,
        base_height: resource.base_height&.to_f
      }
    }
  end
end
