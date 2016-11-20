require 'test_helper'

module Trainmaster
  class SessionsControllerTest < ActionController::TestCase
    setup do
      Rails.cache.clear  # always clear cache first
      @routes = Engine.routes
      @session = trainmaster_sessions(:one)
      @token = @session.token
      @api_key = trainmaster_users(:one).api_key
    end

    test "public can see options" do
      get :options
      assert_response :success
    end

    test "user cannot list sessions with invalid token" do
      get :index, params: { token: "invalidtoken" }
      assert_response 401
    end

    test "user can list all his sessions" do
      get :index, params: { token: @token }
      assert_response :success
      sessions = assigns(:sessions)
      assert_not_nil sessions
      all_his_sessions = Session.where(user: @session.user)
      assert_equal sessions.length, all_his_sessions.length
      sessions.each do |session|
        assert session.user == @session.user
      end
    end

    test "user can list all his sessions with api key" do
      get :index, params: { api_key: @api_key }
      assert_response :success
      sessions = assigns(:sessions)
      assert_not_nil sessions
      all_his_sessions = Session.where(user: @session.user)
      assert_equal sessions.length, all_his_sessions.length
      sessions.each do |session|
        assert session.user == @session.user
      end
    end

    test "user can list all his sessions using user id in routing" do
      get :index, params: { user_id: @session.user.uuid, token: @token }
      assert_response :success
      sessions = assigns(:sessions)
      assert_not_nil sessions
      all_his_sessions = Session.where(user: @session.user)
      assert_equal sessions.length, all_his_sessions.length
      sessions.each do |session|
        assert session.user == @session.user
      end
    end

    test "user cannot list expired session" do
      session = Session.new(user: @session.user, seconds: -1)
      session.save()
      get :index, params: { user_id: session.user.uuid, token: @token }
      assert_response :success
      json = JSON.parse(@response.body)
      assert_equal 1, json.length
    end

    test "user cannot list other's sessions" do
      get :index, params: { user_id: trainmaster_users(:two), token: @token }
      assert_response 401
    end

    test "user cannot list other's sessions with api key" do
      get :index, params: { user_id: trainmaster_users(:two), api_key: @api_key }
      assert_response 401
    end

    test "public cannot list sessions" do
      get :index
      assert_response 401
    end

    test "create a session" do
      user = trainmaster_users(:one)
      post :create, params: { username: user.username, password: "password" }
      assert_response :success
      session = assigns(:session)
      assert_not_nil session
      json = JSON.parse(@response.body)
      assert json.has_key?("token")
      assert !json.has_key?("secret")
    end

    test "cannot create a session if not verified" do
      user = trainmaster_users(:one)
      user.verified = false
      user.save()
      post :create, params: { username: user.username, password: "password" }
      assert_response 401
    end

    test "cannot create a session with non-existent username" do
      post :create, params: { username: 'idontexist', password: "secret" }
      assert_response 401
      json = JSON.parse(@response.body)
      assert json["errors"].length == 1
    end

    test "cannot create a session without username" do
      post :create, params: { password: "secret" }
      assert_response 401
      json = JSON.parse(@response.body)
      assert json["errors"].length == 1
    end

    test "cannot create a session without a password" do
      post :create, params: { username: trainmaster_users(:one).username }
      assert_response 401
      json = JSON.parse(@response.body)
      assert json["errors"].length == 1
    end

    test "cannot create a session with a wrong password" do
      post :create, params: { username: trainmaster_users(:one).username, password: "notsecret" }
      assert_response 401
      json = JSON.parse(@response.body)
      assert json["errors"].length == 1
    end

    test "user can create session using existing auth" do
      post :create, params: { token: @token }
      assert_response 201
    end

    test "user can create session using oauth" do
      auth_hash = OmniAuth::AuthHash.new()
      auth_hash.provider = "someauthprovider"
      auth_hash.uid = "someuniqueid"
      auth_hash.info = OmniAuth::AuthHash::InfoHash.new()
      auth_hash.info.name = "someusername"
      Credentials = Struct.new("Credentials", :token, :expires_at)
      auth_hash.credentials = Credentials.new("sometoken", Time.now.to_i)
      @request.env["omniauth.auth"] = auth_hash
      post :create
      assert_response 302
      user = User.find_by_oauth_provider_and_oauth_uid("someauthprovider", "someuniqueid")
      session = Session.find_by_user_uuid(user.uuid)
      assert_includes @response.location, session.token
    end

    test "user can show session" do
      get :show, params: { id: 1, token: @token }
      assert_response 200
      json = JSON.parse(@response.body)
      assert_equal @token, json["token"]
      # Do a quick cache check
      session = Cache.get(kind: :session, token: json["token"])
      assert_not_nil session
      assert_equal @token, session.token
    end

    test "user can show session using api key" do
      get :show, params: { id: 1, api_key: @api_key }
      assert_response 200
      json = JSON.parse(@response.body)
      assert_equal @token, json["token"]
    end

    test "user can show current session" do
      get :show, params: { id: "current", token: @token }
      assert_response 200
      json = JSON.parse(@response.body)
      assert_equal @token, json["token"]
    end

    test "user cannot show current session with api key" do
      get :show, params: { id: "current", api_key: @api_key }
      assert_response 404
    end

    test "user cannot show other's session" do
      get :show, params: { id: 2, token: @token }
      assert_response 401
    end

    test "user cannot show other's session with api key" do
      get :show, params: { id: 2, api_key: @api_key }
      assert_response 401
    end

    test "user cannot show expired session" do
      session = Session.new(user: @session.user, seconds: -1)
      session.save()
      get :show, params: { id: session.uuid, token: @token }
      assert_response 404
    end

    test "user cannot show expired session with api key" do
      session = Session.new(user: @session.user, seconds: -1)
      session.save()
      get :show, params: { id: session.uuid, api_key: @api_key }
      assert_response 404
    end

    test "public cannot show session" do
      get :show, params: { id:1 }
      assert_response 401
    end

    test "admin can show other's session" do
      @session = trainmaster_sessions(:admin_one)
      @token = @session.token
      get :show, params: { id: 1, token: @token }
      assert_response :success
      json = JSON.parse(@response.body)
      session = trainmaster_sessions(:one)
      assert_equal session.token, json["token"]
    end

    test "admin can show other's session with api key" do
      @session = trainmaster_sessions(:admin_one)
      @token = @session.token
      get :show, params: { id: 1, api_key: @api_key }
      assert_response :success
      json = JSON.parse(@response.body)
      session = trainmaster_sessions(:one)
      assert_equal session.token, json["token"]
    end

    test "user cannot show nonexisting session" do
      get :show, params: { id: 999, token: @token }
      assert_response 404
      json = JSON.parse(@response.body)
      assert json["errors"].length == 1
    end

    test "user can delete session" do
      delete :destroy, params: { id: 1, token: @token }
      assert_response 204
    end

    test "user can delete session with api key" do
      delete :destroy, params: { id: 1, api_key: @api_key }
      assert_response 204
    end

    test "user can delete a current session" do
      delete :destroy, params: { id: "current", token: @token }
      assert_response 204
    end

    test "user cannot delete a current session with api key" do
      delete :destroy, params: { id: "current", api_key: @api_key }
      assert_response 404
    end

    test "user cannot delete a non-existent session" do
      delete :destroy, params: { id: 999, token: @token }
      assert_response 404
    end

    test "user cannot delete other's session" do
      delete :destroy, params: { id: 2, token: @token }
      assert_response 401
    end

    test "admin can delete other's session" do
      @session = trainmaster_sessions(:admin_one)
      @token = @session.token
      delete :destroy, params: { id: 1, token: @token }
      assert_response :success
    end

  end
end
