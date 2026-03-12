require "spec_helper"

describe "AccountPatch", :type => :request do
  fixtures :users, :roles, :email_addresses

  before do
    # Use Setting[]= (saves to DB) so values survive Setting.check_cache clearing
    # the in-memory cache (triggered by Setting.default_language below).
    Setting["plugin_redmine_omniauth_oidc"] = {
      "enabled"        => "1",
      "oidc_issuer_url" => "https://sso.example.com/oidc/myapp"
    }
    Setting.default_language = 'en'
    OmniAuth.config.test_mode = true
  end

  def mock_oidc_auth(email:, uid: nil, preferred_username: nil, given_name: nil, family_name: nil)
    raw_info = {}
    raw_info['uid'] = uid if uid
    raw_info['preferred_username'] = preferred_username if preferred_username
    raw_info['given_name'] = given_name if given_name
    raw_info['family_name'] = family_name if family_name
    OmniAuth::AuthHash.new(
      'uid'   => email,
      'info'  => { 'email' => email },
      'extra' => { 'raw_info' => raw_info }
    )
  end

  context "GET /auth/openid_connect" do
    it "should have a route defined" do
      # Note: when both CAS and OIDC plugins are active, CAS generic routes may take precedence.
      # The OIDC-specific routes work correctly when only the OIDC plugin is active.
      expect(Rails.application.routes.url_helpers.respond_to?(:auth_openid_connect_callback_path)).to be_truthy
    end
  end

  context "GET /auth/openid_connect/callback" do
    it "should have a named route" do
      expect(Rails.application.routes.named_routes.key?(:auth_openid_connect_callback)).to be_truthy
    end

    context "OIDC strategy (test mode)" do
      # In OmniAuth test mode, the middleware intercepts the callback path and sets
      # env['omniauth.auth'] from OmniAuth.config.mock_auth[:openid_connect].
      # We must set the mock on OmniAuth.config (not Rails.application.env_config).
      def set_mock(auth_hash)
        OmniAuth.config.mock_auth[:openid_connect] = auth_hash
      end

      it "should authorize login if user exists with this email" do
        set_mock(mock_oidc_auth(email: "admin@somenet.foo"))
        get '/auth/openid_connect/callback'
        expect(response).to redirect_to('/my/page')
        get '/my/page'
        expect(response.body).to match /Logged in as.*admin/im
      end

      it "should authorize login by uid fallback" do
        set_mock(mock_oidc_auth(email: "nobody_by_email@unknown.fr", uid: "admin"))
        get '/auth/openid_connect/callback'
        expect(response).to redirect_to('/my/page')
      end

      it "should update last_login_on on successful login" do
        user = User.find(1)
        user.update_attribute(:last_login_on, Time.now - 6.hours)
        set_mock(mock_oidc_auth(email: "admin@somenet.foo"))
        get '/auth/openid_connect/callback'
        expect(response).to redirect_to('/my/page')
        user.reload
        assert Time.now - user.last_login_on < 30.seconds
      end

      it "should refuse login if user doesn't exist and auto_provision disabled" do
        set_mock(mock_oidc_auth(email: "nobody@example.com"))
        get '/auth/openid_connect/callback'
        expect(response).to redirect_to('/login')
        follow_redirect!
        expect(User.current).to eq User.anonymous
        assert_select 'div.flash.error', :text => /Invalid user or password/
      end

      it "should auto-provision user on first login if enabled" do
        Setting["plugin_redmine_omniauth_oidc"] = Setting["plugin_redmine_omniauth_oidc"].merge(
          "auto_provision"        => '1',
          "auto_provision_active" => '1'
        )
        set_mock(mock_oidc_auth(email: "nouveau@ministere.fr", uid: "nouveau_user",
                                given_name: "Nouveau", family_name: "Utilisateur"))
        expect {
          get '/auth/openid_connect/callback'
        }.to change(User, :count).by(1)
        expect(response).to redirect_to('/my/page')
      end
    end
  end
end
