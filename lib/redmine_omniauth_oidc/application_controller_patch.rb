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

    # Returns a validated URL string if back_url is a valid url for redirection,
    # otherwise false
    def validate_back_url(back_url)
      return false if back_url.blank?

      if CGI.unescape(back_url).include?('..')
        return false
      end

      begin
        uri = Addressable::URI.parse(back_url)
        ## PATCHED : ignore scheme HTTPS/HTTP and port so redirection works behind reverse proxies
        [:host].each do |component|
          if uri.send(component).present? && uri.send(component) != request.send(component)
            return false
          end
        end
        # Remove unnecessary components to convert the URL into a relative URL
        uri.omit!(:scheme, :authority)
      rescue Addressable::URI::InvalidURIError
        return false
      end

      path = uri.to_s
      # Ensure that the remaining URL starts with a slash, followed by a
      # non-slash character or the end
      unless %r{\A/([^/]|\z)}.match?(path)
        return false
      end

      if %r{/(login|account/register|account/lost_password)}.match?(path)
        return false
      end

      if relative_url_root.present? && !path.starts_with?(relative_url_root)
        return false
      end

      return path
    end

  end
end

ApplicationController.prepend RedmineOmniauthOidc::ApplicationControllerPatch
