# Configures the public URL of the application so that OmniAuth can build
# a correct redirect_uri to send to the OIDC provider.
module OmniAuth::DynamicFullHost
  def self.full_host_url(url = nil)
    url = CGI.unescape(url) if url

    # If a full URL with scheme+host is available (e.g. from omniauth.origin),
    # extract only the scheme://host[:port] part.
    if url.present?
      begin
        uri = URI.parse(URI::Parser.new.escape(url))
        if uri.scheme.present? && uri.host.present?
          result = "#{uri.scheme}://#{uri.host}"
          result << ":#{uri.port}" unless uri.default_port == uri.port
          return result
        end
      rescue URI::InvalidURIError
        # fall through to Redmine settings
      end
    end

    # Fall back to Redmine's host_name setting.
    # Setting["host_name"] may be:
    #   - a bare host[:port][/subpath]  (e.g. "redmine.example.com")    → prepend Setting.protocol
    #   - a full URL                    (e.g. "http://redmine.example.com") → use as-is
    host_setting = Setting["host_name"].to_s
    begin
      host_uri = URI.parse(URI::Parser.new.escape(host_setting))
      if host_uri.scheme.present? && host_uri.host.present?
        result = "#{host_uri.scheme}://#{host_uri.host}"
        result << ":#{host_uri.port}" unless host_uri.default_port == host_uri.port
        return result
      end
    rescue URI::InvalidURIError
      # fall through
    end

    # Plain hostname (Redmine standard): prepend the configured protocol.
    host     = host_setting.split('/').first
    protocol = Setting.protocol.presence || 'https'
    "#{protocol}://#{host}"
  end
end

# Only set if not already configured by another plugin (e.g. redmine_omniauth_cas)
OmniAuth.config.full_host ||= Proc.new do |env|
  OmniAuth::DynamicFullHost.full_host_url(
    env["rack.session"]["omniauth.origin"] || env["omniauth.origin"]
  )
end
