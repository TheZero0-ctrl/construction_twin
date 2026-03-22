# frozen_string_literal: true

class Building < ApplicationRecord
  belongs_to :project
  belongs_to :dataset

  validates :geom, presence: true
end
