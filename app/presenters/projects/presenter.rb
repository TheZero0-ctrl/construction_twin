# frozen_string_literal: true

class Projects::Presenter
  attr_reader :resource, :options

  def initialize(resource = nil, **options)
    @resource = resource
    @options = options
  end

  def to_h
    raise NotImplementedError
  end

  def as_json(*)
    to_h
  end
end
