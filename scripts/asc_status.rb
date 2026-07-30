#!/usr/bin/env ruby
# Read-only App Store Connect status for Callback. No writes.
#
#   set -a; . ~/Develop/Pet/indonesian-app/fastlane/.env; set +a
#   ruby scripts/asc_status.rb
#
# JWT signing and transport live in scripts/asc_client.rb (no gems required).
require_relative "asc_client"

BUNDLE = "cx.viz.callback"

def get(path)
  ASCClient.get(path)
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

puts "\n== App Store versions =="
code, versions = get("/v1/apps/#{app['id']}/appStoreVersions?limit=5")
if versions.is_a?(Hash) && versions["data"]
  puts "  (none — no App Store version record exists yet)" if versions["data"].empty?
  versions["data"].each do |v|
    a = v["attributes"]
    puts "  #{a['versionString']}  state=#{a['appStoreState'] || a['appVersionState']}  release=#{a['releaseType']}  id=#{v['id']}"
    c, b = get("/v1/appStoreVersions/#{v['id']}/build")
    puts "    attached build=#{b.dig('data', 'attributes', 'version') || '(none)'}" if b.is_a?(Hash)
    c, s = get("/v1/appStoreVersions/#{v['id']}/appStoreVersionLocalizations?limit=5")
    if s.is_a?(Hash) && s["data"]
      s["data"].each do |l|
        la = l["attributes"]
        desc = la["description"].to_s
        puts "    #{la['locale']}: description=#{desc.length}ch keywords=#{la['keywords'].to_s.length}ch " \
             "support=#{la['supportUrl'].inspect}"
      end
    end
  end
else
  puts "  HTTP #{code} #{versions.inspect[0, 300]}"
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
