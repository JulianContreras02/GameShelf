# GameShelf

**English** · [Español](README.es.md)

[![CI](https://github.com/JulianContreras02/GameShelf/actions/workflows/ci.yml/badge.svg)](https://github.com/JulianContreras02/GameShelf/actions/workflows/ci.yml)

A personal iOS app that keeps your whole video game library in one place, no
matter which store each game came from.

## What it does

- Connects your Steam, PlayStation Network, Epic Games and Xbox accounts to
  bring in the games you already own.
- Lets you organize that library with your own folders and lists (backlog,
  favorites, anything), which no store lets you do across platforms.
- Checks deals on your wishlist through a price-aggregator API
  (IsThereAnyDeal) instead of reinventing scraping for every store.

It is a learning project: my first app in the Apple ecosystem, which I am also
using to experiment with iOS accessibility features.

## Running it

### 1. Create your secrets file

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

That file is ignored by git. Today it does not need anything in it: every key
is connected from inside the app (see the next section). It is still part of
the Xcode project, and it is where a key would go if one were ever needed
before the user does anything.

### 2. Run

Open `GameShelf.xcodeproj` in Xcode and run it on the simulator or on your
device.

### Requirements

- Xcode 26.5 or later: the project targets iOS 26.5, and that SDK shipped with
  Xcode 26.5.
- [SwiftLint](https://github.com/realm/SwiftLint) 0.65.1, the same version CI
  uses: `brew install swiftlint` installs the latest, which may report
  differently.

## Connecting accounts and keys

Steam, PlayStation, Epic, Xbox and IsThereAnyDeal are connected from the app,
under **Settings**, and their credentials are stored encrypted in the phone's
Keychain. None of them live in the secrets file: that is what lets you install
the app on another phone and connect different accounts there without
rebuilding.

### Steam

Unlike PSN and Epic, Steam offers an official path: you do not need to sign in
from the app.

1. Get your SteamID64 at https://steamid.io by pasting your profile URL.
2. Get a free API key at https://steamcommunity.com/dev/apikey (it asks for a
   domain; `localhost` works).
3. Paste both values into **Settings → Steam**.

### PlayStation and Epic

Both are a workaround for the same reason: neither Sony nor Epic offers a
"sign in" for third-party apps. The only option is to copy a code from the
browser while you are already signed in.

### PlayStation Network

1. Sign in at https://www.playstation.com/ ("Sign In" button).
2. **In the same browser**, open
   https://ca.account.sony.com/api/v1/ssocookie
3. Copy the value between quotes and paste it into the app.

The two steps share the browser session, which is why they must happen in the
same browser. If the second one returns
`{"error":"invalid_grant","error_description":"Invalid login"}`, step 1 is
missing.

That code lasts about two months. Meanwhile the app renews access by itself.

### Epic Games

> **Warning.** Epic states on its own page that this code **gives full access
> to the account**. GameShelf stores it encrypted in the Keychain and never
> sends it to any server, but you should not paste it anywhere else.

1. Sign in at https://www.epicgames.com/id/login
2. **In the same browser**, open
   https://www.epicgames.com/id/api/redirect?clientId=34a02cf8f4414e29b15921876da36f9a&responseType=code
3. Copy the value after `"authorizationCode"`, between quotes, and paste it
   into the app **right away**.

Epic codes expire within seconds. If the app says the code is not valid,
reload that page and copy the new one. If the page shows
`"authorizationCode": null`, step 1 is missing.

### Xbox

Microsoft does not offer a public client for third-party apps the way PSN and
Epic do with theirs (taken from their own mobile apps): you have to register
your own app in Azure, once, and use that client ID and client secret from
GameShelf.

#### Register the app in Azure (once)

1. Go to https://portal.azure.com with your Microsoft account (the same one as
   Xbox) and search for **"App registrations"**.
2. **New registration**. Under "Supported account types" choose **"Personal
   Microsoft accounts only"**.
3. Under **"Add a platform"** choose **"Web"** (not "Mobile and desktop
   applications") and set the Redirect URI to:
   `http://localhost/auth/callback`
4. Copy the **"Application (client) ID"** shown on the app's page: that is the
   first piece.
5. Go to **"Certificates & secrets" → "New client secret"** and copy the
   **value** as soon as it is generated. Azure only shows it once; if you lose
   it, you have to create a new one.

#### Connect from the app

1. Paste the client ID and client secret into **Settings → Xbox**, section
   "Your Azure app".
2. Tap "1. Sign in with Microsoft" and authorize the app.
3. The page will **fail when it reaches `localhost`**: that is expected,
   nothing is listening there. The code is already in the **address bar**, not
   on the page. Copy what follows `code=`.
4. Paste that code into the app.

Access renews by itself as long as Microsoft's refresh token keeps working. The
Azure app (client ID and secret) is not deleted when you disconnect the
session: it belongs to you, not to the session, and Azure will not show the
secret again.

#### Bring in your games

With the account connected, tap **Settings → Xbox → "Bring in my Xbox
games"**. They arrive with their Gamerscore (earned and total) and hours
played. If a game was already there from Steam, PlayStation or Epic, it is
merged into that one instead of showing up twice.

Two things differ from the other stores:

- Xbox does not return what you bought but your **play history**: a game you
  bought and never opened does not appear.
- Hours come from a separate request. If that one fails, the games still
  arrive, with the hours they already had (or 0 the first time).

### Deals and prices (IsThereAnyDeal)

This one is just an API key, free and without an account:

1. Get it at https://isthereanydeal.com/apps/my/
2. Paste it into **Settings → Deals and prices**.

Without it the wishlist looks the same, just without prices or deals.

### When one of them fails

Each store works on its own. If Epic's flow stops working, or Sony changes
theirs, **the rest of the app keeps working**: your saved library, collections
and notes do not depend on them.

## Project status

In progress. See `CONTRIBUTING.md` for the working rules.
