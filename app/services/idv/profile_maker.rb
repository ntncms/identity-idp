module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(applicant:, user:, user_password:, initiating_service_provider: nil)
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.user_password = user_password
      self.initiating_service_provider = initiating_service_provider
    end

    def save_profile(
      active:,
      fraud_review_needed:,
      gpo_verification_needed:,
      deactivation_reason: nil
    )
      profile = Profile.new(user: user, active: false, deactivation_reason: deactivation_reason)
      profile.initiating_service_provider = initiating_service_provider
      profile.encrypt_pii(pii_attributes, user_password)
      profile.proofing_components = current_proofing_components
      profile.save!
      profile.activate if active
      profile.deactivate_for_gpo_verification if gpo_verification_needed
      profile.deactivate_for_fraud_review if fraud_review_needed
      profile
    end

    private

    def current_proofing_components
      user.proofing_component&.as_json || {}
    end

    attr_accessor :user, :user_password, :phone_confirmed, :initiating_service_provider
    attr_writer :pii_attributes
  end
end
