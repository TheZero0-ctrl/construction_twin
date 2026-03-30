# frozen_string_literal: true

class Projects::LayerArtifactPresenter < Projects::Presenter
  def to_h
    {
      id: resource.id,
      format: resource.format,
      status: resource.status,
      active: resource.active,
      url: resource.public_url,
      metadata: resource.metadata
    }
  end
end
