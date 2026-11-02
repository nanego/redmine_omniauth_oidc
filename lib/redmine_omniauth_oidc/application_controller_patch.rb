# frozen_string_literal: true

require_dependency 'application_controller'

module RedmineOmniauthOidc
  module ApplicationControllerPatch
    extend ActiveSupport::Concern

    # OIDC users are MFA-authenticated by the identity provider. When the bypass
    # is enabled, never force Redmine's own 2FA enrolment on an OIDC session.
    def check_twofa_activation
      if session[:logged_in_with_oidc] &&
         RedmineOmniauthOidc.settings_hash['bypass_twofa'] == '1'
        session.delete(:must_activate_twofa)
      end
      super
    end

    # Ignores the scheme and port of the url, which differ behind a reverse proxy,
    # and leaves every other check to the core method
    def validate_back_url(back_url)
      return false if back_url.blank? || !back_url.is_a?(String)

      uri = Addressable::URI.parse(back_url)
      return false if uri.host.present? && uri.host != request.host

      super(uri.omit(:scheme, :authority).to_s)
    rescue Addressable::URI::InvalidURIError
      false
    end

  end
end

ApplicationController.prepend RedmineOmniauthOidc::ApplicationControllerPatch
