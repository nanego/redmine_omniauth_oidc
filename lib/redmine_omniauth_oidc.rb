# frozen_string_literal: true

module RedmineOmniauthOidc
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
  end
end
