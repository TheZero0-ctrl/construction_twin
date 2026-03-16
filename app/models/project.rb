# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :datasets, dependent: :destroy

  validates :name, presence: true
end
