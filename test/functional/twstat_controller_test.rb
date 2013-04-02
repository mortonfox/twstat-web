require 'test_helper'

class TwstatControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get dashboard" do
    get :dashboard
    assert_response :success
  end

  test "should get report" do
    get :report
    assert_response :success
  end

end
