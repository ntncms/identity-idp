require 'rails_helper'

RSpec.describe Idv::StepIndicatorConcern, type: :controller do
  controller ApplicationController do
    include Idv::StepIndicatorConcern
  end

  let(:profile) { nil }
  let(:user) { create(:user, profiles: [profile].compact) }

  before { stub_sign_in(user) }

  describe '#step_indicator_steps' do
    def force_gpo
      idv_session = instance_double(Idv::Session)
      allow(idv_session).to receive(:method_missing).
        with(:address_verification_mechanism).
        and_return('gpo')
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end

    subject(:steps) { controller.step_indicator_steps }

    context 'without an in-person proofing component' do
      let(:doc_auth_step_indicator_steps) do
        [
          { name: :getting_started },
          { name: :verify_id },
          { name: :verify_info },
          { name: :verify_phone_or_address },
          { name: :secure_account },
        ]
      end

      let(:doc_auth_step_indicator_steps_gpo) do
        [
          { name: :getting_started },
          { name: :verify_id },
          { name: :verify_info },
          { name: :get_a_letter },
          { name: :secure_account },
        ]
      end

      context 'without a pending profile' do
        it 'returns doc auth steps' do
          expect(steps).to eq doc_auth_step_indicator_steps
        end
      end

      context 'with a pending profile' do
        let(:profile) { create(:profile, deactivation_reason: :gpo_verification_pending) }

        it 'returns doc auth gpo steps' do
          expect(steps).to eq doc_auth_step_indicator_steps_gpo
        end
      end

      context 'with gpo address verification method' do
        before { force_gpo }

        it 'returns doc auth gpo steps' do
          expect(steps).to eq doc_auth_step_indicator_steps_gpo
        end
      end
    end

    context 'with in person proofing component' do
      let(:in_person_step_indicator_steps) do
        [
          { name: :find_a_post_office },
          { name: :verify_info },
          { name: :verify_phone_or_address },
          { name: :secure_account },
          { name: :go_to_the_post_office },
        ]
      end

      let(:in_person_step_indicator_steps_gpo) do
        [
          { name: :find_a_post_office },
          { name: :verify_info },
          { name: :secure_account },
          { name: :get_a_letter },
          { name: :go_to_the_post_office },
        ]
      end

      context 'via pending profile' do
        let(:profile) do
          create(
            :profile,
            deactivation_reason: :gpo_verification_pending,
            proofing_components: { 'document_check' => Idp::Constants::Vendors::USPS },
          )
        end

        it 'returns in person gpo steps' do
          expect(steps).to eq in_person_step_indicator_steps_gpo
        end
      end

      context 'via current idv session' do
        before do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        it 'returns in person steps' do
          expect(steps).to eq in_person_step_indicator_steps
        end

        context 'with gpo address verification method' do
          before { force_gpo }

          it 'returns in person gpo steps' do
            expect(steps).to eq in_person_step_indicator_steps_gpo
          end
        end
      end
    end
  end
end
