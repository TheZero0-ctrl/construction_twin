# frozen_string_literal: true

module Tilesets
  class GenerationStarter
    def initialize(map_layer:)
      @map_layer = map_layer
    end

    def call
      tileset = map_layer.tileset || map_layer.build_tileset
      tileset.status ||= :pending
      tileset.save! if tileset.new_record? || tileset.changed?

      return tileset if tileset.generating? || tileset.publishing?

      GenerateTilesetJob.perform_later(tileset)
      tileset
    end

    private

    attr_reader :map_layer
  end
end
