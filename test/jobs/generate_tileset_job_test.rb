# frozen_string_literal: true

require "test_helper"

class GenerateTilesetJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @tileset = Tileset.create!(map_layer: map_layers(:one_buildings))
    @dataset = @tileset.dataset
    @project = @tileset.project

    create_building(-74.0, 40.0, -73.99, 40.01, 20)
    create_building(-73.98, 40.0, -73.97, 40.01, 30)
  end

  teardown do
    FileUtils.rm_rf(Rails.root.join("public", "tilesets"))
  end

  test "creates generating version, writes staging manifest, and enqueues publish" do
    clear_enqueued_jobs

    assert_enqueued_with(job: PublishTilesetVersionJob) do
      GenerateTilesetJob.perform_now(@tileset)
    end

    version = @tileset.tileset_versions.order(:version).last
    assert_equal "ready", version.status
    assert version.tile_count.positive?
    assert version.manifest_path.start_with?("tilesets/staging/")

    @tileset.reload
    assert_equal "generating", @tileset.status
    assert @tileset.progress_total_tiles.positive?
    assert_equal @tileset.progress_total_tiles, @tileset.progress_completed_tiles
  end

  private

  def create_building(west, south, east, north, height)
    sql = <<~SQL
      ST_Multi(
        ST_GeomFromText(
          'POLYGON((#{west} #{south}, #{east} #{south}, #{east} #{north}, #{west} #{north}, #{west} #{south}))',
          4326
        )
      )
    SQL

    Building.create!(
      project: @project,
      dataset: @dataset,
      height: height,
      geom: Building.connection.select_value("SELECT #{sql}")
    )
  end
end
