module Users
  class MfaSelectionController < ApplicationController
    include UserAuthenticator
    include SecureHeadersConcern
    include MfaSetupConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup

    def index
      two_factor_options_form
      @after_setup_path = after_mfa_setup_path
      @sign_up_mfa_selection_order_bucket = AbTests::SIGN_UP_MFA_SELECTION.bucket(current_user.uuid)
      @presenter = two_factor_options_presenter
      analytics.user_registration_2fa_additional_setup_visit(
        sign_up_mfa_priority_bucket: @sign_up_mfa_selection_order_bucket,
      )
    end

    def update
      result = submit_form
      @sign_up_mfa_selection_order_bucket = AbTests::SIGN_UP_MFA_SELECTION.bucket(current_user.uuid)
      analytics_hash = result.to_h.merge(
        sign_up_mfa_priority_bucket: @sign_up_mfa_selection_order_bucket,
      )
      analytics.user_registration_2fa_additional_setup(**analytics_hash)

      if result.success?
        process_valid_form
      else
        flash[:error] = t('errors.two_factor_auth_setup.must_select_additional_option')
        redirect_back(fallback_location: second_mfa_setup_path, allow_other_host: false)
      end
    rescue ActionController::ParameterMissing
      flash[:error] = t('errors.two_factor_auth_setup.must_select_option')
      redirect_back(fallback_location: two_factor_options_path, allow_other_host: false)
    end

    private

    def submit_form
      two_factor_options_form.submit(two_factor_options_form_params)
    end

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(
        user_agent: request.user_agent,
        priority_bucket: @sign_up_mfa_selection_order_bucket,
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def two_factor_options_form
      @two_factor_options_form ||= TwoFactorOptionsForm.new(
        user: current_user,
        phishing_resistant_required: service_provider_mfa_policy.phishing_resistant_required?,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_form
      user_session[:mfa_selections] = @two_factor_options_form.selection

      if user_session[:mfa_selections].first.present?
        redirect_to confirmation_path(user_session[:mfa_selections].first)
      else
        redirect_to after_mfa_setup_path
      end
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection, selection: [])
    end
  end
end
