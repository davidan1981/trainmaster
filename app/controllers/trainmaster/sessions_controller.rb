require_dependency "trainmaster/application_controller"

module Trainmaster

  ##
  # This class is sessions controller that performs CRD on session objects.
  # Note that a token includes its session ID. Use "current" to look up a
  # session in the current context.
  #
  class SessionsController < ApplicationController

    prepend_before_action :require_auth, except: [:create, :options]
    before_action :get_session, only: [:show, :destroy]
    before_action :get_user, only: [:index]

    ##
    # Lists all sessions that belong to the specified or authenticated user.
    #
    def index
      @sessions = Session.where(user: @user)
      expired = []
      active = []
      @sessions.each do |session|
        if session.expired?
          expired << session.uuid
        else
          active << session
        end
      end
      SessionsCleanupJob.perform_later(*expired)
      render json: active, except: [:secret]
    end

    ##
    # This action is essentially the login action. Note that get_user is not
    # triggered for this action because we will look at username first. That
    # would be the "normal" way to login. The alternative would be with the
    # token based authentication. If the latter doesn't make sense, just use
    # the username and password approach.
    #
    # A ApplicationController::UNAUTHORIZED_ERROR is thrown if user is not
    # verified.
    #
    def create

      # See if OAuth is used first. When authenticated successfully, either
      # the existing user will be found or a new user will be created.
      # Failure will be redirected to this action but will not match this
      # branch.
      if (omniauth_hash = request.env["omniauth.auth"])
        @user = User.from_omniauth_hash(omniauth_hash)

      # Then see if the request already has authentication. Note that if the
      # user does not have access to the specified session owner, 401 will
      # be thrown.
      elsif accept_auth
        @user = @auth_user

      # Otherwise, it's a normal login process. Use username and password to
      # authenticate. The user must exist, the password must be vaild, and
      # the email must have been verified.
      else
        @user = User.find_by_username(session_params[:username])
        if (@user.nil? || !@user.authenticate(session_params[:password]) ||
            !@user.verified)
          raise ApplicationController::UNAUTHORIZED_ERROR
        end
      end

      # Finally, create session regardless of the method and store it.
      @session = Session.new(user: @user)
      if @session.save
        if omniauth_hash
          # redirect_to the app page that accepts new session token
          url = Rails.application.config.oauth_landing_page_url
          url = "#{url}?token=#{@session.token}"
          render inline: "", status: 302, location: url
        else
          render json: @session, except: [:secret], status: 201
        end
      else
        # :nocov:
        render_errors 400, @session.full_error_messages
        # :nocov:
      end
    end

    ##
    # Shows a session information.
    #
    def show
      render json: @session, except: [:secret]
    end

    ##
    # Deletes a session.
    #
    def destroy
      if @session.destroy
        render body: "", status: 204
      else
        # :nocov:
        render_error 400, @session.errors.full_messages
        # :nocov:
      end
    end

    private

      ##
      # Get the specified or current session.
      #
      # A Repia::Errors::NotFound is raised if the session does not
      # exist (or deleted due to expiration).
      #
      # A ApplicationController::UNAUTHORIZED_ERROR is raised if the
      # authenticated user does not have authorization for the specified
      # session.
      #
      def get_session
        session_id = params[:id]
        if session_id == "current"
          if @auth_session.nil?
            raise Repia::Errors::NotFound
          end
          session_id = @auth_session.id
        end
        @session = find_object(Session, session_id)
        authorize_for!(@session)
        if @session.expired?
          @session.destroy
          raise Repia::Errors::NotFound
        end
      end

      def session_params
        params.permit(:username, :password)
      end

  end
end
