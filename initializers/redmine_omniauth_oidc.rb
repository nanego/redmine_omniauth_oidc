
# OmniAuth OIDC (omniauth_openid_connect gem)
# This setup proc is called on every auth request, allowing settings to be
# changed in the admin UI without restarting the server.
setup_proc = Proc.new do |env|
  strategy = env['omniauth.strategy']

  strategy.options[:issuer]    = RedmineOmniauthOidc.oidc_issuer_url
  strategy.options[:discovery] = true
  strategy.options[:scope]     = RedmineOmniauthOidc.oidc_scope_array
  strategy.options[:uid_field] = RedmineOmniauthOidc.oidc_uid_field

  # Provider-specific parameters appended to the authorization request
  strategy.options[:extra_authorize_params] = RedmineOmniauthOidc.oidc_extra_authorize_params

  # Optional second login button: request a minimum authentication level
  # (acr_values) when the request carries the second-button marker.
  acr_values = RedmineOmniauthOidc.acr_values_for_request(Rack::Request.new(env).params)
  strategy.options[:acr_values] = acr_values if acr_values.present?

  strategy.options[:client_options][:identifier]   = RedmineOmniauthOidc.oidc_client_id
  strategy.options[:client_options][:secret]       = RedmineOmniauthOidc.oidc_client_secret
  strategy.options[:client_options][:redirect_uri] = strategy.callback_url.split('?').first
end

begin
  # Register the middleware with placeholder values (overridden by setup_proc at runtime)
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :openid_connect,
             :issuer            => 'https://placeholder.example.com',
             :discovery         => true,
             :client_options    => {
               :identifier => 'placeholder',
               :secret     => 'placeholder'
             },
             :setup => setup_proc
  end
rescue FrozenError
  Rails.logger.warn("Unable to add OmniAuth::Builder middleware (OIDC) as the middleware stack is frozen")
  puts "/!\\ Unable to add OmniAuth::Builder middleware (OIDC) as the middleware stack is frozen"
end
