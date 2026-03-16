# frozen_string_literal: true

class Dataset < ApplicationRecord
  belongs_to :project
  has_one_attached :file

  enum :status, %w[ processing done ].index_by(&:itself)
  enum :data_type, %w[ shapefile ].index_by(&:itself)
end
