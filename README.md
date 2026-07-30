# Callback

Native iPhone app (iOS 18+) that prepares iOS developers for job interviews.
Local-first — no accounts, no network, no analytics.

Tagline: *Get the callback.*

## Requirements

- macOS 14+
- Xcode 16.4+
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build & Run

```bash
xcodegen generate
xcodebuild build \
  -scheme Callback \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

## TestFlight

Signing uses Apple team `7JF6XQC536` and bundle ID `cx.viz.callback` (set in
`project.yml`). Bump `CURRENT_PROJECT_VERSION` in `project.yml` first — App Store
Connect rejects a build number it has already seen, and `ExportOptions.plist` sets
`manageAppVersionAndBuildNumber: false` so the export won't quietly renumber it
for you.

```bash
xcodegen generate
xcodebuild archive -scheme Callback -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Callback.xcarchive
xcodebuild -exportArchive -archivePath build/Callback.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
xcrun altool --upload-app -f build/export/Callback.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

The App Store Connect API key lives at
`~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8` (never in this repo).
Swap `--upload-app` for `--validate-app` to dry-run the checks without consuming
the build number.

`ruby scripts/asc_status.rb` (same env vars) prints build processing/beta state
and the beta groups, read-only — no gems required.

## Run Tests

```bash
# Package unit tests (no simulator needed)
swift test --package-path Packages/AppCore
swift test --package-path Packages/DesignSystem

# UI smoke test (requires iOS simulator runtime)
xcodebuild test \
  -scheme Callback \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:CallbackUITests/SmokeTests
```

## Architecture

Modern MV + `@Observable` + SwiftData. Two local SPM packages:

- **`DesignSystem`** — design tokens, `ProgressRing`, `CodeBlock`, `OptionRow`, `GroupedCard`, et al.  
- **`AppCore`** — SwiftData models, `ContentLoader`, `ScoringEngine`, `ReviewQueue`.

App target holds all feature folders (`Home`, `Topics`, `Practice`, `Session`, `Review`,
`Reader`, `Placement`, `Profile`, `Onboarding`) and the tab/navigation shell.

`.xcodeproj` is gitignored and regenerated deterministically from `project.yml` via XcodeGen.

## Content

Lessons and questions live in `Packages/AppCore/Sources/AppCore/Resources/content-v1.json`.

### Schema (simplified)

```json
{
  "version": 2,
  "topics": [
    {
      "id": "string (UUID)",
      "name": "string",
      "section": "fundamentals | frameworks | craft",
      "symbolName": "SF Symbol name",
      "colorToken": "hex string e.g. #007AFF",
      "order": 0,
      "lessons": [
        {
          "id": "string (UUID)",
          "order": 0,
          "title": "string",
          "estimatedMinutes": 5,
          "body": "markdown string (fenced code blocks supported)",
          "quickCheck": { "…question object…" }
        }
      ],
      "questions": [
        {
          "id": "string (UUID)",
          "kind": "multipleChoice | code | behavioral",
          "prompt": "string",
          "codeSnippet": { "filename": "string", "language": "string", "code": "string" },
          "options": [
            { "id": "string (UUID)", "order": 0, "text": "string", "isMonospaced": false }
          ],
          "correctIndex": 2,
          "explanation": "string",
          "rubric": "string (behavioral only, correctIndex omitted)"
        }
      ]
    }
  ]
}
```

User progress (mastery, answers, sessions, profile) lives only in the SwiftData store,
never in the JSON. Bumping `"version"` triggers an upsert that preserves all user progress.

## License

MIT
