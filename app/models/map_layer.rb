# frozen_string_literal: true

class MapLayer < ApplicationRecord
  belongs_to :project
  belongs_to :dataset
  has_many :layer_artifacts, dependent: :destroy

  enum :layer_type, %w[buildings terrain roads unknown].index_by(&:itself).freeze

  enum :source, %w[postgis geoserver tiles_3d].index_by(&:itself).freeze
  enum :status, %w[pending processing ready failed].index_by(&:itself).freeze

  validates :name, presence: true
  validates :visible, inclusion: { in: [ true, false ] }

  def active_artifact(format)
    layer_artifacts.active.ready.find_by(format: format)
  end
end
