module Trainmaster
  class UserMailer < ApplicationMailer

    def email_verification(user)
      @user = user
      mail(to: @user.username, subject: "[trainmaster] Email Confirmation")
    end

    def password_reset(user)
      @user = user
      mail(to: @user.username, subject: "[trainmaster] Password Reset")
    end
  end
end
