#!/usr/bin/env ruby
# Read-only App Store Connect status for Callback. No writes.
#
#   set -a; . ~/Develop/Pet/indonesian-app/fastlane/.env; set +a
#   ruby scripts/asc_status.rb
#
# Signs its own ES256 JWT with the OpenSSL stdlib, so no gems are required.
require "net/http"
require "json"
require "openssl"
require "base64"

KEY_ID  = ENV.fetch("ASC_KEY_ID")
ISSUER  = ENV.fetch("ASC_ISSUER_ID")
P8_PATH = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{KEY_ID}.p8")
BUNDLE  = "cx.viz.callback"

def b64(data)
  Base64.urlsafe_encode64(data, padding: false)
end

# ASN.1 DER (what OpenSSL emits) -> raw r||s concatenation (what JWS wants).
def der_to_raw(der)
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2) }
  r.rjust(32, "\0") + s.rjust(32, "\0")
end

def token
  now = Time.now.to_i
  header  = b64(JSON.dump(alg: "ES256", kid: KEY_ID, typ: "JWT"))
  payload = b64(JSON.dump(iss: ISSUER, iat: now, exp: now + 600, aud: "appstoreconnect-v1"))
  signing_input = "#{header}.#{payload}"
  key = OpenSSL::PKey::EC.new(File.read(P8_PATH))
  "#{signing_input}.#{b64(der_to_raw(key.sign(OpenSSL::Digest.new('SHA256'), signing_input)))}"
end

def get(path)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{token}"
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  [res.code, (JSON.parse(res.body) rescue res.body)]
end

code, apps = get("/v1/apps?filter[bundleId]=#{BUNDLE}")
abort "app lookup failed: HTTP #{code} #{apps.inspect[0, 300]}" unless apps.is_a?(Hash) && apps["data"]&.any?
app = apps["data"].first
puts "App: #{app.dig('attributes', 'name')}  bundleId=#{app.dig('attributes', 'bundleId')}  id=#{app['id']}"

puts "\n== Builds =="
code, builds = get("/v1/builds?filter[app]=#{app['id']}&limit=10&sort=-version")
if builds.is_a?(Hash) && builds["data"]
  builds["data"].each do |b|
    a = b["attributes"]
    puts "  build #{a['version']}  processing=#{a['processingState']}  expired=#{a['expired']}  uploaded=#{a['uploadedDate']}"
    c, d = get("/v1/builds/#{b['id']}/buildBetaDetail")
    puts "    internal=#{d.dig('data', 'attributes', 'internalBuildState')}  external=#{d.dig('data', 'attributes', 'externalBuildState')}" if d.is_a?(Hash) && d["data"]
  end
else
  puts "  HTTP #{code} #{builds.inspect[0, 300]}"
end

puts "\n== Beta groups =="
code, groups = get("/v1/betaGroups?filter[app]=#{app['id']}&limit=20")
if groups.is_a?(Hash) && groups["data"]
  puts "  (none — no internal testing group exists yet)" if groups["data"].empty?
  groups["data"].each do |g|
    a = g["attributes"]
    c, t = get("/v1/betaGroups/#{g['id']}/betaTesters?limit=50")
    count = t.is_a?(Hash) && t["data"] ? t["data"].length : "?"
    puts "  #{a['name']}  internal=#{a['isInternalGroup']}  testers=#{count}  id=#{g['id']}"
  end
else
  puts "  HTTP #{code} #{groups.inspect[0, 300]}"
end
