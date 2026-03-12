# frozen_string_literal: true

require_dependency 'account_helper'

module RedmineOmniauthOidc::AccountHelperPatch
  def label_for_oidc_login
    RedmineOmniauthOidc.label_login_with_oidc.presence || l(:label_login_with_oidc)
  end
end

AccountHelper.prepend RedmineOmniauthOidc::AccountHelperPatch
ActionView::Base.prepend AccountHelper
