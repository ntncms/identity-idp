require 'rails_helper'

describe Idv::PersonalKeyController do
  include SamlAuthHelper
  include PersonalKeyValidator

  def stub_idv_session
    stub_sign_in(user)
    idv_session.applicant = applicant
    profile_maker = Idv::ProfileMaker.new(
      applicant: applicant,
      user: user,
      user_password: password,
    )
    profile = profile_maker.save_profile(
      active: false,
      fraud_review_needed: false,
      gpo_verification_needed: false,
    )
    idv_session.pii = profile_maker.pii_attributes
    idv_session.profile_id = profile.id
    idv_session.personal_key = profile.personal_key
    subject.idv_session.address_verification_mechanism = 'phone'
    idv_session.vendor_phone_confirmation = true
    idv_session.user_phone_confirmation = true
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end

  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :fully_registered, password: password) }
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:profile) { subject.idv_session.profile }
  let(:idv_session) do
    Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      service_provider: nil,
    )
  end

  before do
    stub_analytics
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_phone_or_address_confirmed,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end

    describe '#confirm_profile_has_been_created' do
      before do
        stub_idv_session
      end

      controller do
        before_action :confirm_profile_has_been_created

        def index
          render plain: 'Hello'
        end
      end

      context 'profile has been created' do
        it 'does not redirect' do
          get :index

          expect(response).to_not be_redirect
        end
      end

      context 'profile has not been created' do
        before do
          subject.idv_session.profile_id = nil
        end

        it 'redirects to the account path' do
          get :index

          expect(response).to redirect_to account_path
        end
      end
    end
  end

  describe '#show' do
    before do
      stub_idv_session
      stub_attempts_tracker
    end

    it 'sets code instance variable' do
      subject.idv_session.create_profile_from_applicant_with_password(password)
      code = subject.idv_session.personal_key

      get :show

      expect(assigns(:code)).to eq(code)
    end

    it 'can decrypt the profile with the code' do
      get :show

      code = assigns(:code)

      expect(PersonalKeyGenerator.new(user).verify(code)).to eq true
      expect(user.profiles.first.recover_pii(normalize_personal_key(code))).to eq(
        subject.idv_session.pii,
      )
    end

    it 'sets flash[:allow_confirmations_continue] to true' do
      get :show

      expect(flash[:allow_confirmations_continue]).to eq true
    end

    it 'logs when user generates personal key' do
      expect(@irs_attempts_api_tracker).to receive(:idv_personal_key_generated)
      get :show
    end

    it 'sets flash.now[:success]' do
      get :show
      expect(flash[:success]).to eq t('idv.messages.confirm')
    end

    context 'user selected gpo verification' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
        subject.idv_session.vendor_phone_confirmation = false
        subject.idv_session.user_phone_confirmation = false
        subject.idv_session.create_profile_from_applicant_with_password(password)
      end

      it 'redirects to doc auth url' do
        get :show

        expect(response).to redirect_to idv_doc_auth_url
      end
    end
  end

  describe '#update' do
    before do
      stub_idv_session
    end

    context 'user selected phone verification' do
      before do
        subject.idv_session.create_profile_from_applicant_with_password(password)
      end

      it 'redirects to sign up completed for an sp' do
        subject.session[:sp] = { ial2: true }
        patch :update

        expect(response).to redirect_to sign_up_completed_url
      end

      it 'redirects to the account path when no sp present' do
        patch :update

        expect(response).to redirect_to account_path
      end

      it 'clears need_personal_key_confirmation session state' do
        subject.user_session[:need_personal_key_confirmation] = true
        patch :update

        expect(subject.user_session[:need_personal_key_confirmation]).to eq(false)
      end

      it 'logs key submitted event' do
        patch :update

        expect(@analytics).to have_logged_event(
          'IdV: personal key submitted',
          address_verification_method: nil,
          fraud_review_pending: false,
          fraud_rejection: false,
          deactivation_reason: nil,
          proofing_components: nil,
        )
      end
    end

    context 'user selected gpo verification' do
      before do
        subject.idv_session.address_verification_mechanism = 'gpo'
        subject.idv_session.vendor_phone_confirmation = false
        subject.idv_session.user_phone_confirmation = false
        subject.idv_session.create_profile_from_applicant_with_password(password)
      end

      context 'with gpo personal key after verification' do
        it 'redirects to doc auth url' do
          patch :update

          expect(response).to redirect_to idv_doc_auth_url
        end
      end
    end

    context 'with in person profile' do
      let!(:enrollment) { create(:in_person_enrollment, :pending, user: user, profile: profile) }

      before do
        ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'creates a profile and returns completion url' do
        patch :update

        expect(response).to redirect_to idv_in_person_ready_to_verify_url
      end

      it 'logs key submitted event' do
        patch :update

        expect(@analytics).to have_logged_event(
          'IdV: personal key submitted',
          address_verification_method: nil,
          fraud_review_pending: false,
          fraud_rejection: false,
          deactivation_reason: nil,
          proofing_components: nil,
        )
      end
    end

    context 'with device profiling decisioning enabled' do
      before do
        ProofingComponent.create(user: user, threatmetrix: true, threatmetrix_review_status: nil)
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      end

      context 'threatmetrix review status is nil' do
        it 'redirects to account path' do
          patch :update

          expect(response).to redirect_to account_path
        end
        it 'logs key submitted event' do
          patch :update

          expect(@analytics).to have_logged_event(
            'IdV: personal key submitted',
            address_verification_method: nil,
            fraud_review_pending: false,
            fraud_rejection: false,
            deactivation_reason: nil,
            proofing_components: nil,
          )
        end
      end

      context 'device profiling passes' do
        before do
          ProofingComponent.find_by(user: user).update(threatmetrix_review_status: 'pass')
        end
        it 'redirects to account path' do
          patch :update

          expect(response).to redirect_to account_path
        end
        it 'logs key submitted event' do
          patch :update

          expect(@analytics).to have_logged_event(
            'IdV: personal key submitted',
            address_verification_method: nil,
            fraud_review_pending: false,
            fraud_rejection: false,
            deactivation_reason: nil,
            proofing_components: nil,
          )
        end
      end

      context 'device profiling gets sent to review' do
        before do
          ProofingComponent.find_by(user: user).update(threatmetrix_review_status: 'review')
          profile.deactivate_for_fraud_review
        end

        it 'redirects to idv please call path' do
          patch :update
          expect(response).to redirect_to idv_please_call_path
        end

        it 'logs key submitted event' do
          patch :update

          expect(@analytics).to have_logged_event(
            'IdV: personal key submitted',
            fraud_review_pending: true,
            fraud_rejection: false,
            address_verification_method: nil,
            deactivation_reason: nil,
            proofing_components: nil,
          )
        end
      end

      context 'device profiling fails' do
        before do
          ProofingComponent.find_by(user: user).update(threatmetrix_review_status: 'reject')
          profile.deactivate_for_fraud_review
        end

        it 'redirects to idv please call path' do
          patch :update
          expect(response).to redirect_to idv_please_call_path
        end

        it 'logs key submitted event' do
          patch :update

          expect(@analytics).to have_logged_event(
            'IdV: personal key submitted',
            fraud_review_pending: true,
            fraud_rejection: false,
            address_verification_method: nil,
            deactivation_reason: nil,
            proofing_components: nil,
          )
        end
      end
    end
  end
end
