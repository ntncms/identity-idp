require 'base16'

module IrsAttemptsApi
  class EnvelopeEncryptor
    Result = Struct.new(:filename, :iv, :encrypted_key, :encrypted_data, keyword_init: true)

    # A new key is generated for each encryption.  This key is encrypted with the public_key
    # provided so that only the owner of the private key may decrypt this data.
    def self.encrypt(data:, timestamp:, public_key_str:)
      compressed_data = Zlib.gzip(data)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.encrypt
      key = cipher.random_key
      iv = cipher.random_iv
      public_key = OpenSSL::PKey::RSA.new(Base64.strict_decode64(public_key_str))
      encrypted_data = cipher.update(compressed_data) + cipher.final
      encoded_data = Base16.encode16(encrypted_data)
      digest = Digest::SHA256.hexdigest(encoded_data)
      encrypted_key = public_key.public_encrypt(key)
      formatted_time = formatted_timestamp(timestamp)

      filename =
        "FCI-Logingov_#{formatted_time}_#{digest}.dat.gz.hex"

      Result.new(
        filename: filename,
        iv: iv,
        encrypted_key: encrypted_key,
        encrypted_data: encoded_data,
      )
    end

    def self.formatted_timestamp(timestamp)
      timestamp.strftime('%Y%m%dT%HZ')
    end

    def self.decrypt(encrypted_data:, key:, iv:)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      decrypted = cipher.update(Base16.decode16(encrypted_data)) + cipher.final

      Zlib.gunzip(decrypted)
    end
  end
end
