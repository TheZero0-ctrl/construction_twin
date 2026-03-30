# frozen_string_literal: true

class Dataset < ApplicationRecord
  DEFAULT_FOOTPRINT_HEIGHT_METERS = 28.0
  DEFAULT_HEIGHT_BY_LAYER_TYPE = {
    "buildings" => 28.0,
    "terrain" => 6.0,
    "roads" => 1.0
  }.freeze
  UPLOAD_LAYER_TYPES = %w[buildings terrain roads].freeze

  SUPPORTED_DATA_TYPES = {
    "Shapefile (.zip)" => "shapefile"
  }.freeze

  belongs_to :project
  has_many :buildings, dependent: :delete_all
  has_many :terrains, dependent: :delete_all
  has_many :roads, dependent: :delete_all
  has_one :map_layer, dependent: :destroy
  has_one_attached :file

  scope :recently_uploaded, -> { with_attached_file.order(created_at: :desc) }

  enum :status, %w[ uploaded processing completed failed ].index_by(&:itself)
  enum :data_type, { shapefile: "shapefile" }
  enum :layer_type, UPLOAD_LAYER_TYPES.index_by(&:itself)

  validates :data_type, presence: true
  validates :data_type, inclusion: { in: data_types.keys }
  validates :layer_type, presence: true
  validates :layer_type, inclusion: { in: layer_types.keys }
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

  def self.default_height_for(layer_type)
    DEFAULT_HEIGHT_BY_LAYER_TYPE.fetch(layer_type.to_s, DEFAULT_FOOTPRINT_HEIGHT_METERS)
  end

  private

  def file_must_be_attached
    errors.add(:file, :must_be_attached) unless file.attached?
  end

  def file_format_matches_data_type
    return unless file.attached?
    return unless shapefile?
    return if file_extension == "zip"

    errors.add(:file, :invalid_shapefile_archive)
  end

  def file_extension
    File.extname(file.filename.to_s).delete(".").downcase
  end

  def normalized_info
    info.is_a?(Hash) ? info : {}
  end
end
