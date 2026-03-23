# frozen_string_literal: true

class Tileset < ApplicationRecord
  belongs_to :map_layer
  belongs_to :project
  belongs_to :dataset, optional: true
  has_many :tileset_versions, dependent: :destroy

  enum :status, %w[pending generating publishing ready failed].index_by(&:itself).freeze

  enum :layer_type, %w[buildings terrain roads unknown].index_by(&:itself).freeze

  validates :layer_type, presence: true
  validates :map_layer, uniqueness: true
  validates :storage_backend, presence: true
  validates :progress_total_tiles, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :progress_completed_tiles, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :progress_completed_tiles, comparison: {
    less_than_or_equal_to: :progress_total_tiles,
    message: "must be less than or equal to progress_total_tiles"
  }

  scope :for_layer, ->(layer) { where(layer_type: layer) }

  before_validation :sync_layer_and_owner_from_map_layer

  def start_generation!(started_at: Time.current)
    update!(status: :generating, started_at: started_at, finished_at: nil, last_error: nil)
  end

  def mark_publishing!
    update!(status: :publishing)
  end

  def mark_ready!(version:, finished_at: Time.current)
    update!(status: :ready, current_version: version, latest_generated_version: version, finished_at: finished_at, last_error: nil)
  end

  def fail!(message:, finished_at: Time.current)
    update!(status: :failed, last_error: message, finished_at: finished_at)
  end

  def update_progress!(completed:, total: progress_total_tiles)
    update!(progress_completed_tiles: completed, progress_total_tiles: total)
  end

  private

  def sync_layer_and_owner_from_map_layer
    return unless map_layer

    self.layer_type = map_layer.layer_type
    self.project = map_layer.project
    self.dataset ||= map_layer.dataset
  end
end
