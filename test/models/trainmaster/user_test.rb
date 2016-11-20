require 'test_helper'

module Trainmaster
  class UserTest < ActiveSupport::TestCase
    test "user is not valid without a username" do
      user = User.new(password: "secret")
      assert_not user.save
    end

    test "user is not valid without a password" do
      user = User.new(username: "foo@example.com")
      assert_not user.save
    end

    test "user is valid with username and password" do
      user = User.new(username: "foo@example.com", password: "secret")
      assert user.save
    end

    test "user can issue a reset token" do
      user = User.new(username: "foo@example.com", password: "secret")
      assert user.save
      assert_nil user.reset_token
      user.issue_token(:reset_token)
      assert_not_nil user.reset_token
    end

    test "user can issue a verification token" do
      user = User.new(username: "foo@example.com", password: "secret")
      assert user.save
      old = user.verification_token
      user.issue_token(:verification_token)
      assert_not_equal old, user.verification_token
    end

    test "user is not valid if username is malformatted" do
      user = User.new(username: "example.com", password: "secret")
      assert_not user.save
    end

    test "user is not valid if username already exists" do
      user = User.new(username: "one@example.com", password: "secret")
      assert_not user.save
    end

    test "user has a role of 100 by default" do
      user = User.new(username: "new@example.com", password: "secret")
      user.save
    end

  end
end
