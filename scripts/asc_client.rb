# Minimal App Store Connect API client. No gems — signs its own ES256 JWT with
# the OpenSSL stdlib, so it runs on system Ruby 2.6.
#
#   set -a; . ~/Develop/Pet/indonesian-app/fastlane/.env; set +a
#   ruby -r./scripts/asc_client -e 'p ASCClient.get("/v1/apps")'
require "net/http"
require "json"
require "openssl"
require "base64"
require "digest"

module ASCClient
  KEY_ID  = ENV.fetch("ASC_KEY_ID")
  ISSUER  = ENV.fetch("ASC_ISSUER_ID")
  P8_PATH = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{KEY_ID}.p8")
  HOST    = "api.appstoreconnect.apple.com"

  def self.b64(data)
    Base64.urlsafe_encode64(data, padding: false)
  end

  # ASN.1 DER (what OpenSSL emits) -> raw r||s concatenation (what JWS wants).
  def self.der_to_raw(der)
    r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2) }
    r.rjust(32, "\0") + s.rjust(32, "\0")
  end

  def self.token
    now = Time.now.to_i
    header  = b64(JSON.dump(alg: "ES256", kid: KEY_ID, typ: "JWT"))
    payload = b64(JSON.dump(iss: ISSUER, iat: now, exp: now + 600, aud: "appstoreconnect-v1"))
    signing_input = "#{header}.#{payload}"
    key = OpenSSL::PKey::EC.new(File.read(P8_PATH))
    "#{signing_input}.#{b64(der_to_raw(key.sign(OpenSSL::Digest.new('SHA256'), signing_input)))}"
  end

  def self.request(klass, path, body = nil)
    uri = URI("https://#{HOST}#{path}")
    req = klass.new(uri)
    req["Authorization"] = "Bearer #{token}"
    if body
      req["Content-Type"] = "application/json"
      req.body = JSON.dump(body)
    end
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    [res.code.to_i, (JSON.parse(res.body) rescue res.body)]
  end

  def self.get(path)
    request(Net::HTTP::Get, path)
  end

  def self.post(path, body)
    request(Net::HTTP::Post, path, body)
  end

  def self.patch(path, body)
    request(Net::HTTP::Patch, path, body)
  end

  def self.delete(path)
    request(Net::HTTP::Delete, path)
  end

  # Raw byte upload to a pre-signed asset URL from an `uploadOperations` entry.
  # These go to a different host and take no Authorization header.
  def self.upload(operation, bytes)
    uri = URI(operation["url"])
    req = Net::HTTP::Put.new(uri)
    (operation["requestHeaders"] || []).each { |h| req[h["name"]] = h["value"] }
    req.body = bytes[operation["offset"], operation["length"]]
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
    res.code.to_i
  end
end
