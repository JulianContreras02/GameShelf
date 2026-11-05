# GameShelf

**English** · [Español](README.es.md)

[![CI](https://github.com/JulianContreras02/GameShelf/actions/workflows/ci.yml/badge.svg)](https://github.com/JulianContreras02/GameShelf/actions/workflows/ci.yml)

A personal iOS app that keeps your video game library in one place, no matter
which store the games come from.

## What it does

- Connects your Steam, PlayStation Network, Epic Games and Xbox accounts to
  bring in the games you already own.
- Lets you organize that library with your own folders and lists (backlog,
  favorites, whatever you like), something no store lets you do across
  platforms.
- Checks your wishlist for deals through a price aggregator API
  (IsThereAnyDeal), instead of reinventing scraping for every store.

It's a learning project: my first app in the Apple ecosystem, and I'm also
using it to experiment with the iOS accessibility features.

## How to run it

### 1. Create your secrets file

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

That file is ignored by git. Right now you don't need to put anything in it:
every key is connected from inside the app (see the next section). It is still
part of the Xcode project, and it's where a key would go if a future feature
needs one before the user does anything.

### 2. Run

Open `GameShelf.xcodeproj` in Xcode and run it on the simulator or on your
device.

### Requirements

- Xcode 26.5 or later: the project requires iOS 26.5, and that SDK shipped with Xcode 26.5
- [SwiftLint](https://github.com/realm/SwiftLint) 0.65.1, the same version CI uses:
  `brew install swiftlint` installs the latest one, which may flag different things.

## Connecting accounts and keys

Steam, PlayStation, Epic, Xbox and IsThereAnyDeal are connected from the app,
in **Settings**, and their credentials are stored encrypted in the phone's
keychain. None of them lives in the secrets file: that's what lets you install
the app on another phone and connect different accounts there, without
rebuilding.

### Steam

Unlike PSN and Epic, Steam does offer an official route: you don't need to
sign in from the app.

1. Find your SteamID64 at https://steamid.io by pasting your profile URL.
2. Get a free API key at https://steamcommunity.com/dev/apikey (it asks for a
   domain; `localhost` works).
3. Paste both values in **Settings -> Steam**.

### PlayStation and Epic

Both need a workaround for the same reason: neither Sony nor Epic offers a
"sign in" for third-party apps. The only option is to copy a code from the
browser while you're already signed in.

### PlayStation Network

1. Sign in at https://www.playstation.com/ ("Sign In" button).
2. **In the same browser**, open
   https://ca.account.sony.com/api/v1/ssocookie
3. Copy what appears between the quotes and paste it into the app.

What the two steps share is the session, which is why they have to happen in
the same browser. If the second one responds with
`{"error":"invalid_grant","error_description":"Invalid login"}`, you skipped
step 1.

That code lasts about two months. In the meantime the app renews access on
its own.

### Epic Games

> **Heads up.** Epic warns on its own page that this code **gives full access
> to the account**. GameShelf stores it encrypted in the keychain and never
> sends it to any server, but you shouldn't paste it anywhere else.

1. Sign in at https://www.epicgames.com/id/login
2. **In the same browser**, open
   https://www.epicgames.com/id/api/redirect?clientId=34a02cf8f4414e29b15921876da36f9a&responseType=code
3. Copy what comes after `"authorizationCode"`, between the quotes, and paste
   it into the app **right away**.

Epic codes expire within seconds. If the app says the code doesn't work when
you paste it, just reload that page and copy the new one. If the page shows
`"authorizationCode": null`, you skipped step 1.

### Xbox

Microsoft doesn't offer a public client for third-party apps the way PSN and
Epic do with theirs (taken from their own mobile apps): you have to register
your own app in Azure, once, and use its client id and client secret from
GameShelf.

#### Register the app in Azure (one time only)

1. Go to https://portal.azure.com with your Microsoft account (the same one
   you use for Xbox) and search for **"App registrations"**.
2. **New registration**. Under "Supported account types" choose **"Personal
   Microsoft accounts only"**.
3. Under **"Add a platform"** choose **"Web"** (not "Mobile and desktop
   applications") and set the Redirect URI to:
   `http://localhost/auth/callback`
4. Copy the **"Application (client) ID"** shown on the app's page: that's the
   first piece.
5. Go to **"Certificates & secrets" -> "New client secret"** and copy the
   **value** as soon as it's generated. Azure only shows it that one time; if
   you lose it, you'll have to create a new one.

#### Connect from the app

1. Paste the client ID and the client secret in **Settings -> Xbox**, under
   "Your Azure app".
2. Tap "1. Sign in with Microsoft" and authorize the app.
3. The page will **fail when it reaches `localhost`**: that's expected,
   nothing is listening there. The code is already in the **address bar**, not
   on the page. Copy what comes after `code=`.
4. Paste that code into the app.

Access renews itself as long as the Microsoft refresh token stays valid. The
Azure app (client id and secret) isn't deleted when you disconnect the
session: it belongs to you, not to the session, and Azure won't let you see it
again.

#### Bring in your games

With the account connected, tap **Settings -> Xbox -> "Bring in my Xbox
games"**. They come with their Gamerscore (earned and total) and hours
played. If a game was already there from Steam, PlayStation or Epic, it's
merged into that one instead of showing up twice.

Two things are different from the other stores:

- Xbox doesn't give you the list of what you bought but your **play
  history**: a game you bought and never launched doesn't show up.
- Hours come from a separate query. If that one fails, the games still
  arrive, with whatever hours they already had (or 0 the first time).

### Prices and deals (IsThereAnyDeal)

This one really is just an API key, free and with no account needed:

1. Get it at https://isthereanydeal.com/apps/my/
2. Paste it in **Settings -> Prices and deals**.

Without it the wishlist looks the same, just without prices or deals.

### What happens if one fails

Each store works independently. If the Epic flow stops working, or if Sony
changes theirs, **the rest of the app keeps working as before**: your saved
library, collections and notes don't depend on them.

## Project status

Work in progress. See `CONTRIBUTING.md` for the working rules.
