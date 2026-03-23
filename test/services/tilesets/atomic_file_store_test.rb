# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Tilesets
  class AtomicFileStoreTest < ActiveSupport::TestCase
    setup do
      @root_dir = Dir.mktmpdir("tilesets-store-test")
      @store = AtomicFileStore.new(root_path: @root_dir)
    end

    teardown do
      FileUtils.remove_entry(@root_dir) if @root_dir && Dir.exist?(@root_dir)
    end

    test "writes file atomically to destination path" do
      @store.write(relative_path: "tilesets/projects/1/buildings/v1/tileset.json", content: '{"asset":{"version":"1.1"}}')

      destination = File.join(@root_dir, "tilesets/projects/1/buildings/v1/tileset.json")
      assert File.exist?(destination)
      assert_equal '{"asset":{"version":"1.1"}}', File.read(destination)

      temp_files = Dir.glob(File.join(File.dirname(destination), ".tileset.json.tmp-*"))
      assert_empty temp_files
    end

    test "moves staged file into published path" do
      staged_path = "tilesets/staging/projects/1/buildings/v2/tileset.json"
      published_path = "tilesets/projects/1/buildings/v2/tileset.json"

      @store.write(relative_path: staged_path, content: "staged")
      destination = @store.move(from_relative_path: staged_path, to_relative_path: published_path)

      assert_equal File.join(@root_dir, published_path), destination
      assert_equal "staged", File.read(destination)
      assert_not File.exist?(File.join(@root_dir, staged_path))
    end

    test "rejects paths outside root_path" do
      assert_raises(ArgumentError) do
        @store.write(relative_path: "../outside.json", content: "{}")
      end
    end
  end
end
