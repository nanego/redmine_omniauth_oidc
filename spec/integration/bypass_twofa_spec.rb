require "spec_helper"

# Redmine forces users without 2FA to enrol when 2FA is required. OIDC users are
# already MFA-authenticated by the identity provider, so the plugin can bypass
# that enrolment. These specs cover the enrolment-enforcement case (the OTP
# challenge for already-paired users never happens on the OIDC path).
describe "OIDC 2FA bypass", :type => :request do
  fixtures :users, :roles, :email_addresses

  before do
    Setting["plugin_redmine_omniauth_oidc"] = {
      "enabled"      => "1",
      "bypass_twofa" => bypass
    }
    Setting.default_language = 'en'
    Setting.twofa = '2' # 2FA required for everyone; admin has none configured
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:openid_connect] =
      OmniAuth::AuthHash.new('uid' => 'admin@somenet.foo',
                             'info' => { 'email' => 'admin@somenet.foo' },
                             'extra' => { 'raw_info' => {} })
  end

  after { Setting.twofa = '0' }

  context "when the bypass is enabled" do
    let(:bypass) { '1' }

    it "does not force 2FA enrolment after OIDC login" do
      get '/auth/openid_connect/callback'
      expect(response).to redirect_to('/my/page')

      get '/my/page'
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the bypass is disabled" do
    let(:bypass) { '' }

    it "still forces 2FA enrolment after OIDC login" do
      get '/auth/openid_connect/callback'
      expect(response).to redirect_to('/my/page')

      get '/my/page'
      expect(response).to redirect_to(%r{/twofa/})
    end
  end
end
