# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
  end

  test "should get index" do
    get projects_url

    assert_response :success
  end

  test "should get new" do
    get new_project_url

    assert_response :success
  end

  test "should create project" do
    assert_difference("Project.count") do
      post projects_url, params: {
        project: {
          name: "Harbor Expansion",
          location: "Pier 5",
          description: "Structural retrofit and expansion."
        }
      }
    end

    created_project = Project.order(:created_at).last
    assert_redirected_to project_url(created_project)
    assert_equal I18n.t("projects.create.created"), flash[:notice]
  end

  test "should not create project with invalid params" do
    assert_no_difference("Project.count") do
      post projects_url, params: {
        project: {
          name: "",
          location: "",
          description: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show project" do
    get project_url(@project)

    assert_response :success
  end

  test "should get edit" do
    get edit_project_url(@project)

    assert_response :success
  end

  test "should update project" do
    patch project_url(@project), params: {
      project: {
        name: "#{@project.name} Updated"
      }
    }

    assert_redirected_to project_url(@project)
    assert_equal I18n.t("projects.update.updated"), flash[:notice]
    assert_equal "#{projects(:one).name} Updated", @project.reload.name
  end

  test "should not update project with invalid params" do
    patch project_url(@project), params: {
      project: {
        name: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy project" do
    assert_difference("Project.count", -1) do
      delete project_url(@project)
    end

    assert_redirected_to projects_url
    assert_equal I18n.t("projects.destroy.destroyed"), flash[:notice]
  end
end
