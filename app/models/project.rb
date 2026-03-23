# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :datasets, dependent: :destroy
  has_many :buildings, dependent: :destroy
  has_many :map_layers, dependent: :destroy
  has_many :tilesets, dependent: :destroy

  validates :name, presence: true
end
