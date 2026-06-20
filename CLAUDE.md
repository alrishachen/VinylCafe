# Vinyl Cafe — Project Guide

Vinyl Cafe is a native **SwiftUI + SwiftData** iPhone app (iOS 18+) for personal Spotify
listening analytics, album/song ratings & reviews, lists, and vinyl collection logging.

- **Repo:** `alrishachen/VinylCafe` (GitHub). Use the **`gh` CLI** for all GitHub work.
- **Build:** `xcodebuild -scheme VinylCafe -destination 'platform=iOS Simulator,name=iPhone 17' build`
- **Run on simulator:** `xcrun simctl boot "iPhone 17"`, then install + launch the built `.app`.
- **Install on a physical iPhone:** **Build ≠ install.** In Xcode use **Run ▶** (not Build), or push
  the signed build with `xcrun devicectl device install app --device <id> <path-to>.app`. With a free
  Apple ID the signing **expires after 7 days** — rebuild + reinstall to refresh it.
- Source lives under `VinylCafe/` (`Models/`, `Services/`, `Features/`, `Shared/`). See `README.md`
  for the full layout and `SETUP.md` for Spotify connection.

---

## Project status & progress (last updated 2026-06-19)

**Where things stand:** the app is fully built and runs on the **iPhone 17 simulator** and is
installed on a **physical iPhone 14**. All four feature areas work with local persistence and seeded
sample data. Spotify is fully coded but **not yet connected** (the user hasn't registered a Spotify
developer app / entered a Client ID yet).

**What's built (v1, all functional):**
- **Models/** — SwiftData: `Artist`, `Album`, `Track`, `VinylCopy`, `PlayRecord`, `Rating`,
  `Review`, `ListEntry`, plus `Enums`, `Store` (LibraryActions helper), `SampleData` (first-launch seed).
- **Services/** — `SpotifyConfig`, `Keychain`, `SpotifyAuth` (Authorization Code + PKCE via
  `ASWebAuthenticationSession`), `SpotifyAPIClient`, `SyncService` (recently-played → PlayRecords),
  `ImportService` (Spotify data-export JSON → PlayRecords), `AnalyticsEngine`, `SpotifyController`.
- **Features/** — five tabs: **Stats** (analytics + Swift Charts), **Library** (ratings/reviews),
  **Lists** (want-to-listen / good, drag-reorder + sort), **Vinyl** (collection grid + add record),
  **Settings** (connect Spotify, sync, import, setup guide). Shared unified Album/Track **Detail**
  screen handles rating + review + lists + vinyl copies.
- **Vinyl is a first-class album:** owning a record = attaching a `VinylCopy` to an `Album`; that
  album is rated/reviewed/listed like any other. The Vinyl tab is a filtered library view.

**Key design constraint (Spotify API, post-2024):** no full-history endpoint and audio-features/
recommendations were retired for new apps. Analytics are built from top tracks/artists + accumulated
`recently-played` syncs + an imported "Extended streaming history" data export. No in-app playback.

**Operational facts / hard-won gotchas:**
- **Build ≠ install on device.** Use Xcode **Run ▶**, or push the signed build:
  `xcrun devicectl device install app --device 7FD2EA75-113A-54EF-83CC-EA0A66CB5B18 <path-to>.app`
  (that UDID is the user's iPhone 14). Find the build at
  `~/Library/Developer/Xcode/DerivedData/VinylCafe-*/Build/Products/Debug-iphoneos/VinylCafe.app`.
- **Free Apple ID signing expires every ~7 days** → "App not available"; rebuild + reinstall to refresh.
- This automated shell **can't reach the macOS GUI keychain** (hit this with codesign and with git
  HTTPS auth). Device code-signing must run via the user's Xcode; git auth goes through `gh`.
- **`gh` CLI is installed** at `~/.local/bin/gh` and authenticated as `alrishachen` (scopes: repo,
  workflow). It's the credential path for pushes. Not on bare PATH unless the user adds
  `~/.local/bin` to `~/.zshrc`.

**Backlog / next steps:**
- Connect Spotify for real (user does the 5-min dev-app registration in `SETUP.md`).
- Custom **named** lists in the UI (the `ListEntry` model already supports `kind == .custom`).
- Tap-through from Stats top-lists into the Detail screen to rate.
- Album artwork caching; per-genre analytics.

---

## Development model: a three-agent system

All feature work in this repo flows through three roles. Each is a dispatchable subagent under
`.claude/agents/`. Dispatch the matching agent for the phase you're in.

| Agent | File | Role |
|-------|------|------|
| **Project Manager** | `.claude/agents/project-manager.md` | Operational. Tracks GitHub issues, closes them when features are complete, groups features into daily/weekly milestones, and writes summaries & reports. |
| **Coder** | `.claude/agents/coder.md` | Implementation. Takes a single GitHub issue and implements *only* that task in Swift, with sufficient tests and clean, simple code. |
| **Reviewer / Release** | `.claude/agents/reviewer.md` | Quality assurance. Reviews the Coder's work against the issue, then commits and pushes the code to GitHub. |

---

## The workflow

> **Cardinal rule — issue first, always.** The **Project Manager opens a GitHub issue containing a
> plan, refined with the user's feedback, *before any implementation begins*.** No code is written
> until an approved issue exists. If asked to build something without an issue, the first step is to
> create the issue and get the plan approved — not to start coding.

The loop for every feature:

1. **Plan (PM).** The Project Manager opens a GitHub issue describing the problem and a proposed
   plan, then iterates with the user until they approve it. The issue includes **acceptance
   criteria** so "done" is unambiguous.
2. **Implement (Coder).** Once the issue is approved, the Coder implements **only that issue's
   scope** — sufficient tests, clean and simple code, no gold-plating or unrelated changes. The
   Coder builds locally to confirm it compiles but does **not** push.
3. **Review & release (Reviewer).** The Reviewer verifies the implementation meets the issue's
   acceptance criteria and that tests pass. If it does, the Reviewer commits and pushes to GitHub
   (branch + PR referencing the issue). If it doesn't, the Reviewer sends it back to the Coder with
   specifics — it is not released.
4. **Close & report (PM).** When the feature is verified complete, the Project Manager closes the
   issue, keeps issues grouped into the current daily/weekly **milestone**, and writes
   summaries/reports of progress.

---

## Conventions

- **Issues** follow this shape: **Problem** (what & why) → **Plan** (approach) → **Acceptance
  criteria** (checklist) → **Milestone** (day/week). Link related issues.
- **Branches:** `feature/<issue#>-short-slug` (e.g. `feature/12-custom-lists`). Reference the issue
  in commits and PRs (`Closes #12`).
- **Commits:** small and descriptive; the Reviewer is the one who commits/pushes for a feature.
- **Tests:** every implemented issue ships with enough tests to cover the new behavior. The Reviewer
  blocks release if coverage of the issue's behavior is missing.
- **Scope discipline:** the Coder changes only what the issue asks for. Anything else becomes a new
  issue for the PM to triage.
