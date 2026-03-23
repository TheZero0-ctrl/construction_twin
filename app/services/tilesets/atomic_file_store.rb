# frozen_string_literal: true

require "fileutils"
require "securerandom"

module Tilesets
  class AtomicFileStore
    def initialize(root_path: Rails.root.join("public"))
      @root_path = root_path.to_s
    end

    def write(relative_path:, content:)
      destination = absolute_path(relative_path)
      directory = File.dirname(destination)
      FileUtils.mkdir_p(directory)

      temp_path = File.join(directory, ".#{File.basename(destination)}.tmp-#{SecureRandom.hex(8)}")

      File.open(temp_path, "wb") { |file| file.write(content) }
      File.rename(temp_path, destination)

      destination
    rescue StandardError
      FileUtils.rm_f(temp_path) if defined?(temp_path) && temp_path
      raise
    end

    def move(from_relative_path:, to_relative_path:)
      source = absolute_path(from_relative_path)
      destination = absolute_path(to_relative_path)
      FileUtils.mkdir_p(File.dirname(destination))
      File.rename(source, destination)
      destination
    end

    private

    attr_reader :root_path

    def absolute_path(relative_path)
      File.expand_path(relative_path.to_s, root_path)
    end
  end
end
