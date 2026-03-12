require "spec_helper"

describe "RedmineOmniauthOidc" do
  before do
    Setting["plugin_redmine_omniauth_oidc"]["oidc_issuer_url"] = "https://sso.example.com/oidc/myapp"
    Setting["plugin_redmine_omniauth_oidc"]["oidc_client_id"]  = "myapp"
    Setting["plugin_redmine_omniauth_oidc"]["oidc_client_secret"] = "secret"
    # Reset YAML cache
    RedmineOmniauthOidc.remove_instance_variable(:@yaml_config) if RedmineOmniauthOidc.instance_variable_defined?(:@yaml_config)
  end

  context "#enabled?" do
    it "returns false when not set" do
      Setting["plugin_redmine_omniauth_oidc"]["enabled"] = ''
      expect(RedmineOmniauthOidc.enabled?).to be_falsey
    end

    it "returns true when set to '1'" do
      Setting["plugin_redmine_omniauth_oidc"]["enabled"] = '1'
      expect(RedmineOmniauthOidc.enabled?).to be_truthy
    end
  end

  context "#oidc_issuer_url" do
    it "returns DB setting when no YAML" do
      expect(RedmineOmniauthOidc.oidc_issuer_url).to eq "https://sso.example.com/oidc/myapp"
    end
  end

  context "#oidc_scope_array" do
    it "converts space-separated string to symbol array" do
      Setting["plugin_redmine_omniauth_oidc"]["oidc_scope"] = "openid email profile"
      expect(RedmineOmniauthOidc.oidc_scope_array).to eq [:openid, :email, :profile]
    end

    it "handles comma-separated scopes" do
      Setting["plugin_redmine_omniauth_oidc"]["oidc_scope"] = "openid,email,profile"
      expect(RedmineOmniauthOidc.oidc_scope_array).to eq [:openid, :email, :profile]
    end

    it "returns default scopes when not set" do
      Setting["plugin_redmine_omniauth_oidc"]["oidc_scope"] = ''
      expect(RedmineOmniauthOidc.oidc_scope_array).to include(:openid, :email)
    end
  end

  context "#oidc_uid_field" do
    it "returns 'email' by default" do
      Setting["plugin_redmine_omniauth_oidc"]["oidc_uid_field"] = ''
      expect(RedmineOmniauthOidc.oidc_uid_field).to eq 'email'
    end

    it "returns DB setting when configured" do
      Setting["plugin_redmine_omniauth_oidc"]["oidc_uid_field"] = 'preferred_username'
      expect(RedmineOmniauthOidc.oidc_uid_field).to eq 'preferred_username'
    end
  end

  context "dynamic full host" do
    it "should return host name from setting if no url" do
      Setting["host_name"] = "http://redmine.example.com"
      expect(OmniAuth::DynamicFullHost.full_host_url).to eq "http://redmine.example.com"
    end

    it "should return host name from url if url is present" do
      url = "https://redmine.example.com:3000/some/path"
      expect(OmniAuth::DynamicFullHost.full_host_url(url)).to eq "https://redmine.example.com:3000"
    end
  end
end
