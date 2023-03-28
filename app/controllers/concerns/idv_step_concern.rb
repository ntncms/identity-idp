module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
  end

  def confirm_document_capture_complete
    @pii = flow_session&.[]('pii_from_doc') # hash with indifferent access
    return if @pii.present?

    flow_session&.delete('Idv::Steps::DocumentCaptureStep')
    redirect_to idv_doc_auth_url
  end

  def confirm_verify_info_step_complete
    return if idv_session.verify_info_step_complete?

    if idv_session.in_person_enrollment?
      redirect_to idv_in_person_verify_info_url
    else
      redirect_to idv_verify_info_url
    end
  end

  def confirm_verify_info_step_needed
    return unless idv_session.verify_info_step_complete?
    redirect_to idv_review_url
  end

  def confirm_address_step_complete
    return if idv_session.address_step_complete?

    redirect_to idv_otp_verification_url
  end
end
