module ReauthenticationRequiredConcern
  include MfaSetupConcern

  def confirm_recently_authenticated
    if IdentityConfig.store.reauthentication_for_second_factor_management_enabled
      confirm_recently_authenticated_2fa
    else
      @reauthn = reauthn?
      return unless user_signed_in?
      return if recently_authenticated?

      prompt_for_current_password
    end
  end

  def confirm_recently_authenticated_2fa
    @reauthn = reauthn?
    return unless user_fully_authenticated?
    non_remembered_device_authentication = user_session[:auth_method].present? &&
                                           user_session[:auth_method] != 'remember_device'
    return if recently_authenticated? && non_remembered_device_authentication
    return if in_multi_mfa_selection_flow?

    analytics.user_2fa_reauthentication_required(
      auth_method: user_session[:auth_method],
      authenticated_at: user_session[:authn_at],
    )

    prompt_for_second_factor
  end

  private

  def recently_authenticated?
    return false if user_session.blank?
    authn_at = user_session[:authn_at]
    return false if authn_at.blank?
    authn_at > Time.zone.now - IdentityConfig.store.reauthn_window
  end

  def prompt_for_current_password
    store_location(request.url)
    user_session[:context] = 'reauthentication'
    user_session[:factor_to_change] = factor_from_controller_name
    user_session[:current_password_required] = true
    redirect_to user_password_confirm_url
  end

  def prompt_for_second_factor
    store_location(request.url)
    user_session[:context] = 'reauthentication'

    redirect_to login_two_factor_options_path(reauthn: true)
  end

  def factor_from_controller_name
    {
      # see LG-5701, translate these
      'emails' => 'email',
      'passwords' => 'password',
      'phones' => 'phone',
      'personal_keys' => 'personal key',
    }[controller_name]
  end

  def store_location(url)
    user_session[:stored_location] = url
  end
end
