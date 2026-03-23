# frozen_string_literal: true

module Tilesets
  class PathBuilder
    ROOT = "tilesets"
    STAGING_ROOT = "tilesets/staging"

    def initialize(tileset:, root: ROOT, staging_root: STAGING_ROOT)
      @tileset = tileset
      @root = root
      @staging_root = staging_root
    end

    def project_prefix
      File.join("projects", tileset.project_id.to_s, tileset.layer_type)
    end

    def published_version_dir(version:)
      File.join(root, project_prefix, version_segment(version))
    end

    def published_manifest_path(version:)
      File.join(published_version_dir(version: version), "tileset.json")
    end

    def staging_version_dir(version:)
      File.join(staging_root, project_prefix, version_segment(version))
    end

    def staging_manifest_path(version:)
      File.join(staging_version_dir(version: version), "tileset.json")
    end

    def staging_nodes_dir(version:)
      File.join(staging_version_dir(version: version), "nodes")
    end

    def staging_node_tileset_path(version:, node_id:)
      File.join(staging_nodes_dir(version: version), "node-#{node_id}.json")
    end

    def staging_node_meta_path(version:, node_id:)
      File.join(staging_nodes_dir(version: version), "node-#{node_id}.meta.json")
    end

    private

    attr_reader :tileset, :root, :staging_root

    def version_segment(version)
      normalized_version = Integer(version)
      raise ArgumentError, "version must be positive" if normalized_version <= 0

      "v#{normalized_version}"
    end
  end
end
