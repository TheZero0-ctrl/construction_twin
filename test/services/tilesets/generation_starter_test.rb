# frozen_string_literal: true

require "test_helper"

module Tilesets
  class GenerationStarterTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
    end

    test "creates tileset and enqueues generation when none exists" do
      map_layer = map_layers(:one_buildings)

      assert_enqueued_with(job: GenerateTilesetJob) do
        tileset = GenerationStarter.new(map_layer: map_layer).call
        assert_equal map_layer, tileset.map_layer
      end
    end

    test "does not enqueue when tileset is generating" do
      map_layer = map_layers(:one_buildings)
      map_layer.create_tileset!(status: :generating)

      assert_no_enqueued_jobs only: GenerateTilesetJob do
        GenerationStarter.new(map_layer: map_layer).call
      end
    end

    test "does not enqueue when tileset is publishing" do
      map_layer = map_layers(:one_buildings)
      map_layer.create_tileset!(status: :publishing)

      assert_no_enqueued_jobs only: GenerateTilesetJob do
        GenerationStarter.new(map_layer: map_layer).call
      end
    end
  end
end
