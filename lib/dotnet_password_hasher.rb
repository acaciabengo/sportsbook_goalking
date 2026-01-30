# frozen_string_literal: true

require 'base64'
require 'openssl'

class DotnetPasswordHasher
  # ASP.NET Identity password hash formats
  V2_HEADER = 0x00 # Identity v2: PBKDF2 with HMAC-SHA1, 128-bit salt, 256-bit subkey, 1000 iterations
  V3_HEADER = 0x01 # Identity v3: PBKDF2 with HMAC-SHA256/SHA512, configurable

  class << self
    def verify(plain_password, hashed_password)
      return false if plain_password.nil? || hashed_password.nil?

      decoded = Base64.decode64(hashed_password)
      return false if decoded.empty?

      header = decoded.bytes.first

      case header
      when V2_HEADER
        verify_v2(plain_password, decoded)
      when V3_HEADER
        verify_v3(plain_password, decoded)
      else
        false
      end
    rescue ArgumentError, StandardError
      false
    end

    private

    def verify_v2(plain_password, decoded)
      # V2 format: 0x00 | salt (16 bytes) | subkey (32 bytes)
      return false if decoded.bytesize != 49

      salt = decoded[1, 16]
      stored_subkey = decoded[17, 32]

      derived_subkey = OpenSSL::KDF.pbkdf2_hmac(
        plain_password,
        salt: salt,
        iterations: 1000,
        length: 32,
        hash: 'SHA1'
      )

      secure_compare(derived_subkey, stored_subkey)
    end

    def verify_v3(plain_password, decoded)
      # V3 format: 0x01 | prf (4 bytes) | iter count (4 bytes) | salt length (4 bytes) | salt | subkey
      return false if decoded.bytesize < 13

      bytes = decoded.bytes

      prf = bytes[1, 4].pack('C*').unpack1('N')
      iteration_count = bytes[5, 4].pack('C*').unpack1('N')
      salt_length = bytes[9, 4].pack('C*').unpack1('N')

      return false if decoded.bytesize < 13 + salt_length

      salt = decoded[13, salt_length]
      subkey_length = decoded.bytesize - 13 - salt_length
      stored_subkey = decoded[13 + salt_length, subkey_length]

      hash_algorithm = case prf
                       when 0 then 'SHA1'
                       when 1 then 'SHA256'
                       when 2 then 'SHA512'
                       else return false
                       end

      derived_subkey = OpenSSL::KDF.pbkdf2_hmac(
        plain_password,
        salt: salt,
        iterations: iteration_count,
        length: subkey_length,
        hash: hash_algorithm
      )

      secure_compare(derived_subkey, stored_subkey)
    end

    def secure_compare(a, b)
      return false if a.bytesize != b.bytesize

      OpenSSL.fixed_length_secure_compare(a, b)
    rescue NoMethodError
      # Fallback for older OpenSSL versions
      a.bytes.zip(b.bytes).reduce(0) { |acc, (x, y)| acc | (x ^ y) }.zero?
    end
  end
end
