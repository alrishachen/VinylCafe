# Vinyl Cafe ☕️🎶

A personal iOS app for tracking your music life: Spotify listening analytics, album & song
ratings and reviews (Letterboxd-for-music), curated lists, and a vinyl collection log.

## Features

- **Stats** — listening analytics from your Spotify history: top artists/songs/albums, hours
  listened, day streak, and charts of when you listen (by month, hour of day, weekday). Built
  from synced recent plays and/or an imported Spotify data export.
- **Library** — rate albums and songs (half-stars) and write reviews. Filter by rated/reviewed
  and search.
- **Lists** — keep "Want to Listen" and "Good Stuff" lists with drag-to-reorder and sorting by
  date, title, artist, or rating.
- **Vinyl** — log your record collection. A record is a first-class **album**: it lives in your
  library, gets rated/reviewed/listed like anything else, and additionally carries the physical
  copy's details (label, catalog #, pressing year, color, condition).
- **Settings** — connect Spotify, sync, import your data export, and the in-app setup guide.

## Tech

- SwiftUI + **SwiftData** (all data stored locally on device), iOS 18+.
- Swift Charts for analytics visualizations.
- Spotify **Authorization Code + PKCE** auth via `ASWebAuthenticationSession`; tokens in the
  Keychain. No client secret.

## Project layout

```
VinylCafe/
  VinylCafeApp.swift      App entry, ModelContainer, first-launch sample data
  Models/                 SwiftData models + data-access helpers + sample/preview data
  Services/               Spotify auth, API client, sync, import, analytics engine
  Features/               Dashboard, Library, Lists, Vinyl, Detail, Settings
  Shared/                 Reusable views (cover art, star rating, cards)
```

## Running

Open `VinylCafe.xcodeproj` in Xcode and run on a simulator or device, or:

```sh
xcodebuild -scheme VinylCafe -destination 'platform=iOS Simulator,name=iPhone 17' build
```

The app is fully usable offline and ships with sample data so every screen has content. To
wire up live Spotify analytics, follow **[SETUP.md](SETUP.md)**.

## Spotify caveats

Spotify's Web API (for new apps, post-2024) has no full-history endpoint and dropped audio
features/recommendations. Vinyl Cafe works within that: it accumulates history via sync and
supports importing your "Extended streaming history" export for complete analytics. See
SETUP.md for details.
