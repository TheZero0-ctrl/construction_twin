# frozen_string_literal: true

class Dataset < ApplicationRecord
  SUPPORTED_DATA_TYPES = {
    "Shapefile (.zip)" => "shapefile"
  }.freeze

  belongs_to :project
  has_many :buildings, dependent: :destroy
  has_many :map_layers, dependent: :destroy
  has_one_attached :file

  enum :status, %w[ uploaded processing completed failed ].index_by(&:itself)
  enum :data_type, { shapefile: "shapefile" }

  validates :data_type, presence: true
  validates :data_type, inclusion: { in: data_types.keys }
  validate :file_must_be_attached
  validate :file_format_matches_data_type

  def display_name
    file.filename.to_s
  end

  def info_message
    normalized_info["message"]
  end

  def update_info_message!(message)
    update!(info: normalized_info.merge("message" => message))
  end

  private

  def file_must_be_attached
    errors.add(:file, "must be attached") unless file.attached?
  end

  def file_format_matches_data_type
    return unless file.attached?
    return unless shapefile?
    return if file_extension == "zip"

    errors.add(:file, "must be uploaded as a .zip archive containing the shapefile bundle")
  end

  def file_extension
    File.extname(file.filename.to_s).delete(".").downcase
  end

  def normalized_info
    info.is_a?(Hash) ? info : {}
  end
end
