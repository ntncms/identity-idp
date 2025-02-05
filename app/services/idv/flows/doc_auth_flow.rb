module Idv
  module Flows
    class DocAuthFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::WelcomeStep,
        agreement: Idv::Steps::AgreementStep,
        upload: Idv::Steps::UploadStep,
        link_sent: Idv::Steps::LinkSentStep,
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :getting_started },
        { name: :verify_id },
        { name: :verify_info },
        { name: :verify_phone_or_address },
        { name: :secure_account },
      ].freeze

      STEP_INDICATOR_STEPS_GPO = [
        { name: :getting_started },
        { name: :verify_id },
        { name: :verify_info },
        { name: :get_a_letter },
        { name: :secure_account },
      ].freeze

      OPTIONAL_SHOW_STEPS = {}.freeze

      ACTIONS = {
        cancel_link_sent: Idv::Actions::CancelLinkSentAction,
        redo_document_capture: Idv::Actions::RedoDocumentCaptureAction,
      }.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= {}
      end

      def extra_analytics_properties
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(flow_session[:document_capture_session_uuid]),
        }
      end
    end
  end
end
