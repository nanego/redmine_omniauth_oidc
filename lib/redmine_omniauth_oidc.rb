# frozen_string_literal: true

module RedmineOmniauthOidc
  # Marker param sent by the optional second login button (see below).
  SECOND_BUTTON_PARAM = 'oidc_acr'

  class << self
    def settings_hash
      Setting["plugin_redmine_omniauth_oidc"]
    end

    def enabled?
      settings_hash["enabled"] == '1'
    end

    def yaml_config_path
      @yaml_config_path ||= File.join(Rails.root, 'config', 'omniauth_oidc.yml')
    end

    def yaml_config_exists?
      File.exist?(yaml_config_path) && File.readable?(yaml_config_path)
    end

    def yaml_config
      return @yaml_config if defined?(@yaml_config)

      if yaml_config_exists?
        begin
          content = File.read(yaml_config_path)
          @yaml_config = YAML.safe_load(content) || {}
          Rails.logger.info "Loaded OIDC configuration from YAML: #{yaml_config_path}"
        rescue => e
          Rails.logger.error "Error loading OIDC YAML config: #{e.message}"
          @yaml_config = {}
        end
      else
        @yaml_config = {}
      end

      @yaml_config
    end

    def from_yaml_config_file?(setting_name)
      case setting_name
      when 'oidc_issuer_url', 'oidc_client_id', 'oidc_client_secret'
        yaml_config[setting_name].present?
      else
        false
      end
    end

    # Priority: YAML > Database settings
    def oidc_issuer_url
      yaml_config['oidc_issuer_url'].presence || settings_hash['oidc_issuer_url'].presence
    end

    # Priority: YAML > Database settings
    def oidc_client_id
      yaml_config['oidc_client_id'].presence || settings_hash['oidc_client_id'].presence || ''
    end

    # Priority: YAML > Database settings
    def oidc_client_secret
      yaml_config['oidc_client_secret'].presence || settings_hash['oidc_client_secret'].presence || ''
    end

    def oidc_scope
      settings_hash['oidc_scope'].presence || 'openid profile email'
    end

    def oidc_scope_array
      oidc_scope.split(/[\s,]+/).map(&:to_sym)
    end

    def oidc_uid_field
      settings_hash['oidc_uid_field'].presence || 'email'
    end

    def label_login_with_oidc
      settings_hash['label_login_with_oidc']
    end

    def oidc_claim_firstname
      settings_hash['oidc_claim_firstname'].presence || 'given_name'
    end

    def oidc_claim_lastname
      settings_hash['oidc_claim_lastname'].presence || 'family_name'
    end

    # Extra parameters appended to the OIDC authorization request, configured
    # as a free-form string by the administrator (one `key=value` per line, or
    # separated by `&`).
    def oidc_extra_authorize_params
      settings_hash['extra_authorize_params'].to_s.split(/[\n&]+/).filter_map do |pair|
        key, value = pair.split('=', 2)
        key = key.to_s.strip
        next if key.empty?

        [key, value.to_s.strip]
      end.to_h
    end

    # Optional second login button that requests a specific minimum
    # authentication level (acr_values) from the OIDC provider.
    def second_button_enabled?
      settings_hash['second_button_enabled'] == '1'
    end

    def second_button_label
      settings_hash['second_button_label'].to_s
    end

    def second_button_acr_values
      settings_hash['second_button_acr_values'].to_s.strip
    end

    # True when the second button can be displayed
    def second_button_available?
      second_button_enabled? && second_button_acr_values.present?
    end

    # Returns the configured acr_values floor
    def acr_values_for_request(params)
      return nil unless second_button_available?
      return nil if params.blank? || params[SECOND_BUTTON_PARAM].blank?

      second_button_acr_values
    end

    # Builds the OIDC `claims` request parameter marking the requested acr as
    # *essential* (mandatory). `acr_values` alone is defined as "voluntary" by
    # the OIDC spec (§3.1.2.1) and providers may ignore it.
    def essential_acr_claims(acr_values)
      values = acr_values.to_s.split
      return {} if values.empty?

      { 'claims' => JSON.generate('id_token' => { 'acr' => { 'essential' => true, 'values' => values } }) }
    end
  end
end
