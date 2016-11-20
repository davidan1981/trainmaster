module Trainmaster
  class User < ActiveRecord::Base
    include Repia::Support::UUIDModel
    acts_as_paranoid
    has_secure_password validations: false

    validates :username, uniqueness: true,
              format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i,
                        on: [:create, :update] }, allow_nil: true
    validates :password, confirmation: true
    validate :valid_user
    before_save :default_role

    alias_attribute :email, :username

    ##
    # This method validates if the user object is valid. A user is valid if
    # username and password exist OR oauth integration exists.
    #
    def valid_user
      if (self.username.blank? || self.password_digest.blank?) &&
          (self.oauth_provider.blank? || self.oauth_uid.blank?)
        errors.add(:username, " and password OR oauth must be specified")
      end
    end

    ##
    # Create a user from oauth.
    #
    def self.from_omniauth_hash(auth_hash)
      params = {
        oauth_provider: auth_hash.provider,
        oauth_uid: auth_hash.uid
      }
      where(params).first_or_initialize(attributes={}) do |user|
        user.oauth_provider = auth_hash.provider
        user.oauth_uid = auth_hash.uid
        user.oauth_name = auth_hash.info.name
        user.oauth_token = auth_hash.credentials.token
        user.oauth_expires_at = Time.at(auth_hash.credentials.expires_at)
        user.verified = true
        user.save!
      end
    end

    ##
    # Initializes the user. User is not verified initially. The user has one
    # hour to get verified. After that, a PATCH request must be made to
    # re-issue the verification token.
    #
    def initialize(attributes = {})
      attributes[:api_key] = SecureRandom.hex(32)
      super
    end

    ##
    # Sets the default the role for the user if not set.
    #
    def default_role
      self.role ||= Roles::USER
    end

    ##
    # This method will generate a reset token that lasts for an hour.
    #
    def issue_token(kind)
      session = Session.new(user: self, seconds: 3600)
      session.save
      if kind == :reset_token
        self.reset_token = session.token
      elsif kind == :verification_token
        self.verification_token = session.token
      end
    end

  end
end
