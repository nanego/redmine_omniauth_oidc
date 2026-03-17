if defined?(Deface)
  Deface::Override.new :virtual_path  => 'account/login',
                       :name          => 'hide-login-form-oidc',
                       :surround      => '#login-form',
                       :text          => <<-HTML
<% if RedmineOmniauthOidc.enabled? && RedmineOmniauthOidc.oidc_issuer_url.present? %>
<div style="text-align:center; margin:15px">
  <em class=info>
    <%= link_to_function l(:label_or_login_with_password), "$('#login-form-container').show(); $(this).hide();" %>
  </em>
</div>
<div id="login-form-container" style="display:none">
  <%= render_original %>
</div>
<% else %>
<%= render_original %>
<% end %>
HTML
end
