require 'json'
require 'net/http'
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
