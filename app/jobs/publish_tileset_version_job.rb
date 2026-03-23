# frozen_string_literal: true

class PublishTilesetVersionJob < ApplicationJob
  queue_as :default

  def perform(tileset_version)
    tileset = tileset_version.tileset
    version = tileset_version.version

    path_builder = Tilesets::PathBuilder.new(tileset: tileset)
    store = Tilesets::AtomicFileStore.new

    staging_manifest_relative_path = path_builder.staging_manifest_path(version: version)
    published_manifest_relative_path = path_builder.published_manifest_path(version: version)
    staging_manifest_absolute_path = Rails.root.join("public", staging_manifest_relative_path)

    validation = Tilesets::ManifestValidator.new.validate(staging_manifest_absolute_path)
    unless validation[:success]
      fail_publish!(tileset: tileset, tileset_version: tileset_version, error: validation[:error])
      return
    end

    ApplicationRecord.transaction do
      tileset.mark_publishing!
      store.move(from_relative_path: staging_manifest_relative_path, to_relative_path: published_manifest_relative_path)
      tileset_version.mark_published!(manifest_path: published_manifest_relative_path)
      tileset.mark_ready!(version: version)
    end
  rescue StandardError => error
    if defined?(tileset) && defined?(tileset_version) && tileset && tileset_version
      fail_publish!(tileset: tileset, tileset_version: tileset_version, error: error.message)
    end
    raise
  end

  private

  def fail_publish!(tileset:, tileset_version:, error:)
    ApplicationRecord.transaction do
      tileset_version.fail!(message: error)
      tileset.fail!(message: error)
    end
  end
end
