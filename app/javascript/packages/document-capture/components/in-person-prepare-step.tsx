import { useContext, useEffect } from 'react';
import { Alert, Link, PageHeading, ProcessList, ProcessListItem } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import UploadContext from '../context/upload';
import MarketingSiteContext from '../context/marketing-site';
import AnalyticsContext from '../context/analytics';
import BackButton from './back-button';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';
import { InPersonContext } from '../context';

function InPersonPrepareStep({ toPreviousStep }) {
  const { t } = useI18n();
  const { flowPath } = useContext(UploadContext);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);
  const { securityAndPrivacyHowItWorksURL } = useContext(MarketingSiteContext);
  const { inPersonURL, inPersonCtaVariantActive } = useContext(InPersonContext);

  useEffect(() => {
    setSubmitEventMetadata({ in_person_cta_variant: inPersonCtaVariantActive });
  }, []);

  return (
    <>
      <Alert type="warning" className="margin-bottom-4">
        <>
          <strong>
            {t('idv.failure.exceptions.post_office_outage_error_message.post_cta.title')}
          </strong>
          <br />
          <br />
          {t('idv.failure.exceptions.post_office_outage_error_message.post_cta.body', {
            app_name: getConfigValue('appName'),
          })}
          <br />
        </>
      </Alert>

      <PageHeading>{t('in_person_proofing.headings.prepare')}</PageHeading>

      <p>{t('in_person_proofing.body.prepare.verify_step_about')}</p>

      <ProcessList className="margin-bottom-4">
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_post_office')}
          headingUnstyled
        />
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_pii')}
          headingUnstyled
        />
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_phone')}
          headingUnstyled
        />
      </ProcessList>
      {inPersonURL && flowPath === 'standard' ? (
        <FormStepsButton.Continue className="margin-y-5" />
      ) : (
        <FormStepsButton.Continue />
      )}
      <p>
        {t('in_person_proofing.body.prepare.privacy_disclaimer', {
          app_name: getConfigValue('appName'),
        })}{' '}
        {securityAndPrivacyHowItWorksURL && (
          <>
            {t('in_person_proofing.body.prepare.privacy_disclaimer_questions')}{' '}
            <Link href={securityAndPrivacyHowItWorksURL}>
              {t('in_person_proofing.body.prepare.privacy_disclaimer_link')}
            </Link>
          </>
        )}
      </p>
      <InPersonTroubleshootingOptions />
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonPrepareStep;
