# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  match 'auth/failure',                 :controller => 'account', :action => 'login_with_oidc_failure',  via: [:get, :post]
  match 'auth/openid_connect/callback', :controller => 'account', :action => 'login_with_oidc_callback', via: [:get, :post]
  match 'auth/openid_connect',          :controller => 'account', :action => 'login_with_oidc_redirect', via: [:get, :post]
end
