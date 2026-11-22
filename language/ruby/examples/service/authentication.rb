require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module ServiceAuth
  Principal = Struct.new(:subject, :tenant, :expires, keyword_init: true)

  class AuthError < StandardError; end

  class ContextAuthenticator
    def initialize(tenant)
      @tenant = tenant
    end

    def authenticate(principal, _authorization = nil, _now = Time.now.to_i)
      return nil if principal.nil? || principal.empty?

      Principal.new(subject: principal, tenant: @tenant, expires: nil)
    end
  end

  class NetHttpTransport
    def get_json(url)
      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 2,
        read_timeout: 2
      ) { |http| http.request(request) }
      [response.code.to_i, response.body.to_s]
    rescue StandardError
      raise AuthError, 'identity provider unavailable'
    end

    def post_form(url, form, authorization)
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request['Authorization'] = authorization if authorization
      request.body = form
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 2,
        read_timeout: 2
      ) { |http| http.request(request) }
      [response.code.to_i, response.body.to_s]
    rescue StandardError
      raise AuthError, 'identity provider unavailable'
    end
  end

  class IntrospectionAuthenticator
    def initialize(transport:, endpoint:, client_id: '', client_secret: '',
                   tenant_claim: 'tenant')
      @transport = transport
      @endpoint = endpoint
      @client_id = client_id
      @client_secret = client_secret
      @tenant_claim = tenant_claim.empty? ? 'tenant' : tenant_claim
    end

    def authenticate(authorization, now = Time.now.to_i)
      return nil unless authorization&.start_with?('Bearer ')

      token = authorization.delete_prefix('Bearer ').strip
      return nil if token.empty?

      form = URI.encode_www_form(
        'token' => token,
        'client_id' => @client_id,
        'client_secret' => @client_secret
      )
      status, body = @transport.post_form(@endpoint, form, basic_auth)
      return nil unless status == 200

      payload = JSON.parse(body)
      return nil unless payload.is_a?(Hash) && payload['active'] == true

      subject = payload['sub']
      tenant = payload[@tenant_claim]
      expires = payload['exp']
      return nil unless subject.is_a?(String) && !subject.empty?
      return nil unless tenant.is_a?(String) && !tenant.empty?
      return nil unless expires.is_a?(Integer) && expires > now

      Principal.new(subject: subject, tenant: tenant, expires: expires)
    rescue AuthError, JSON::ParserError
      nil
    end

    private

    def basic_auth
      return nil if @client_id.empty?

      raw = "#{@client_id}:#{@client_secret}"
      "Basic #{[raw].pack('m0')}"
    end
  end

  class OidcAuthenticator
    ALGORITHMS = {
      'RS256' => OpenSSL::Digest.new('SHA256'),
      'RS384' => OpenSSL::Digest.new('SHA384'),
      'RS512' => OpenSSL::Digest.new('SHA512')
    }.freeze
    CACHE_SECONDS = 300

    def initialize(transport:, issuer:, audience:, jwks_url: '',
                   discovery_url: '', tenant_claim: 'tenant')
      raise ArgumentError, 'issuer is required' if issuer.nil? || issuer.empty?
      raise ArgumentError, 'audience is required' if audience.nil? || audience.empty?

      @transport = transport
      @issuer = issuer.sub(%r{/+$}, '')
      @audience = audience
      @jwks_url = jwks_url
      @discovery_url = discovery_url
      @tenant_claim = tenant_claim.empty? ? 'tenant' : tenant_claim
      @keys = nil
      @keys_at = 0
      @metadata = nil
      @metadata_at = 0
    end

    def authenticate(authorization, now = Time.now.to_i)
      return nil unless authorization&.start_with?('Bearer ')

      token = authorization.delete_prefix('Bearer ').strip
      parts = token.split('.')
      return nil unless parts.length == 3

      header = JSON.parse(ServiceAuth.b64url_decode(parts[0]))
      claims = JSON.parse(ServiceAuth.b64url_decode(parts[1]))
      return nil unless header.is_a?(Hash) && claims.is_a?(Hash)

      algorithm = header['alg']
      kid = header['kid']
      digest = ALGORITHMS[algorithm]
      return nil if digest.nil? || kid.nil? || kid.empty?

      issuer = claims['iss']
      return nil unless issuer.is_a?(String) && issuer.sub(%r{/+$}, '') == @issuer
      return nil unless audience_matches?(claims['aud'])
      return nil unless claims['exp'].is_a?(Integer) && claims['exp'] > now
      return nil if claims['nbf'].is_a?(Integer) && claims['nbf'] > now
      subject = claims['sub']
      tenant = claims[@tenant_claim]
      return nil unless subject.is_a?(String) && !subject.empty?
      return nil unless tenant.is_a?(String) && !tenant.empty?

      key = find_key(kid, algorithm, refresh: false)
      key = find_key(kid, algorithm, refresh: true) if key.nil?
      return nil if key.nil?

      signature = ServiceAuth.b64url_decode(parts[2])
      return nil unless rsa_key(key).verify(digest, signature, "#{parts[0]}.#{parts[1]}")

      Principal.new(subject: subject, tenant: tenant, expires: claims['exp'])
    rescue AuthError, JSON::ParserError, OpenSSL::OpenSSLError
      nil
    end

    private

    def audience_matches?(value)
      case value
      when String then value == @audience
      when Array then value.include?(@audience)
      else false
      end
    end

    def find_key(kid, algorithm, refresh:)
      now = Time.now.to_i
      if @keys.nil? || refresh || now - @keys_at > CACHE_SECONDS
        url = @jwks_url
        url = metadata['jwks_uri'] if url.empty?
        raise AuthError, 'identity provider JWKS is not configured' if url.nil? || url.empty?

        body = fetch_json(url)
        keys = body.is_a?(Hash) ? body['keys'] : nil
        raise AuthError, 'invalid JWKS' unless keys.is_a?(Array)

        @keys = keys.each_with_object({}) do |item, result|
          next unless item.is_a?(Hash)

          item_kid = item['kid']
          result[item_kid] = item if item_kid.is_a?(String) && !item_kid.empty?
        end
        @keys_at = now
      end
      key = @keys[kid]
      return nil unless key.is_a?(Hash)
      return nil unless key['kty'] == 'RSA'
      return nil unless key['use'].nil? || key['use'] == 'sig'
      return nil unless key['alg'].nil? || key['alg'] == algorithm

      key
    end

    def metadata
      now = Time.now.to_i
      return @metadata if @metadata && now - @metadata_at <= CACHE_SECONDS

      url = @discovery_url
      url = "#{@issuer}/.well-known/openid-configuration" if url.empty?
      body = fetch_json(url)
      issuer = body.is_a?(Hash) ? body['issuer'] : nil
      raise AuthError, 'invalid provider issuer' unless issuer.is_a?(String) &&
        issuer.sub(%r{/+$}, '') == @issuer

      @metadata = body
      @metadata_at = now
      @metadata
    end

    def fetch_json(url)
      status, body = @transport.get_json(url)
      raise AuthError, 'identity provider unavailable' unless status == 200

      JSON.parse(body)
    rescue JSON::ParserError
      raise AuthError, 'invalid provider response'
    end

    def rsa_key(jwk)
      modulus = OpenSSL::BN.new(ServiceAuth.b64url_decode(jwk['n']), 2)
      exponent = OpenSSL::BN.new(ServiceAuth.b64url_decode(jwk['e']), 2)
      rsa_public_key = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer(modulus),
        OpenSSL::ASN1::Integer(exponent)
      ])
      algorithm = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::ObjectId('rsaEncryption'),
        OpenSSL::ASN1::Null(nil)
      ])
      spki = OpenSSL::ASN1::Sequence([
        algorithm,
        OpenSSL::ASN1::BitString(rsa_public_key.to_der)
      ])
      OpenSSL::PKey::RSA.new(spki.to_der)
    end
  end

  def self.b64url_decode(value)
    text = value.tr('-_', '+/')
    text += '=' * ((4 - text.length % 4) % 4)
    text.unpack1('m0')
  end

  def self.b64url(value)
    [value].pack('m0').tr('+/', '-_').delete('=')
  end

  class RevocationClient
    def initialize(transport:, endpoint:, client_id: '', client_secret: '')
      @transport = transport
      @endpoint = endpoint
      @client_id = client_id
      @client_secret = client_secret
    end

    def revoke(token, token_type_hint: 'access_token')
      raise AuthError, 'revocation token is required' if token.nil? || token.empty?

      form = URI.encode_www_form(
        'token' => token,
        'token_type_hint' => token_type_hint,
        'client_id' => @client_id,
        'client_secret' => @client_secret
      )
      status, = @transport.post_form(@endpoint, form, basic_auth)
      raise AuthError, 'token revocation failed' unless status == 200

      true
    end

    private

    def basic_auth
      return nil if @client_id.empty?

      raw = "#{@client_id}:#{@client_secret}"
      "Basic #{[raw].pack('m0')}"
    end
  end
end
