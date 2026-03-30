# frozen_string_literal: true

class Projects::LayerPresenter < Projects::Presenter
  def to_h
    {
      id: resource.id,
      name: resource.name,
      layer_type: resource.layer_type,
      source: resource.source,
      visible: resource.visible,
      status: resource.status,
      last_processed_at: resource.last_processed_at,
      last_error: resource.last_error,
      fallback_geojson_url: options.fetch(:fallback_geojson_url),
      artifacts: artifact_presenters
    }
  end

  private

  def artifact_presenters
    resource.layer_artifacts.sort_by(&:created_at).reverse.map do |artifact|
      Projects::LayerArtifactPresenter.new(artifact).to_h
    end
  end
end
