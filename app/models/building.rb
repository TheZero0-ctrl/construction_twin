# frozen_string_literal: true

class Building < ApplicationRecord
  belongs_to :project
  belongs_to :dataset

  validates :geom, presence: true
  validates :height, numericality: { greater_than: 0 }
  validates :base_height, numericality: { greater_than_or_equal_to: 0 }
end
