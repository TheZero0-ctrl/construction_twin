# frozen_string_literal: true

require "test_helper"

class ProcessDatasetJobTilesetTriggerTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @dataset = datasets(:one)
    @job = ProcessDatasetJob.new
    clear_enqueued_jobs
  end

  test "triggers generation starter when buildings layer is ensured" do
    assert_enqueued_with(job: GenerateTilesetJob) do
      result = @job.send(:ensure_buildings_layer!, @dataset, "/tmp/buildings.shp")
      assert_equal "buildings", result.layer_type
      assert_equal "postgis", result.source
      assert_equal "buildings", result.name
    end
  end
end
