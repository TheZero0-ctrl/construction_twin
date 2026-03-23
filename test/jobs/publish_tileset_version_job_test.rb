# frozen_string_literal: true

require "test_helper"

class PublishTilesetVersionJobTest < ActiveJob::TestCase
  setup do
    @tileset = Tileset.create!(map_layer: map_layers(:one_buildings))
    @tileset_version = TilesetVersion.create!(tileset: @tileset, version: 1, status: :ready)
    @path_builder = Tilesets::PathBuilder.new(tileset: @tileset)
    @store = Tilesets::AtomicFileStore.new
  end

  teardown do
    FileUtils.rm_rf(Rails.root.join("public", "tilesets"))
  end

  test "publishes a validated manifest and marks version current" do
    staging_manifest = @path_builder.staging_manifest_path(version: @tileset_version.version)
    published_manifest = @path_builder.published_manifest_path(version: @tileset_version.version)

    @store.write(relative_path: staging_manifest, content: valid_manifest)

    PublishTilesetVersionJob.perform_now(@tileset_version)

    @tileset.reload
    @tileset_version.reload

    assert_equal "ready", @tileset.status
    assert_equal 1, @tileset.current_version
    assert_equal 1, @tileset.latest_generated_version
    assert_equal "published", @tileset_version.status
    assert File.exist?(@store.absolute_path_for(published_manifest))
    assert_not File.exist?(@store.absolute_path_for(staging_manifest))
  end

  test "marks records failed when manifest validation fails" do
    staging_manifest = @path_builder.staging_manifest_path(version: @tileset_version.version)
    @store.write(relative_path: staging_manifest, content: '{"asset":{"version":"1.1"}}')

    PublishTilesetVersionJob.perform_now(@tileset_version)

    @tileset.reload
    @tileset_version.reload

    assert_equal "failed", @tileset.status
    assert_equal "failed", @tileset_version.status
    assert_match(/manifest missing required keys/, @tileset.last_error)
    assert_match(/manifest missing required keys/, @tileset_version.error)
  end

  private

  def valid_manifest
    <<~JSON
      {
        "asset": { "version": "1.1" },
        "geometricError": 500,
        "root": {
          "boundingVolume": { "region": [0, 0, 0, 0, 0, 0] },
          "geometricError": 0
        }
      }
    JSON
  end
end
