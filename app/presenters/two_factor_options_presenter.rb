class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :priority_bucket

  def initialize(user_agent:, user: nil, priority_bucket: :default,
                 phishing_resistant_required: false, piv_cac_required: false)
    @user_agent = user_agent
    @user = user
    @priority_bucket = priority_bucket
    @phishing_resistant_required = phishing_resistant_required
    @piv_cac_required = piv_cac_required
  end

  def options
    if priority_bucket == :authentication_app_priority
      totp_option + webauthn_platform_option + webauthn_option + piv_cac_option +
        phone_options + backup_code_option
    elsif priority_bucket == :usability_priority
      phone_options + totp_option + backup_code_option + webauthn_platform_option +
        webauthn_option + piv_cac_option
    else
      webauthn_platform_option + webauthn_option + piv_cac_option + totp_option +
        phone_options + backup_code_option
    end
  end

  def icon
    if piv_cac_required? || (phishing_resistant_only? && mfa_policy.two_factor_enabled?)
      'icon-lock-alert-important.svg'
    end
  end

  def icon_alt_text
    t('two_factor_authentication.important_alert_icon')
  end

  def heading
    if piv_cac_required?
      t('two_factor_authentication.two_factor_hspd12_choice')
    elsif phishing_resistant_only? && mfa_policy.two_factor_enabled?
      t('two_factor_authentication.two_factor_aal3_choice')
    else
      t('two_factor_authentication.two_factor_choice')
    end
  end

  def intro
    if piv_cac_required?
      t('two_factor_authentication.two_factor_hspd12_choice_intro')
    elsif phishing_resistant_only?
      t('two_factor_authentication.two_factor_aal3_choice_intro')
    else
      t('mfa.info')
    end
  end

  private

  def piv_cac_option
    return [] unless current_device_is_desktop?
    [TwoFactorAuthentication::PivCacSelectionPresenter.new(user: user)]
  end

  def webauthn_option
    return [] if piv_cac_required?
    [TwoFactorAuthentication::WebauthnSelectionPresenter.new(user: user)]
  end

  def webauthn_platform_option
    return [] if piv_cac_required? || !IdentityConfig.store.platform_auth_set_up_enabled
    [TwoFactorAuthentication::WebauthnPlatformSelectionPresenter.new(user: user)]
  end

  def phone_options
    if piv_cac_required? || phishing_resistant_only? || IdentityConfig.store.hide_phone_mfa_signup
      return []
    else
      [TwoFactorAuthentication::PhoneSelectionPresenter.new(user: user)]
    end
  end

  def totp_option
    return [] if piv_cac_required? || phishing_resistant_only?
    [TwoFactorAuthentication::AuthAppSelectionPresenter.new(user: user)]
  end

  def backup_code_option
    return [] if piv_cac_required? || phishing_resistant_only?
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new(user: user)]
  end

  def current_device_is_desktop?
    !BrowserCache.parse(@user_agent).mobile?
  end

  def piv_cac_required?
    @piv_cac_required
  end

  def phishing_resistant_only?
    @phishing_resistant_required && !mfa_policy.phishing_resistant_mfa_enabled?
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(user)
  end
end
