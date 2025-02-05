require 'rails_helper'

describe Users::PasswordsController do
  describe '#update' do
    context 'form returns success' do
      it 'redirects to profile and sends a password change email' do
        stub_sign_in
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)

        expect(@irs_attempts_api_tracker).to receive(:logged_in_password_change).
          with(failure_reason: nil, success: true)

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }

        expect(@analytics).to have_received(:track_event).
          with('Password Changed', success: true, errors: {})
        expect(response).to redirect_to account_url
        expect(flash[:info]).to eq t('notices.password_changed')
        expect(flash[:personal_key]).to be_nil
      end

      it 'calls UpdateUserPassword' do
        stub_sign_in(create(:user))
        updater = instance_double(UpdateUserPasswordForm)
        password = 'strong password'
        allow(UpdateUserPasswordForm).to receive(:new).
          with(subject.current_user, subject.user_session).
          and_return(updater)
        response = FormResponse.new(success: true, errors: {})
        allow(updater).to receive(:submit).and_return(response)
        personal_key = 'five random words for test'
        allow(updater).to receive(:personal_key).and_return(personal_key)

        params = { password: password }
        patch :update, params: { update_user_password_form: params }

        expect(flash[:personal_key]).to eq personal_key
        expect(updater).to have_received(:submit)
        expect(updater).to have_received(:personal_key)
      end

      it 'creates a user Event for the password change' do
        stub_sign_in(create(:user))

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }
      end

      it 'sends a security event' do
        user = create(:user)
        stub_sign_in(user)
        security_event = PushNotification::PasswordResetEvent.new(user: user)
        expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }
      end

      it 'sends the user an email' do
        user = create(:user)

        stub_sign_in(user)

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }

        expect_delivered_email_count(1)
        expect_delivered_email(
          to: [user.email_addresses.first.email],
          subject: t('devise.mailer.password_updated.subject'),
        )
      end
    end

    context 'form returns failure' do
      it 'renders edit' do
        password_short_error = { password: [:too_short] }
        stub_sign_in

        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)

        expect(@irs_attempts_api_tracker).to receive(:logged_in_password_change).with(
          success: false,
          failure_reason: password_short_error,
        )

        params = { password: 'new' }
        patch :update, params: { update_user_password_form: params }

        expect(@analytics).to have_received(:track_event).with(
          'Password Changed',
          success: false,
          errors: {
            password: [
              t('errors.attributes.password.too_short.other', count: Devise.password_length.first),
            ],
          },
          error_details: password_short_error,
        )
        expect(response).to render_template(:edit)
      end

      it 'does not create a password_changed user Event' do
        stub_sign_in

        expect(controller).to_not receive(:create_user_event)

        params = { password: 'new' }
        patch :update, params: { update_user_password_form: params }
      end
    end
  end

  describe '#edit' do
    context 'user has a profile with PII' do
      let(:pii) { { first_name: 'Jane' } }
      before do
        user = create(:user)
        create(:profile, :active, :verified, user: user, pii: pii)
        stub_sign_in(user)
      end

      it 'redirects to capture password if PII is not decrypted' do
        get :edit

        expect(response).to redirect_to capture_password_path
      end

      it 'renders form if PII is decrypted' do
        controller.user_session[:decrypted_pii] = pii.to_json

        get :edit

        expect(response).to render_template(:edit)
      end
    end
  end
end
