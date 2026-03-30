# frozen_string_literal: true

class LayerArtifact < ApplicationRecord
  belongs_to :map_layer

  enum :format, %w[tiles_3d geojson].index_by(&:itself).freeze
  enum :status, %w[pending processing ready failed].index_by(&:itself).freeze

  scope :active, -> { where(active: true) }

  validates :storage_path, presence: true
end
