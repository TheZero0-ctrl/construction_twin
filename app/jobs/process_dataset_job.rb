# frozen_string_literal: true

class ProcessDatasetJob < ApplicationJob
  queue_as :default

  def perform(dataset)
    dataset.update!(status: :processing)
    dataset.update_info_message!("Placeholder processing completed. Spatial import is not implemented yet.")
    dataset.update!(status: :completed)
  rescue StandardError => error
    dataset.update!(status: :failed, info: failure_info(dataset, error)) if dataset&.persisted?
    raise
  end

  private

  def failure_info(dataset, error)
    current_info = dataset.info.is_a?(Hash) ? dataset.info : {}
    current_info.merge("message" => error.message)
  end
end
