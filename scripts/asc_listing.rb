#!/usr/bin/env ruby
# Shared plumbing for the App Store Connect push scripts (asc_metadata.rb,
# asc_testflight.rb): parses docs/store-listing.md — the single source of truth
# for both store and TestFlight copy — and wraps ASCClient with logging, a
# --dry-run guard, and upsert helpers.
#
# Not executable on its own. Top-level defs (rather than a module) match the
# style of the scripts that require it and keep their call sites unchanged.
require_relative "asc_client"

ROOT    = File.expand_path("..", __dir__)
LISTING = File.join(ROOT, "docs", "store-listing.md")
LOCALE  = "en-US"

DRY_RUN = ARGV.include?("--dry-run")

LIMITS = {
  "Name" => 30, "Subtitle" => 30, "Keywords" => 100,
  "Promotional text" => 170, "Description" => 4000, "Release notes" => 4000,
  "Beta app description" => 4000, "What to test" => 4000
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
    elsif line.match(/^\#{1,6}\s/)
      # A markdown heading ends the open field — otherwise a section heading and
      # its prose get appended to whatever field happened to come last.
      key = nil
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

# Creates the record when it doesn't exist yet, patches it when it does. ASC
# models most one-to-one child resources this way, so every push script needs it.
def upsert(collection, type, existing_id, attributes, relationships, label)
  if existing_id
    patch_attrs("/v1/#{collection}/#{existing_id}", type, existing_id, attributes, label)
  else
    write(:post, "/v1/#{collection}", {
      data: { type: type, attributes: attributes, relationships: relationships }
    }, label)
  end
end
