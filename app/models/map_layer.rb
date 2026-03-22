# frozen_string_literal: true

class MapLayer < ApplicationRecord
  belongs_to :project
  belongs_to :dataset

  enum :layer_type, {
    buildings: "buildings",
    terrain: "terrain",
    roads: "roads",
    unknown: "unknown"
  }

  enum :source, {
    postgis: "postgis",
    geoserver: "geoserver"
  }

  validates :name, presence: true
  validates :visible, inclusion: { in: [ true, false ] }
end
