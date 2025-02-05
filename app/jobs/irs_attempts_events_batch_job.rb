class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(timestamp = Time.zone.now - 1.hour)
    enabled = IdentityConfig.store.irs_attempt_api_enabled && s3_helper.attempts_s3_write_enabled
    return nil unless enabled

    previous_hour = timestamp - 1.hour
    # Check if previous hour was properly loaded
    IrsAttemptsEventsBatchJob.perform_later(previous_hour) if missing_log_file?(previous_hour)

    start_time = Time.zone.now
    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: timestamp)
    event_values = events.values.join("\r\n")

    public_key = IdentityConfig.store.irs_attempt_api_public_key

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: timestamp, public_key_str: public_key,
    )

    upload_to_s3_response = create_and_upload_to_attempts_s3_resource(
      bucket_name: s3_helper.attempts_bucket_name, filename: result.filename,
      encrypted_data: result.encrypted_data
    )

    encoded_iv = Base64.strict_encode64(result.iv)
    encoded_encrypted_key = Base64.strict_encode64(result.encrypted_key)

    irs_attempts_api_log_file = IrsAttemptApiLogFile.create(
      filename: result.filename,
      iv: encoded_iv,
      encrypted_key: encoded_encrypted_key,
      requested_time: timestamp_key(key: timestamp),
    )

    log_irs_attempts_events_job_info(result, events, start_time)
    redis_client.remove_events(timestamp: timestamp) if upload_to_s3_response&.etag
    irs_attempts_api_log_file
  end

  def timestamp_key(key:)
    IrsAttemptsApi::EnvelopeEncryptor.formatted_timestamp(key)
  end

  def missing_log_file?(previous_hour)
    previous_hour_log_file_hash = {
      requested_time: timestamp_key(key: previous_hour),
    }

    !IrsAttemptApiLogFile.find_by(previous_hour_log_file_hash) &&
      reasonable_timespan?(previous_hour)
  end

  def reasonable_timespan?(check_time)
    check_time.after?(3.days.ago)
  end

  def create_and_upload_to_attempts_s3_resource(bucket_name:, filename:, encrypted_data:)
    aws_object = Aws::S3::Resource.new(client: s3_helper.s3_client).
      bucket(bucket_name).object(filename)
    aws_object.put(body: encrypted_data, acl: 'private', content_type: 'text/plain')
  end

  def redis_client
    @redis_client ||= IrsAttemptsApi::RedisClient.new
  end

  def s3_helper
    @s3_helper ||= JobHelpers::S3Helper.new
  end

  def log_irs_attempts_events_job_info(result, events, start_time)
    logger_info_hash(
      name: 'IRSAttemptsEventJob',
      start_time: start_time,
      end_time: Time.zone.now,
      duration_ms: duration_ms(start_time),
      events_count: events.values.count,
      file_bytes_size: result.encrypted_data.bytesize,
    )
  end

  def logger_info_hash(hash)
    logger.info(hash.to_json)
  end

  def duration_ms(start_time)
    Time.zone.now.to_f - start_time.to_f
  end
end
