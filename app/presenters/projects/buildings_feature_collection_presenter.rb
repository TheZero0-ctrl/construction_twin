# frozen_string_literal: true

class Projects::BuildingsFeatureCollectionPresenter < Projects::Presenter
  def to_h
    {
      type: "FeatureCollection",
      features: features,
      meta: {
        total_count: options.fetch(:total_count),
        returned_count: features.size,
        limit: options.fetch(:limit),
        truncated: options.fetch(:total_count) > features.size
      }
    }
  end

  private

  def features
    @features ||= options.fetch(:buildings).map do |building|
      Projects::BuildingFeaturePresenter.new(building).to_h
    end
  end
end
