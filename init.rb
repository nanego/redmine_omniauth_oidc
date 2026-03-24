# frozen_string_literal: true

initializers_dir = File.join(Rails.root, "config", "initializers")
if Dir.glob(File.join(initializers_dir, "redmine_omniauth_oidc.rb")).blank?
  $stderr.puts "Omniauth OIDC Plugin: Missing initialization file config/initializers/redmine_omniauth_oidc.rb. " \
               "Please copy the provided file to the config/initializers/ directory.\n" \
               "You can copy/paste this command:\n" \
               "cp #{File.join(Rails.root, "plugins", "redmine_omniauth_oidc")}/initializers/redmine_omniauth_oidc.rb #{File.join(initializers_dir, "redmine_omniauth_oidc.rb")}"
  exit 1
end

require 'redmine'
require_relative 'lib/redmine_omniauth_oidc'
require_relative 'lib/redmine_omniauth_oidc/hooks'
require_relative 'lib/omni_auth/dynamic_full_host'

Redmine::Plugin.register :redmine_omniauth_oidc do
  name 'Redmine OmniAuth OIDC Plugin'
  description 'Adds OpenID Connect (OIDC) authentication support to Redmine via OmniAuth'
  url 'https://github.com/nanego/redmine_omniauth_oidc'
  version '1.0.0'
  requires_redmine :version_or_higher => '6.0.0'
  requires_redmine_plugin :redmine_base_deface, :version_or_higher => '0.0.1'
  requires_redmine_plugin :redmine_base_rspec, :version_or_higher => '0.0.3' if Rails.env.test?
  settings :default => {
             'enabled'               => '',
             'oidc_issuer_url'       => '',
             'oidc_client_id'        => '',
             'oidc_client_secret'    => '',
             'oidc_scope'            => 'openid profile email',
             'oidc_uid_field'        => 'email',
             'label_login_with_oidc' => '',
             'replace_redmine_login' => '',
             'auto_provision'        => '',
             'auto_provision_active' => '',
             'oidc_claim_firstname'  => 'given_name',
             'oidc_claim_lastname'   => 'family_name'
           },
           :partial => 'settings/omniauth_oidc_settings'
end
