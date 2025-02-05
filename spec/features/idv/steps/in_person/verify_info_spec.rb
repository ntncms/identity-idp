require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'doc auth IPP VerifyInfo', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_verify_info_controller_enabled).
      and_return(true)
  end

  it 'provides back buttons for address, state ID, and SSN that discard changes',
     allow_browser_log: true do
    user = user_with_2fa

    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user)
    complete_address_step(user)
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_CITY)
    expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    fill_in t('in_person_proofing.form.state_id.first_name'), with: 'bad first name'
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).not_to have_text('bad first name')

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    fill_in t('idv.form.address1'), with: 'bad address'
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).not_to have_text('bad address')

    # click update ssn button
    click_button t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_fail
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    complete_verify_step(user)

    # phone page
    expect(page).to have_content(t('titles.idv.phone'))
  end

  it 'returns the user to the verify info page when updates are made',
     allow_browser_log: true do
    user = user_with_2fa

    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user)
    complete_address_step(user)
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_CITY)
    expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    fill_in t('in_person_proofing.form.state_id.first_name'), with: 'Natalya'
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text('Natalya')
    expect(page).not_to have_text('bad first name')

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    fill_in t('idv.form.address1'), with: '987 Fake St.'
    choose t('in_person_proofing.form.address.same_address_choice_yes')
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text('987 Fake St.')
    expect(page).not_to have_text('bad address')

    # click update ssn button
    click_button t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_in t('idv.form.ssn_label_html'), with: '900-12-2345'
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text('9**-**-***5')

    complete_verify_step(user)

    # phone page
    expect(page).to have_content(t('titles.idv.phone'))
  end

  context 'with in person verify info controller enabled ' do
    let(:capture_secondary_id_enabled) { true }
    let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }
    let(:user) { user_with_2fa }
    let(:same_address_as_id) { true }
    let(:double_address_verification) { true }

    before do
      allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
        and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_verify_info_controller_enabled).
        and_return(true)
      allow(user).to receive(:establishing_in_person_enrollment).
        and_return(enrollment)
    end

    it 'displays expected headers & data on /verify_info',
       allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
      complete_state_id_step(
        user, same_address_as_id: same_address_as_id,
              double_address_verification: double_address_verification
      )
      click_idv_continue
      complete_ssn_step(user)

      # confirm url is /verify_info
      expect(page).to have_current_path(idv_in_person_verify_info_path)

      # verify page
      expect(page).to have_content(t('headings.verify'))

      # confirm headers are on template
      expect(page).to have_content(t('headings.state_id').tr(' ', ' '))
      expect(page).to have_content(t('headings.residential_address'))
      expect(page).to have_content(t('headings.ssn'))

      # confirm data is on template
      expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
      expect(page).to have_text(
        "#{I18n.t('idv.form.issuing_state')}: #{Idp::Constants::
        MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION}",
      ).once
      expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1).twice
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2).twice
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY).twice
      expect(page).to have_text(
        Idp::Constants::
                MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_address_state],
      ).twice

      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
      expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)
    end
  end
end
