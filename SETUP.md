# Connecting Vinyl Cafe to Spotify

Vinyl Cafe works fully offline for ratings, reviews, lists, and vinyl logging. To pull in
your listening analytics you connect your own free Spotify developer app. It takes ~5 minutes
and you only do it once.

> **Why this step exists:** Spotify requires every app to have its own Client ID. There's no
> shared key. The good news: it's free, needs no review, and uses the secure PKCE flow (no
> secret stored in the app).

## 1. Create a Spotify app

1. Go to <https://developer.spotify.com/dashboard> and log in with your Spotify account.
2. Click **Create app**.
3. Fill in:
   - **App name:** Vinyl Cafe (or anything)
   - **App description:** Personal listening stats
   - **Redirect URI:** paste exactly:
     ```
     vinylcafe://callback
     ```
     then click **Add**.
   - **Which API/SDKs are you planning to use?** check **Web API**.
4. Agree to the terms and click **Save**.

## 2. Copy your Client ID

1. Open your new app, then go to **Settings**.
2. Copy the **Client ID** (a long string of letters and numbers).

## 3. Add yourself as a user

New apps start in **development mode**, which only works for accounts you explicitly allow
(up to 25). To allow yourself:

1. In the app's dashboard, open **User Management**.
2. Add your own name and the email on your Spotify account. Save.

## 4. Connect in the app

1. Open Vinyl Cafe → **Settings**.
2. Paste your **Client ID** into the field and tap **Save**.
3. Tap **Connect Spotify** and approve access.

You're connected! Tap **Sync Recently Played** (or the refresh button on the Stats tab) to
pull in plays.

## 5. (Recommended) Import your full history

Spotify's API only returns your **last 50 plays**, so syncing alone builds history slowly
from today forward. For *years* of data at once, import your data export:

1. Go to <https://www.spotify.com/account/privacy/> and request your
   **Extended streaming history** (not the basic one). Spotify emails you a ZIP in a few days.
2. Unzip it. You'll find files like `Streaming_History_Audio_2023_1.json`.
3. In Vinyl Cafe → **Settings → Import Spotify Data Export**, select those JSON files.

Your Stats tab will fill in with the full picture. ✨

## Notes & limitations

- Spotify retired several API features for new apps in late 2024 (audio features like
  danceability/energy, recommendations, related artists, 30-second previews). Vinyl Cafe's
  analytics are built entirely from your play history and top tracks/artists, which remain
  available.
- All your data — ratings, reviews, lists, vinyl, and imported history — stays on your device.
