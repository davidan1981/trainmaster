require 'test_helper'

module Trainmaster
  class SessionTest < ActiveSupport::TestCase

    test "session has token and secret when created" do
      session = Session.new(user: trainmaster_users(:one))
      assert_not_nil session.secret
      assert_not_nil session.token
      assert_equal Roles::USER, JWT.decode(session.token, nil, false)[0]["role"]
    end

    test "save a session" do
      session = Session.new(user: trainmaster_users(:one))
      assert session.save
    end

    test "cannot save a session without a user" do
      assert_raise do
        # Fails because no user has been passed in.
        Session.new()
      end
    end

  end
end
