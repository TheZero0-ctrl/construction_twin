# frozen_string_literal: true

class Projects::DatasetsController < ApplicationController
  before_action :set_project

  def create
    selected_layer_type = dataset_params[:layer_type].presence || "buildings"
    upload = dataset_params[:file]
    @dataset = @project.datasets.build(
      data_type: dataset_params[:data_type],
      layer_type: selected_layer_type,
      status: :uploaded
    )

    unless upload.present?
      @dataset.errors.add(:file, :must_be_attached)
      flash.now[:alert] = t(".missing_file")
      return render_create_change(status: :unprocessable_entity)
    end

    @dataset.file.attach(upload)

    saved = false
    @project.with_lock do
      existing_dataset = @project.datasets
        .where(layer_type: selected_layer_type)
        .where.not(id: @dataset.id)
        .order(created_at: :desc)
        .first

      saved = @dataset.save
      existing_dataset&.destroy! if saved && existing_dataset.present?
    end

    if saved
      ProcessDatasetJob.perform_later(@dataset.id)
      flash.now[:notice] = t(".created")
      render_create_change
    else
      flash.now[:alert] = t(".create_failed")
      render_create_change(status: :unprocessable_entity)
    end
  end

  private

  def datasets_scope
    @project.datasets.recently_uploaded
  end

  def set_project
    @project = Project.find(params.expect(:project_id))
  end

  def dataset_params
    params.expect(dataset: [ :data_type, :layer_type, :file ])
  end

  def render_create_change(status: :created)
    form_dataset = status == :created ? @project.datasets.build : @dataset

    render(
      turbo_stream: [
        turbo_stream.replace(
          "datasets-container",
          partial: "projects/datasets",
          locals: { datasets: datasets_scope, project: @project, dataset: form_dataset }
        ),
        turbo_stream.replace("flash", partial: "layouts/flash")
      ],
      status: status
    )
  end
end
