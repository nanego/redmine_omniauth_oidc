require "spec_helper"

describe AccountController, type: :controller do
  fixtures :users, :roles, :email_addresses

  before do
    Setting["plugin_redmine_omniauth_oidc"]["enabled"] = "1"
    Setting["plugin_redmine_omniauth_oidc"]["oidc_issuer_url"] = "https://sso.example.com/oidc/myapp"
  end

  def oidc_auth_hash(email:, uid: nil, preferred_username: nil, given_name: nil, family_name: nil)
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

  # render_views is needed only for button visibility tests (full layout)
  context "GET /login OIDC button", :render_views => true do
    render_views

    it "should not show OIDC button when issuer_url is blank" do
      Setting["plugin_redmine_omniauth_oidc"]["oidc_issuer_url"] = ""
      get :login
      assert_select '#oidc-login', 0
    end

    it "should show OIDC button when issuer_url is configured" do
      get :login
      assert_select '#oidc-login'
    end

    it "should correct double-escaped back_url" do
      get :login, params: { :back_url => "https%3A%2F%2Fblah%2F" }
      assert_select '#oidc-login > form[action=?]', '/auth/openid_connect?origin=https%3A%2F%2Fblah%2F'
    end
  end

  context "login_with_oidc_callback" do
    it "should redirect to /my/page after successful login by email" do
      request.env["omniauth.auth"] = oidc_auth_hash(email: "admin@somenet.foo")
      get :login_with_oidc_callback, params: { :provider => "openid_connect" }
      expect(response).to redirect_to('/my/page')
    end

    it "should set session flag after successful login" do
      request.env["omniauth.auth"] = oidc_auth_hash(email: "admin@somenet.foo")
      get :login_with_oidc_callback, params: { :provider => "openid_connect" }
      expect(session[:logged_in_with_oidc]).to be_truthy
    end

    it "should redirect to /login if user not found and auto_provision is disabled" do
      Setting["plugin_redmine_omniauth_oidc"]["auto_provision"] = ''
      request.env["omniauth.auth"] = oidc_auth_hash(email: "nobody@example.com")
      get :login_with_oidc_callback, params: { :provider => "openid_connect" }
      expect(response).to redirect_to('/login')
    end

    context "auto-provisioning" do
      before do
        Setting["plugin_redmine_omniauth_oidc"]["auto_provision"] = '1'
        Setting["plugin_redmine_omniauth_oidc"]["auto_provision_active"] = '1'
      end

      it "should create user on first login if not found" do
        request.env["omniauth.auth"] = oidc_auth_hash(
          email: "newuser@ministere.fr",
          uid: "jdupont",
          preferred_username: "jdupont",
          given_name: "Jean",
          family_name: "Dupont"
        )
        expect {
          get :login_with_oidc_callback, params: { :provider => "openid_connect" }
        }.to change(User, :count).by(1)
        expect(response).to redirect_to('/my/page')
        user = User.find_by_mail("newuser@ministere.fr")
        expect(user).not_to be_nil
        expect(user.login).to eq "jdupont"
        expect(user.firstname).to eq "Jean"
        expect(user.status).to eq User::STATUS_ACTIVE
      end

      it "should create user with registered status when auto_provision_active is disabled" do
        Setting["plugin_redmine_omniauth_oidc"]["auto_provision_active"] = ''
        request.env["omniauth.auth"] = oidc_auth_hash(
          email: "pending@ministere.fr",
          uid: "pending_user",
          given_name: "Pending",
          family_name: "User"
        )
        get :login_with_oidc_callback, params: { :provider => "openid_connect" }
        user = User.find_by_mail("pending@ministere.fr")
        expect(user).not_to be_nil
        expect(user.status).to eq User::STATUS_REGISTERED
      end
    end
  end

  context "logout" do
    it "should redirect to home if not logged in with OIDC" do
      get :logout
      expect(response).to redirect_to(home_url)
    end

    it "should redirect to end_session_endpoint if logged in with OIDC" do
      session[:logged_in_with_oidc] = true
      session[:oidc_end_session_endpoint] = "https://sso.example.com/oidc/myapp/logout"
      get :logout
      expect(response).to redirect_to("https://sso.example.com/oidc/myapp/logout")
    end

    it "should redirect to home if logged in with OIDC but no end_session_endpoint" do
      session[:logged_in_with_oidc] = true
      session[:oidc_end_session_endpoint] = nil
      get :logout
      expect(response).to redirect_to(home_url)
    end
  end
end
