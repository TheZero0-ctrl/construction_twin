# frozen_string_literal: true

class Projects::LayerFeatureCollectionPresenter < Projects::Presenter
  def to_h
    {
      type: "FeatureCollection",
      features: features,
      meta: {
        total_count: options.fetch(:total_count),
        returned_count: features.size,
        limit: options.fetch(:limit),
        truncated: options.fetch(:total_count) > features.size,
        layer_type: resource.layer_type
      }
    }
  end

  private

  def features
    @features ||= options.fetch(:features).map do |feature|
      Projects::LayerFeaturePresenter.new(feature, layer_type: resource.layer_type, layer_name: resource.name).to_h
    end
  end
end
