# frozen_string_literal: true

require_dependency 'account_controller'

module RedmineOmniauthOidc
  module AccountControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :login_without_oidc,  :login
        alias_method :login,               :login_with_oidc
        alias_method :logout_without_oidc, :logout
        alias_method :logout,              :logout_with_oidc
      end
    end

    module InstanceMethods

      def login_with_oidc
        if oidc_settings["enabled"] == '1' && oidc_settings["replace_redmine_login"] == '1'
          # We use omniauth-rails_csrf_protection, so we must POST.
          # A redirect_to would generate a GET request which is rejected.
          render :inline => %Q{
            <form method="POST" action="/auth/openid_connect">
              <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
              <input type="hidden" name="origin" value="#{back_url}">
              <script>document.forms[0].submit();</script>
            </form>
          }
        else
          login_without_oidc
        end
      end

      # GET /auth/openid_connect — OmniAuth intercepts POST before reaching here.
      # Only reached on direct GET navigation (blocked).
      def login_with_oidc_redirect
        render_error :message => "Not Found", :status => 404
      end

      def login_with_oidc_callback
        auth = request.env["omniauth.auth"]

        # Hook where other plugins can react (e.g. create users on-the-fly)
        call_hook(:controller_account_before_oidc_login, { :params => params, :auth => auth, :cookies => cookies })

        user = find_user_from_oidc_auth(auth)

        if user.blank? && oidc_settings["auto_provision"] == '1'
          user = create_user_from_oidc(auth)
          if user.blank?
            logger.warn "Failed OIDC auto-provision for uid='#{auth['uid']}' / " \
                        "email='#{auth.dig('info', 'email')}' from #{request.remote_ip} at #{Time.now.utc}"
          end
        end

        if user.blank?
          logger.warn "Failed OIDC login for uid='#{auth['uid']}' / " \
                      "email='#{auth.dig('info', 'email')}' from #{request.remote_ip} at #{Time.now.utc}"
          error = l(:notice_account_invalid_credentials).sub(/\.$/, '')
          if oidc_settings["replace_redmine_login"] == '1'
            render_error({ :message => error.html_safe, :status => 403 })
            return false
          else
            flash[:error] = error
            redirect_to signin_url
          end
        else
          user.update_attribute(:last_login_on, Time.now)
          params[:back_url] = request.env["omniauth.origin"] unless request.env["omniauth.origin"].blank?

          # Capture end_session_endpoint and id_token before reset_session clears the context
          # Discovery populates client_options.end_session_endpoint during the callback phase
          strategy = request.env['omniauth.strategy']
          end_session_endpoint = strategy&.options&.dig(:client_options, :end_session_endpoint).to_s
          id_token = auth.dig('credentials', 'id_token').to_s

          successful_authentication(user)
          # Must be set AFTER successful_authentication because it calls reset_session
          session[:logged_in_with_oidc] = true
          session[:oidc_end_session_endpoint] = end_session_endpoint if end_session_endpoint.present?
          session[:oidc_id_token] = id_token if id_token.present?

          # Store authentication level: prefer 'auth_level' claim,
          # fall back to the standard OIDC 'acr' claim. Stored only when present.
          raw_info = auth.dig('extra', 'raw_info') || {}
          auth_level = raw_info['auth_level'].to_s.presence || raw_info['acr'].to_s.presence
          session[:oidc_auth_level] = auth_level if auth_level
        end
      end

      def login_with_oidc_failure
        error = 'error_oidc_' + (params[:message] || 'unknown')
        if oidc_settings["replace_redmine_login"] == '1'
          render_error({ :message => error.to_sym, :status => 500 })
          return false
        else
          flash[:error] = l(error.to_sym)
          redirect_to signin_url
        end
      end

      def logout_with_oidc
        if oidc_settings["enabled"] == '1' && session[:logged_in_with_oidc]
          end_session_url = session[:oidc_end_session_endpoint].presence
          id_token        = session[:oidc_id_token].presence
          logout_user
          if end_session_url.present?
            end_session_url = "#{end_session_url}?id_token_hint=#{CGI.escape(id_token)}" if id_token.present?
            redirect_to end_session_url, :allow_other_host => true
          else
            redirect_to home_url
          end
        else
          logout_without_oidc
        end
      end

      private

      def oidc_settings
        RedmineOmniauthOidc.settings_hash
      end

      # Look up an existing Redmine user from the OIDC auth hash.
      # Priority: email → uid claim (= login) → preferred_username
      def find_user_from_oidc_auth(auth)
        raw_info = auth.dig('extra', 'raw_info') || {}
        email    = auth.dig('info', 'email').to_s
        uid      = raw_info['uid'].to_s
        pref_un  = raw_info['preferred_username'].to_s

        User.find_by_mail(email) ||
          User.find_by_login(uid) ||
          User.find_by_login(pref_un)
      end

      # Create a new Redmine user from the OIDC auth hash (auto-provisioning).
      # Maps OIDC claims to Redmine user attributes.
      def create_user_from_oidc(auth)
        raw_info = auth.dig('extra', 'raw_info') || {}
        email    = auth.dig('info', 'email').to_s

        # Derive a login from uid, preferred_username, or the local part of email
        login = raw_info['uid'].presence ||
                raw_info['preferred_username'].presence ||
                email.split('@').first.to_s.downcase.gsub(/[^a-z0-9_\-]/, '_')

        # Make login unique if it already exists
        base_login = login
        suffix     = 1
        while User.find_by_login(login)
          login = "#{base_login}_#{suffix}"
          suffix += 1
        end

        status = oidc_settings['auto_provision_active'] == '1' ? User::STATUS_ACTIVE : User::STATUS_REGISTERED

        user = User.new(
          :login     => login,
          :mail      => email,
          :firstname => raw_info[RedmineOmniauthOidc.oidc_claim_firstname].to_s,
          :lastname  => raw_info[RedmineOmniauthOidc.oidc_claim_lastname].to_s,
          :language  => Setting.default_language,
          :status    => status
        )
        user.random_password
        if user.save
          logger.info "OIDC auto-provisioned user '#{login}' (#{email}) with status #{status}"
          journalize_user_auto_creation(user) if Redmine::Plugin.installed?(:redmine_admin_activity)
          user
        else
          logger.error "OIDC auto-provision failed for '#{login}' (#{email}): #{user.errors.full_messages.join(', ')}"
          nil
        end
      end

    end
  end
end

unless AccountController.included_modules.include? RedmineOmniauthOidc::AccountControllerPatch
  AccountController.send(:include, RedmineOmniauthOidc::AccountControllerPatch)
end

class AccountController
  include RedmineAdminActivity::Journalizable if Redmine::Plugin.installed?(:redmine_admin_activity)
  skip_before_action :verify_authenticity_token, only: [:login_with_oidc_callback]
end
