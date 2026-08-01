# Callback — App Store listing

Single source of truth for the store copy. `scripts/asc_metadata.rb` parses this
file and pushes it to App Store Connect, so edit here — never in the web UI.

Format contract: each field is a `**Key:** value` line. A field whose value is
empty continues until the next `**Key:**` line. Prose is reflowed on push —
hard-wrapped lines inside a paragraph become one line, blank lines stay as
paragraph breaks, and `•` starts a new line.

**Name:** Callback: Interview Prep

**Subtitle:** iOS interview prep, offline

**Promotional text:**
Six core topics, timed mock interviews, and a review queue that remembers what
you got wrong. No account, no network, no tracking.

**Keywords:**
swift,ios,interview,developer,swiftui,uikit,concurrency,memory,arc,quiz,practice,coding,prep

**Description:**
Callback prepares you for iOS developer interviews — on the train, in a waiting
room, or the night before the real thing. Everything works offline. There is no
account to create, nothing to sign in to, and no network connection required.

WHAT YOU GET

• Six core topics — Swift, Memory, Concurrency, SwiftUI, UIKit, and Behavioral —
each with focused lessons and a bank of interview-grade questions.
• Short, readable lessons with syntax-highlighted Swift, each ending in a quick
check so you find out immediately whether it stuck.
• Timed mock interviews with a pause-safe timer that survives backgrounding, so
a phone call doesn't cost you the session.
• A review queue that automatically resurfaces every question you got wrong or
flagged — the fastest way to turn weak spots into strong ones.
• Behavioral questions come with a model-answer rubric you score yourself
against, because that's how they're actually assessed.
• A readiness score that weights recent answers more heavily than old ones and
accounts for how much of each topic you've actually covered.
• Full VoiceOver support, Dynamic Type throughout, and Reduce Motion respected.

PRIVATE BY DESIGN

Callback makes no network requests at all. Your progress lives on your device
and nowhere else. There is no analytics SDK, no advertising, and no crash
reporting. You can export everything you've done as a JSON file, or erase it in
one tap.

Get the callback.

**Support URL:** https://chiliec.github.io/Callback/

**Marketing URL:** https://chiliec.github.io/Callback/

**Privacy Policy URL:** https://chiliec.github.io/Callback/privacy.html

**Primary category:** EDUCATION

**Secondary category:** DEVELOPER_TOOLS

**Age rating:** 4+

**Copyright:** 2026 Vladimir Babin

**Release notes:** First release.

**Review notes:**
Callback is fully offline. No account or sign-in is required — launch the app
and everything is immediately available. First launch offers an optional
placement quiz which can be skipped with the Skip button.

## TestFlight

Pushed by `scripts/asc_testflight.rb`. "Beta app description" and "Beta
feedback email" are app-level Beta App Information; "What to test" is per-build.

**Beta app description:**
Callback is an offline iOS interview-prep app — lessons, question drills, timed
mock interviews, and a review queue that resurfaces whatever you got wrong.
There is no account and no network access of any kind; everything runs on your
device.

**Beta feedback email:** vovababin@gmail.com

**Beta group:** Public Beta

**Public link limit:** 100

**What to test:**
This build fixes the "No way to continue." report from build 17: at the end of a
lesson, the "Up next" card named the following lesson but did nothing when
tapped. Your progress carries over untouched.

• Open any topic → its first lesson, scroll to the bottom, and tap "Up next".
It should open the next lesson, and you should be able to keep tapping through
to the end of the topic. On the last lesson the card is gone — there is nothing
after it yet.
• Practice → Review queue → Review N questions → "Covers this gap" at the
bottom of a review card. That should open the lesson, and "Up next" should work
from there too.
• The lesson header should read "Lesson 2 of 3" and so on, matching where you
actually are.
• Still worth a look if you haven't yet: Topics → Mobile System Design (4
lessons, 27 open-ended questions you rate yourself on), Practice → System Design
and Behavioral, and Profile → Level (Junior / Mid / Senior).
• Anything else: backgrounding the app mid-mock (the timer should survive),
VoiceOver, and large Dynamic Type sizes.
