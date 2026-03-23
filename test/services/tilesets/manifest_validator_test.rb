# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Tilesets
  class ManifestValidatorTest < ActiveSupport::TestCase
    setup do
      @tmp_dir = Dir.mktmpdir("tileset-manifest-validator")
      @validator = ManifestValidator.new
      @path = File.join(@tmp_dir, "tileset.json")
    end

    teardown do
      FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
    end

    test "validates a minimal valid 3d tiles manifest" do
      File.write(@path, <<~JSON)
        {
          "asset": { "version": "1.1" },
          "geometricError": 500,
          "root": {
            "boundingVolume": { "region": [0, 0, 0, 0, 0, 0] },
            "geometricError": 0
          }
        }
      JSON

      result = @validator.validate(@path)

      assert_equal true, result[:success]
      assert_nil result[:error]
    end

    test "fails when manifest file is missing" do
      result = @validator.validate(File.join(@tmp_dir, "missing.json"))

      assert_equal false, result[:success]
      assert_equal "manifest file not found", result[:error]
    end

    test "fails when required keys are missing" do
      File.write(@path, '{"asset":{"version":"1.1"}}')

      result = @validator.validate(@path)

      assert_equal false, result[:success]
      assert_match(/manifest missing required keys/, result[:error])
    end

    test "fails when manifest is invalid json" do
      File.write(@path, "{not_json}")

      result = @validator.validate(@path)

      assert_equal false, result[:success]
      assert_equal "manifest is not valid JSON", result[:error]
    end
  end
end
