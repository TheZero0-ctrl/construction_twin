# frozen_string_literal: true

require "test_helper"

class Projects::LayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @layer = map_layers(:one)
  end

  test "returns project layer payload" do
    get project_layers_url(@project), as: :json

    assert_response :success

    payload = response.parsed_body
    assert_equal @project.id, payload.fetch("project_id")
    assert_equal 1, payload.fetch("layers").size
    assert_equal @layer.id, payload.fetch("layers").first.fetch("id")
  end

  test "updates layer visibility" do
    patch project_layer_url(@project, @layer), params: { layer: { visible: false } }, as: :json

    assert_response :success
    assert_equal false, @layer.reload.visible
  end
end
