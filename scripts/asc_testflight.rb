#!/usr/bin/env ruby
# Configures external TestFlight testing from docs/store-listing.md and, with
# --submit, sends the build for Beta App Review.
#
# External testing needs four things that internal testing doesn't: app-level
# Beta App Information, Beta App Review contact details, per-build "What to
# Test" notes, and an external beta group. This pushes all four, then optionally
# submits. Idempotent — re-running overwrites the same fields.
#
#   set -a; . ~/Develop/Pet/indonesian-app/fastlane/.env; set +a
#   ruby scripts/asc_testflight.rb --dry-run
#   ruby scripts/asc_testflight.rb              # configure only
#   ruby scripts/asc_testflight.rb --submit     # configure, then submit for review
#   ruby scripts/asc_testflight.rb --build 16   # target a specific build
#
# Contact details are personal and never committed: ASC_CONTACT_FIRST,
# ASC_CONTACT_LAST, ASC_CONTACT_EMAIL, ASC_CONTACT_PHONE. They're the same
# values the App Store review detail uses. Beta App Review requires them, so the
# script aborts rather than skipping if they're unset.
require_relative "asc_listing"

BUNDLE = "cx.viz.callback"
SUBMIT = ARGV.include?("--submit")

build_flag = ARGV.index("--build")
WANT_BUILD = build_flag ? ARGV[build_flag + 1] : nil

# --- 1. app + build ----------------------------------------------------------

puts "== App =="
apps = fetch!("/v1/apps?filter[bundleId]=#{BUNDLE}", "app lookup")
app = Array(apps["data"]).first
abort "no app for bundleId #{BUNDLE}" unless app
APP_ID = app["id"]
puts "  #{app.dig('attributes', 'name').inspect}  id=#{APP_ID}"

puts "\n== Build =="
# Sorting by uploadedDate rather than version: version is a string field, so
# "9" would sort above "16".
builds = fetch!("/v1/builds?filter[app]=#{APP_ID}&limit=20&sort=-uploadedDate", "builds")
candidates = Array(builds["data"])
build = if WANT_BUILD
          candidates.find { |b| b.dig("attributes", "version") == WANT_BUILD }
        else
          candidates.find { |b| b.dig("attributes", "processingState") == "VALID" }
        end
abort "no #{WANT_BUILD ? "build #{WANT_BUILD}" : 'VALID build'} found" unless build
BUILD_ID = build["id"]
BUILD_NO = build.dig("attributes", "version")
state = build.dig("attributes", "processingState")
puts "  build #{BUILD_NO}  id=#{BUILD_ID}  processing=#{state}"
abort "build #{BUILD_NO} is #{state}, not VALID — can't submit for beta review" unless state == "VALID"

detail = fetch!("/v1/builds/#{BUILD_ID}/buildBetaDetail", nil)
ext_state = detail.dig("data", "attributes", "externalBuildState")
puts "  externalBuildState=#{ext_state}"

# --- 2. Beta App Information (app-level, one per locale) ---------------------

puts "\n== Beta App Information =="
blocs = fetch!("/v1/apps/#{APP_ID}/betaAppLocalizations", "beta app localizations")
bloc = Array(blocs["data"]).find { |l| l.dig("attributes", "locale") == LOCALE }
bloc_attrs = {
  description: field("Beta app description"),
  feedbackEmail: field("Beta feedback email"),
  marketingUrl: field("Marketing URL"),
  privacyPolicyUrl: field("Privacy Policy URL")
}
# locale is set-once, on create only.
bloc_attrs[:locale] = LOCALE unless bloc
upsert("betaAppLocalizations", "betaAppLocalizations", bloc && bloc["id"], bloc_attrs,
       { app: { data: { type: "apps", id: APP_ID } } },
       "beta description + feedback email")

# --- 3. Beta App Review details ---------------------------------------------

puts "\n== Beta App Review details =="
contact = {
  contactFirstName: ENV["ASC_CONTACT_FIRST"],
  contactLastName: ENV["ASC_CONTACT_LAST"],
  contactEmail: ENV["ASC_CONTACT_EMAIL"],
  contactPhone: ENV["ASC_CONTACT_PHONE"]
}
missing = contact.select { |_k, v| v.nil? || v.empty? }.keys
unless missing.empty?
  abort "Beta App Review needs #{missing.join(', ')} — export ASC_CONTACT_FIRST/LAST/EMAIL/PHONE " \
        "(values live in ~/Develop/Pet/indonesian-app/fastlane/metadata/review_information/)"
end
bard = fetch!("/v1/apps/#{APP_ID}/betaAppReviewDetail", nil)
upsert("betaAppReviewDetails", "betaAppReviewDetails", bard.dig("data", "id"),
       contact.merge(notes: field("Review notes"), demoAccountRequired: false),
       { app: { data: { type: "apps", id: APP_ID } } },
       "beta review contact + notes")

# --- 4. What to Test (per build) --------------------------------------------

puts "\n== What to Test (build #{BUILD_NO}) =="
bblocs = fetch!("/v1/builds/#{BUILD_ID}/betaBuildLocalizations", "beta build localizations")
bbloc = Array(bblocs["data"]).find { |l| l.dig("attributes", "locale") == LOCALE }
bbloc_attrs = { whatsNew: field("What to test") }
bbloc_attrs[:locale] = LOCALE unless bbloc
upsert("betaBuildLocalizations", "betaBuildLocalizations", bbloc && bbloc["id"], bbloc_attrs,
       { build: { data: { type: "builds", id: BUILD_ID } } },
       "what to test (#{field('What to test').length}ch)")

# --- 5. external group with a capped public link ------------------------------

puts "\n== External group =="
group_name = field("Beta group")
limit = Integer(field("Public link limit"))
groups = fetch!("/v1/apps/#{APP_ID}/betaGroups?limit=50", "beta groups")
group = Array(groups["data"]).find { |g| g.dig("attributes", "name") == group_name }
if group && group.dig("attributes", "isInternalGroup")
  abort "beta group #{group_name.inspect} already exists and is INTERNAL — " \
        "public links need an external group. Rename '**Beta group:**' in #{LISTING}."
end

group_attrs = {
  publicLinkEnabled: true,
  publicLinkLimitEnabled: true,
  publicLinkLimit: limit
}
# name is settable on create and on update, but isInternalGroup is create-only
# (and defaults to external via the API — internal groups can't be made here).
group_attrs[:name] = group_name unless group
ok, body = upsert("betaGroups", "betaGroups", group && group["id"], group_attrs,
                  { app: { data: { type: "apps", id: APP_ID } } },
                  "#{group_name.inspect} public link, cap #{limit}")
abort "could not create/update beta group" unless ok || DRY_RUN
group_id = group ? group["id"] : (body ? body.dig("data", "id") : "<new>")

# --- 6. attach the build to the group ---------------------------------------

puts "\n== Attach build #{BUILD_NO} to #{group_name.inspect} =="
if DRY_RUN
  puts "  DRY  POST /v1/betaGroups/#{group_id}/relationships/builds"
else
  code, body = ASCClient.post("/v1/betaGroups/#{group_id}/relationships/builds",
                              { "data" => [{ "type" => "builds", "id" => BUILD_ID }] })
  already = code == 409 && body.to_s.include?("already")
  puts "  HTTP #{code}  #{already ? 'already attached' : 'attach build'}"
  if code >= 300 && !already
    Array(body.is_a?(Hash) ? body["errors"] : []).each { |e| puts "        #{e['title']}: #{e['detail']}" }
  end
end

# --- 7. submit for Beta App Review ------------------------------------------

puts "\n== Beta App Review submission =="
if !SUBMIT
  puts "  SKIP pass --submit to send build #{BUILD_NO} for Beta App Review"
elsif ext_state == "IN_BETA_TESTING"
  puts "  SKIP build #{BUILD_NO} is already approved and in external testing"
else
  write(:post, "/v1/betaAppReviewSubmissions", {
    data: {
      type: "betaAppReviewSubmissions",
      relationships: { build: { data: { type: "builds", id: BUILD_ID } } }
    }
  }, "submit build #{BUILD_NO} for Beta App Review")
end

# --- 8. report the public link ----------------------------------------------

unless DRY_RUN
  puts "\n== Public link =="
  g = fetch!("/v1/betaGroups/#{group_id}", nil)
  a = g.dig("data", "attributes") || {}
  puts "  enabled=#{a['publicLinkEnabled'].inspect} limit=#{a['publicLinkLimit'].inspect}"
  puts "  #{a['publicLink'] || '(not issued yet — appears once Beta App Review approves the build)'}"
  d = fetch!("/v1/builds/#{BUILD_ID}/buildBetaDetail", nil)
  puts "  externalBuildState=#{d.dig('data', 'attributes', 'externalBuildState')}"
end

puts "\nDone#{DRY_RUN ? ' (dry run — nothing was sent)' : ''}."
