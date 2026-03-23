# frozen_string_literal: true

class MapLayer < ApplicationRecord
  belongs_to :project
  belongs_to :dataset
  has_one :tileset, dependent: :destroy

  enum :layer_type, %w[buildings terrain roads unknown].index_by(&:itself).freeze

  enum :source, %w[postgis geoserver].index_by(&:itself).freeze

  validates :name, presence: true
  validates :visible, inclusion: { in: [ true, false ] }
end
