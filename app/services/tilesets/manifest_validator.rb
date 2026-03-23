# frozen_string_literal: true

require "json"

module Tilesets
  class ManifestValidator
    REQUIRED_ROOT_KEYS = %w[asset geometricError root].freeze
    REQUIRED_ASSET_KEYS = %w[version].freeze
    REQUIRED_TILE_KEYS = %w[boundingVolume geometricError].freeze

    def validate(path)
      absolute_path = path.to_s
      return failure("manifest file not found") unless File.exist?(absolute_path)

      payload = parse_json(File.read(absolute_path))
      return failure("manifest is not valid JSON") if payload.nil?
      return failure("manifest root must be a JSON object") unless payload.is_a?(Hash)

      missing_root_keys = REQUIRED_ROOT_KEYS - payload.keys
      return failure("manifest missing required keys: #{missing_root_keys.join(', ')}") if missing_root_keys.any?

      asset = payload["asset"]
      return failure("manifest asset must be an object") unless asset.is_a?(Hash)

      missing_asset_keys = REQUIRED_ASSET_KEYS - asset.keys
      return failure("manifest asset missing required keys: #{missing_asset_keys.join(', ')}") if missing_asset_keys.any?

      root = payload["root"]
      return failure("manifest root tile must be an object") unless root.is_a?(Hash)

      missing_tile_keys = REQUIRED_TILE_KEYS - root.keys
      return failure("manifest root tile missing required keys: #{missing_tile_keys.join(', ')}") if missing_tile_keys.any?

      success
    end

    private

    def parse_json(content)
      JSON.parse(content)
    rescue JSON::ParserError
      nil
    end

    def success
      { success: true, error: nil }
    end

    def failure(message)
      { success: false, error: message }
    end
  end
end
