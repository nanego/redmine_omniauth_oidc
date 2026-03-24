# redmine_omniauth_oidc

OpenID Connect (OIDC) authentication plugin for Redmine. Compatible with any standard OIDC provider (Keycloak, Azure AD, etc.).

## Test status

| Plugin branch | Redmine version | Test status |
|---------------|-----------------|-------------|
| master | 6.1.2 | [![6.1.2][1]][3] |
| master | master | [![master][2]][3] |

[1]: https://github.com/nanego/redmine_omniauth_oidc/actions/workflows/6_1_2.yml/badge.svg
[2]: https://github.com/nanego/redmine_omniauth_oidc/actions/workflows/master.yml/badge.svg
[3]: https://github.com/nanego/redmine_omniauth_oidc/actions

## Dependencies

This plugin requires [redmine_base_deface](https://github.com/nanego/redmine_base_deface) to be installed (used to inject the OIDC login button into Redmine views).

## Installation

1. Install gems:
   ```bash
   bundle install
   ```

2. Copy the initializer into Redmine:
   ```bash
   cp plugins/redmine_omniauth_oidc/initializers/redmine_omniauth_oidc.rb config/initializers/
   ```

3. Restart Redmine.

4. Configure the plugin: **Administration > Plugins > redmine_omniauth_oidc > Configure**

## Settings

| Setting | Description |
|---------|-------------|
| Enabled | Show the OIDC login button |
| Issuer URL | OIDC provider base URL, e.g. `https://sso.example.com/oidc` |
| Client ID | Application client identifier |
| Client Secret | OIDC client secret |
| Scopes | Default: `openid profile email` |
| Replace Redmine login | Hide the native Redmine login form |
| Auto-provisioning | Automatically create a Redmine account on first login |
| Active accounts | Auto-created accounts are immediately active (otherwise: pending admin approval) |

## YAML configuration (optional, recommended in production)

To avoid storing credentials in the database, create `config/omniauth_oidc.yml`:

```bash
cp plugins/redmine_omniauth_oidc/config/omniauth_oidc.yml.example config/omniauth_oidc.yml
# fill in your values
```

```yaml
oidc_issuer_url: https://sso.example.com/oidc
oidc_client_id: my-client-id
oidc_client_secret: my-client-secret
```

When this file exists, the three corresponding fields become read-only in the admin UI. Restart Redmine after any change.

## User matching

On login, the plugin looks up the user in this order:
1. by `email` claim → `User.mail`
2. by `uid` claim → `User.login`
3. by `preferred_username` claim → `User.login`

## SSO logout

If the provider exposes an `end_session_endpoint` in its discovery document, Redmine logout will automatically redirect to that endpoint.
