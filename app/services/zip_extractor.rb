# frozen_string_literal: true

require "fileutils"
require "zip"

class ZipExtractor
  MAX_SIZE = 1.gigabyte
  MAX_FILES = 10_000
  ALLOWED_EXTENSIONS = %w[.txt .csv .json .xml .pdf .jpg .png].freeze

  def initialize(zip_path:, destination:)
    @zip_path = zip_path
    @destination = File.expand_path(destination)
    @extracted_size = 0
    @file_count = 0
  end

  def extract(allowed_extensions: ALLOWED_EXTENSIONS)
    normalized_extensions = normalize_extensions(allowed_extensions)

    validate_destination

    Zip::File.open(@zip_path) do |zip_file|
      zip_file.each do |entry|
        validate_entry(entry, normalized_extensions)
        extract_entry(entry)
      end
    end

    {
      success: true,
      files_extracted: @file_count,
      total_size: @extracted_size
    }
  rescue StandardError => error
    details = [ "#{error.class}: #{error.message}", error.backtrace&.first ].compact.join(" at ")
    { success: false, error: details }
  end

  private

  def validate_destination
    FileUtils.mkdir_p(@destination) unless Dir.exist?(@destination)
  end

  def validate_entry(entry, allowed_extensions)
    canonical_path = entry_output_path(entry)
    unless canonical_path.start_with?(@destination + File::SEPARATOR)
      raise "Path traversal detected: #{entry.name}"
    end

    return if entry.directory?

    @file_count += 1
    raise "Too many files in archive (max: #{MAX_FILES})" if @file_count > MAX_FILES

    @extracted_size += entry.size
    raise "Archive too large (max: #{MAX_SIZE} bytes)" if @extracted_size > MAX_SIZE

    extension = File.extname(entry.name).downcase
    return if allowed_extensions.include?(extension)

    raise "Disallowed file type: #{extension.presence || '(none)'}"
  end

  def extract_entry(entry)
    output_path = entry_output_path(entry)

    if entry.directory?
      FileUtils.mkdir_p(output_path)
      return
    end

    FileUtils.mkdir_p(File.dirname(output_path))
    File.open(output_path, "wb") do |file|
      entry.get_input_stream do |input_stream|
        IO.copy_stream(input_stream, file)
      end
    end
  end

  def entry_output_path(entry)
    File.expand_path(File.join(@destination, entry.name))
  end

  def normalize_extensions(extensions)
    extensions.map do |extension|
      normalized = extension.to_s.downcase
      normalized.start_with?(".") ? normalized : ".#{normalized}"
    end
  end
end
