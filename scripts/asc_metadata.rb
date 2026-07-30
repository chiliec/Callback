#!/usr/bin/env ruby
# Pushes the store listing in docs/store-listing.md — plus categories, age
# rating, content rights, and the 6.9" screenshots — to App Store Connect.
# Idempotent: re-running overwrites the same fields and replaces the screenshot set.
#
#   set -a; . ~/Develop/Pet/indonesian-app/fastlane/.env; set +a
#   ruby scripts/asc_metadata.rb --dry-run
#   ruby scripts/asc_metadata.rb
#   ruby scripts/asc_metadata.rb --skip-screenshots
#
# Review-contact details are personal, so they come from the environment and are
# never committed: ASC_CONTACT_FIRST, ASC_CONTACT_LAST, ASC_CONTACT_EMAIL,
# ASC_CONTACT_PHONE. Omit them and the review-details step is skipped.
require_relative "asc_client"

BUNDLE  = "cx.viz.callback"
VERSION = "0.1.0"
LOCALE  = "en-US"
ROOT    = File.expand_path("..", __dir__)
LISTING = File.join(ROOT, "docs", "store-listing.md")
SHOTS   = File.join(ROOT, "docs", "store-assets", "ios")
# The API has no APP_IPHONE_69: 6.9" images (1320x2868) go in the 6.7" set,
# which is the largest iPhone display type it accepts.
DISPLAY = "APP_IPHONE_67"

DRY_RUN          = ARGV.include?("--dry-run")
SKIP_SCREENSHOTS = ARGV.include?("--skip-screenshots")

LIMITS = {
  "Name" => 30, "Subtitle" => 30, "Keywords" => 100,
  "Promotional text" => 170, "Description" => 4000, "Release notes" => 4000
}.freeze

# --- listing file ------------------------------------------------------------

# Reflows a hard-wrapped markdown block into App Store prose: blank lines stay
# as paragraph breaks, "•" starts a new line, everything else joins with a space.
def reflow(text)
  text.split(/\n{2,}/).map { |para|
    lines = para.split("\n").map(&:strip).reject(&:empty?)
    out = []
    lines.each do |line|
      if line.start_with?("•") || out.empty?
        out << line
      else
        out[-1] = "#{out[-1]} #{line}"
      end
    end
    out.join("\n")
  }.join("\n\n").strip
end

def parse_listing(path)
  fields = {}
  key = nil
  File.readlines(path).each do |line|
    if (m = line.match(/^\*\*(.+?):\*\*[ \t]*(.*)$/))
      key = m[1]
      fields[key] = m[2].to_s
    elsif key
      fields[key] = "#{fields[key]}\n#{line.chomp}"
    end
  end
  fields.each { |k, v| fields[k] = reflow(v) }
  fields
end

LISTING_FIELDS = parse_listing(LISTING)

def field(name)
  value = LISTING_FIELDS[name]
  abort "missing '**#{name}:**' in #{LISTING}" if value.nil? || value.empty?
  limit = LIMITS[name]
  if limit && value.length > limit
    abort "'#{name}' is #{value.length} chars, limit #{limit}"
  end
  value
end

# --- request helpers ---------------------------------------------------------

def check(label, result)
  code, body = result
  ok = code >= 200 && code < 300
  puts "  HTTP #{code}  #{label}"
  unless ok
    errors = body.is_a?(Hash) ? Array(body["errors"]) : []
    errors.each { |e| puts "        #{e['title']}: #{e['detail']}" }
    puts "        #{body.inspect[0, 400]}" if errors.empty?
  end
  [ok, body]
end

def write(verb, path, body, label)
  if DRY_RUN
    puts "  DRY  #{verb.to_s.upcase} #{path}"
    puts "       #{JSON.dump(body)[0, 500]}" if body
    return [true, nil]
  end
  check(label, ASCClient.send(verb, *[path, body].compact))
end

def patch_attrs(path, type, id, attributes, label)
  write(:patch, path, { data: { type: type, id: id, attributes: attributes } }, label)
end

def fetch!(path, label)
  code, body = ASCClient.get(path)
  abort "GET #{path} failed: HTTP #{code} #{body.inspect[0, 300]}" unless code == 200
  puts "  HTTP #{code}  #{label}" if label
  body
end

# --- 1. app ------------------------------------------------------------------

puts "== App =="
apps = fetch!("/v1/apps?filter[bundleId]=#{BUNDLE}", "app lookup")
app = Array(apps["data"]).first
abort "no app for bundleId #{BUNDLE}" unless app
APP_ID = app["id"]
puts "  #{app.dig('attributes', 'name').inspect}  id=#{APP_ID}"

puts "\n== Content rights =="
patch_attrs("/v1/apps/#{APP_ID}", "apps", APP_ID,
            { contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT" },
            "content rights → DOES_NOT_USE_THIRD_PARTY_CONTENT")

# --- 2. app info: categories, name, subtitle, privacy URL --------------------

puts "\n== App info =="
infos = fetch!("/v1/apps/#{APP_ID}/appInfos?include=ageRatingDeclaration", "app infos")
# The editable AppInfo is the one not yet locked by an approved release.
editable = Array(infos["data"]).find { |i|
  state = i.dig("attributes", "state") || i.dig("attributes", "appStoreState")
  state != "READY_FOR_DISTRIBUTION"
} || Array(infos["data"]).first
abort "no editable appInfo" unless editable
INFO_ID = editable["id"]
puts "  appInfo id=#{INFO_ID} state=#{editable.dig('attributes', 'state').inspect}"

write(:patch, "/v1/appInfos/#{INFO_ID}", {
  data: {
    type: "appInfos", id: INFO_ID,
    relationships: {
      primaryCategory: { data: { type: "appCategories", id: field("Primary category") } },
      secondaryCategory: { data: { type: "appCategories", id: field("Secondary category") } }
    }
  }
}, "categories → #{field('Primary category')} / #{field('Secondary category')}")

locs = fetch!("/v1/appInfos/#{INFO_ID}/appInfoLocalizations", "app info localizations")
info_loc = Array(locs["data"]).find { |l| l.dig("attributes", "locale") == LOCALE }
abort "no #{LOCALE} appInfoLocalization" unless info_loc
patch_attrs("/v1/appInfoLocalizations/#{info_loc['id']}", "appInfoLocalizations", info_loc["id"], {
  name: field("Name"),
  subtitle: field("Subtitle"),
  privacyPolicyUrl: field("Privacy Policy URL")
}, "name/subtitle/privacyPolicyUrl → #{field('Name').inspect}")

# --- 3. age rating (4+) ------------------------------------------------------

puts "\n== Age rating =="
ard_id = editable.dig("relationships", "ageRatingDeclaration", "data", "id")
if ard_id.nil?
  ard = fetch!("/v1/appInfos/#{INFO_ID}/ageRatingDeclaration", "age rating declaration")
  ard_id = ard.dig("data", "id")
end
if ard_id
  patch_attrs("/v1/ageRatingDeclarations/#{ard_id}", "ageRatingDeclarations", ard_id, {
    alcoholTobaccoOrDrugUseOrReferences: "NONE",
    contests: "NONE",
    gamblingSimulated: "NONE",
    gunsOrOtherWeapons: "NONE",
    horrorOrFearThemes: "NONE",
    matureOrSuggestiveThemes: "NONE",
    medicalOrTreatmentInformation: "NONE",
    profanityOrCrudeHumor: "NONE",
    sexualContentGraphicAndNudity: "NONE",
    sexualContentOrNudity: "NONE",
    violenceCartoonOrFantasy: "NONE",
    violenceRealisticProlongedGraphicOrSadistic: "NONE",
    violenceRealistic: "NONE",
    advertising: false,
    ageAssurance: false,
    gambling: false,
    healthOrWellnessTopics: false,
    lootBox: false,
    messagingAndChat: false,
    parentalControls: false,
    socialMedia: false,
    socialMediaAgeRestricted: false,
    unrestrictedWebAccess: false,
    userGeneratedContent: false,
    ageRatingOverrideV2: "NONE",
    koreaAgeRatingOverride: "NONE",
    kidsAgeBand: nil
  }, "age rating → 4+")
else
  puts "  SKIP no ageRatingDeclaration found"
end

# --- 4. App Store version ----------------------------------------------------

puts "\n== App Store version #{VERSION} =="
versions = fetch!("/v1/apps/#{APP_ID}/appStoreVersions?limit=20", "versions")
editable_states = %w[
  PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED
  INVALID_BINARY WAITING_FOR_REVIEW
]
match = Array(versions["data"]).find { |v| v.dig("attributes", "versionString") == VERSION }
open_version = match || Array(versions["data"]).find { |v|
  editable_states.include?(v.dig("attributes", "appStoreState") || v.dig("attributes", "appVersionState"))
}

if open_version.nil?
  ok, body = write(:post, "/v1/appStoreVersions", {
    data: {
      type: "appStoreVersions",
      attributes: { platform: "IOS", versionString: VERSION },
      relationships: { app: { data: { type: "apps", id: APP_ID } } }
    }
  }, "create version #{VERSION}")
  abort "could not create version #{VERSION}" unless ok
  version_id = body ? body.dig("data", "id") : "<new>"
else
  version_id = open_version["id"]
  current = open_version.dig("attributes", "versionString")
  puts "  reusing existing version record #{current.inspect} id=#{version_id}"
  if current != VERSION
    # ASC only offers builds whose CFBundleShortVersionString matches this
    # string, and the uploaded builds are 0.1.0 — so rename rather than add.
    patch_attrs("/v1/appStoreVersions/#{version_id}", "appStoreVersions", version_id,
                { versionString: VERSION }, "versionString #{current} → #{VERSION}")
  end
end

vloc_id = "<vloc>"
unless DRY_RUN
  vlocs = fetch!("/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", "version localizations")
  version_loc = Array(vlocs["data"]).find { |l| l.dig("attributes", "locale") == LOCALE }
  abort "no #{LOCALE} appStoreVersionLocalization" unless version_loc
  vloc_id = version_loc["id"]
end

loc_attrs = {
  description: field("Description"),
  keywords: field("Keywords"),
  promotionalText: field("Promotional text"),
  supportUrl: field("Support URL"),
  marketingUrl: field("Marketing URL"),
  whatsNew: field("Release notes")
}
label = "description/keywords/urls (#{field('Description').length}ch description)"
ok, body = patch_attrs("/v1/appStoreVersionLocalizations/#{vloc_id}",
                       "appStoreVersionLocalizations", vloc_id, loc_attrs, label)

# 'What's New' only exists for updates — an initial release rejects it, and the
# rejection takes the whole PATCH down with it. Retry without it.
if !ok && body.is_a?(Hash) && Array(body["errors"]).any? { |e| e["detail"].to_s.include?("whatsNew") }
  puts "  retrying without whatsNew (first release has no release notes)"
  loc_attrs.delete(:whatsNew)
  patch_attrs("/v1/appStoreVersionLocalizations/#{vloc_id}",
              "appStoreVersionLocalizations", vloc_id, loc_attrs, label)
end

# --- 5. review details (optional, needs a personal phone number) -------------

puts "\n== Review details =="
contact = {
  contactFirstName: ENV["ASC_CONTACT_FIRST"],
  contactLastName: ENV["ASC_CONTACT_LAST"],
  contactEmail: ENV["ASC_CONTACT_EMAIL"],
  contactPhone: ENV["ASC_CONTACT_PHONE"]
}
if contact.values.all? { |v| v && !v.empty? }
  attrs = contact.merge(notes: field("Review notes"), demoAccountRequired: false)
  details = DRY_RUN ? nil : ASCClient.get("/v1/appStoreVersions/#{version_id}/appStoreReviewDetail")[1]
  existing_id = details.is_a?(Hash) ? details.dig("data", "id") : nil
  if existing_id
    patch_attrs("/v1/appStoreReviewDetails/#{existing_id}", "appStoreReviewDetails",
                existing_id, attrs, "review contact + notes")
  else
    write(:post, "/v1/appStoreReviewDetails", {
      data: {
        type: "appStoreReviewDetails", attributes: attrs,
        relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version_id } } }
      }
    }, "review contact + notes")
  end
else
  puts "  SKIP ASC_CONTACT_* not set — enter review contact details in the browser"
end

# --- 6. screenshots ----------------------------------------------------------

puts "\n== Screenshots (#{DISPLAY}) =="
pngs = Dir[File.join(SHOTS, "*.png")].sort
if SKIP_SCREENSHOTS
  puts "  SKIP --skip-screenshots"
elsif pngs.empty?
  puts "  SKIP no PNGs in docs/store-assets/ios — run scripts/capture-screenshots.sh first"
elsif DRY_RUN
  puts "  DRY  would upload #{pngs.length} screenshots:"
  pngs.each { |p| puts "       #{File.basename(p)} (#{File.size(p)} bytes)" }
else
  sets = fetch!("/v1/appStoreVersionLocalizations/#{vloc_id}/appScreenshotSets", "screenshot sets")
  set = Array(sets["data"]).find { |s| s.dig("attributes", "screenshotDisplayType") == DISPLAY }
  if set
    set_id = set["id"]
    puts "  reusing set id=#{set_id}"
    existing = fetch!("/v1/appScreenshotSets/#{set_id}/appScreenshots", nil)
    Array(existing["data"]).each do |shot|
      check("delete #{shot.dig('attributes', 'fileName')}", ASCClient.delete("/v1/appScreenshots/#{shot['id']}"))
    end
  else
    ok, body = write(:post, "/v1/appScreenshotSets", {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: DISPLAY },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: "appStoreVersionLocalizations", id: vloc_id }
          }
        }
      }
    }, "create #{DISPLAY} set")
    abort "could not create screenshot set" unless ok
    set_id = body["data"]["id"]
  end

  pngs.each do |path|
    bytes = File.binread(path)
    ok, body = check("reserve #{File.basename(path)}", ASCClient.post("/v1/appScreenshots", {
      data: {
        type: "appScreenshots",
        attributes: { fileName: File.basename(path), fileSize: bytes.bytesize },
        relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set_id } } }
      }
    }))
    next unless ok
    shot_id = body["data"]["id"]
    Array(body.dig("data", "attributes", "uploadOperations")).each do |op|
      code = ASCClient.upload(op, bytes)
      puts "  HTTP #{code}  upload chunk offset=#{op['offset']} length=#{op['length']}"
    end
    patch_attrs("/v1/appScreenshots/#{shot_id}", "appScreenshots", shot_id,
                { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) },
                "commit #{File.basename(path)}")
  end
end

puts "\nDone#{DRY_RUN ? ' (dry run — nothing was sent)' : ''}."
