module Trainmaster
  module ApplicationHelper
    include Repia::Helper::Base

    # Respect the config first. If not specified, use 401 Unauthorized.
    UNAUTHORIZED_ERROR = Rails.application.config.try(:unauthorized_error) ||
        Repia::Errors::Unauthorized

    ##
    # Determines if the authenticated user is admin or not.
    #
    def has_admin_auth?
      return instance_variable_defined?(:@auth_user) &&
          @auth_user.try(:role).try(:>=, Roles::ADMIN)
    end

    ##
    # Helper method to get the user object in the request, which is
    # specified by :user_id parameter. There are two ways to specify the
    # user id--one in the routing or the auth context.
    #
    # A UNAUTHORIZED_ERROR is raised if the authenticated user is
    # not authorized for the specified user information.
    #
    # A Repia::Errors::NotFound is raised if the specified user cannot
    # be found.
    #
    def get_user(fallback: true)
      user_id = params[:user_id]
      logger.debug("Attempting to get user #{user_id}")
      if !user_id.nil? && user_id != "current"
        @user = find_object(User, params[:user_id])  # will throw error if nil
        authorize_for!(@user)
      elsif fallback || user_id == "current"
        @user = @auth_user
      else
        # :nocov:
        raise Repia::Errors::NotFound, "User #{user_id} does not exist"
        # :nocov:
      end
    end

    ##
    # :method: require_auth
    #
    # Requires authentication. Either token or api key must be present.
    #

    ##
    # :method: require_admin_auth
    #
    # Requires admin authentication. Either token or api key of admin must
    # be present.
    #

    ##
    # :method: accept_auth
    #
    # Accepts authentication if present. Either token or api key is accepted.
    #

    ##
    # :method: require_token
    #
    # Requires authentication. Token must be present.
    #

    ##
    # :method: require_admin_token
    #
    # Requires admin authentication. Admin token must # be present.
    #

    ##
    # :method: accept_token
    #
    # Accepts authentication if present. Only token is accepted.
    #
    ##
    # :method: require_api_key
    #
    # Requires authentication. API key must be present.
    #

    ##
    # :method: require_admin_api_key
    #
    # Requires admin authentication. Admin api key must be present.
    #

    ##
    # :method: accept_api_key
    #
    # Accepts authentication if present. Only api key is accepted.
    #

    #
    # Metaprogramming baby
    #
    ["auth", "token", "api_key"].each do |suffix|

      define_method "require_#{suffix}" do
        self.method("get_#{suffix}").call
      end

      define_method "require_admin_#{suffix}" do
        self.method("get_#{suffix}").call(required_role: Roles::ADMIN)
      end

      define_method "accept_#{suffix}" do
        begin
          self.method("get_#{suffix}").call
        rescue StandardError
          logger.debug("Suppressing error")
          return false
        end
      end
    end

    ##
    # Determines if the user is authorized for the object. The user must be
    # either the creator of the object or must be an admin or above.
    #
    def authorized_for?(obj)
      logger.debug("Checking to see if authorized to access object")
      if @auth_user.nil?
        # :nocov:
        return false
        # :nocov:
      elsif @auth_user.role >= Roles::ADMIN
        return true
      elsif obj.is_a? User
        return obj == @auth_user
      else
        return obj.try(:user) == @auth_user
      end
    end
    alias_method :authorize_for?, :authorized_for?

    ##
    # Deprecated: use authorized_for? instead.
    #
    def authorized?(obj); authorized_for?(obj) end

    ##
    # Authorize the user for a specified object. If the user does not have
    # permission, it will throw an exception. Note that it is sometimes not
    # desirable to provide detailed information about authorization failure.
    # Note that this will not include this detail in the exception.
    #
    # A UNAUTHORIZED_ERROR is raised.
    #
    def authorize_for!(obj)
      if !authorized_for?(obj)
        logger.error("User #{@auth_user.uuid} does not have permission " +
                     "to access #{obj}")
        raise UNAUTHORIZED_ERROR, "User is not authorized"
      end
    end

    protected

      ##
      # Attempts to retrieve the payload encoded in the token. It checks if
      # the token is "valid" according to JWT definition and not expired.
      #
      # A UNAUTHORIZED_ERROR is raised if token cannot be decoded.
      #
      def get_token_payload(token)

        # Attempt to decode without verifying. May raise DecodeError.
        decoded = JWT.decode token, nil, false
        payload = decoded[0]

        # At this point, we know that the token is not expired and
        # well formatted. Find out if the payload is well defined.
        if payload.nil?
          # :nocov:
          logger.error("Token payload is nil: #{token}")
          raise UNAUTHORIZED_ERROR, "Invalid token"
          # :nocov:
        end

        return payload

      rescue JWT::DecodeError => e
        logger.error("Token decode error: #{e.message}")
        raise UNAUTHORIZED_ERROR, "Invalid token"
      end

      ##
      # Truly verifies the token and its payload. It ensures the user and
      # session specified in the token payload are indeed valid. The
      # required role is also checked.
      #
      # A UNAUTHORIZED_ERROR is thrown for all cases where token is
      # invalid.
      #
      def verify_token(token)
        logger.debug("Verifying token: #{token}")

        # First get the payload of the token. This will also verify whether
        # or not the token is welformed.
        payload = get_token_payload(token)

        # Next, the payload should define user UUID and session UUID.
        user_uuid = payload["user_uuid"]
        session_uuid = payload["session_uuid"]
        if user_uuid.nil? || session_uuid.nil?
          logger.error("User or session is not specified")
          raise UNAUTHORIZED_ERROR, "Invalid token"
        end
        logger.debug("Token well defined: #{token}")

        # But, the user UUID and session UUID better be valid too. That is,
        # they must be real user and session, and the session must belong to
        # the user.
        auth_user = User.find_by_uuid(user_uuid)
        if auth_user.nil?
          # :nocov:
          logger.error("Specified user doesn't exist #{user_uuid}")
          raise UNAUTHORIZED_ERROR, "Invalid token"
          # :nocov:
        end
        auth_session = Session.find_by_uuid(session_uuid)
        if auth_session.nil? || auth_session.user != auth_user
          logger.error("Specified session doesn't exist #{session_uuid}")
          raise UNAUTHORIZED_ERROR, "Invalid token"
        end

        # Finally, decode the token using the secret. Also check expiration
        # here too.
        JWT.decode token, auth_session.secret, true
        logger.debug("Token well formatted and verified. Set cache.")

        # Return the corresponding session
        return auth_session

      rescue JWT::DecodeError => e
        logger.error(e.message)
        raise UNAUTHORIZED_ERROR, "Invalid token"
      end

      ##
      # Attempt to get a token for the session. Token must be specified in
      # query string or part of the JSON object.
      #
      # Raises a UNAUTHORIZED_ERROR if cached session has less role
      # than what's required.
      #
      def get_token(required_role: Roles::PUBLIC)
        token = params[:token]

        # Look up the cache. If present, use it and skip the verification.
        # Use token itself (and not a session UUID) as part of the key so
        # it can be considered *verified*.
        @auth_session = Cache.get(kind: :session, token: token)

        # Cache miss. So proceed to verify the token and get user and
        # session data from database. Then set the cache for later.
        if @auth_session.nil?
          @auth_session = verify_token(token)
          @auth_session.role  # NOTE: no-op
          Cache.set({kind: :session, token: token}, @auth_session)
        end

        # Obtained session may not have enough permission. Check here.
        if @auth_session.role < required_role
          logger.error("Not enough permission (role: #{@auth_session.role})")
          raise UNAUTHORIZED_ERROR, "Invalid token"
        end
        @auth_user = @auth_session.user
        @token = @auth_session.token
        return true
      end

      ##
      # Get API key from the request.
      #
      # Raises a UNAUTHORIZED_ERROR if API key is not valid (or not
      # provided).
      #
      def get_api_key(required_role: Roles::PUBLIC)
        api_key = params[:api_key]
        if api_key.nil?
          # This case is not likely, but as a safeguard in case migration
          # has not gone well.
          # :nocov:
          raise UNAUTHORIZED_ERROR, "Invalid api key"
          # :nocov:
        end
        auth_user = User.find_by_api_key(api_key)
        if auth_user.nil? || auth_user.role < required_role
          raise UNAUTHORIZED_ERROR, "Invalid api key"
        end
        @auth_user = auth_user
        @auth_session = nil
        @token = nil
        return true
      end

      ##
      # Get auth data from the request. The token takes the precedence.
      #
      def get_auth(required_role: Roles::USER)
        if params[:token]
          get_token(required_role: required_role)
        else
          get_api_key(required_role: required_role)
        end
      end
  end
end
