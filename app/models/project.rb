# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :datasets, dependent: :destroy
  has_many :buildings, dependent: :delete_all
  has_many :map_layers, dependent: :destroy
  has_many :layer_artifacts, through: :map_layers

  validates :name, presence: true
end
