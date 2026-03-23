# frozen_string_literal: true

class TilesetVersion < ApplicationRecord
  belongs_to :tileset

  enum :status, %w[pending generating ready published failed].index_by(&:itself).freeze

  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :tile_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :version, uniqueness: { scope: :tileset_id }

  scope :ordered, -> { order(:version) }

  def mark_generating!
    update!(status: :generating, error: nil)
  end

  def mark_ready!(tile_count:, manifest_path:)
    update!(status: :ready, tile_count: tile_count, manifest_path: manifest_path, error: nil)
  end

  def mark_published!(published_at: Time.current)
    update!(status: :published, published_at: published_at, error: nil)
  end

  def fail!(message:)
    update!(status: :failed, error: message)
  end
end
