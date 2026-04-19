# Fastlane — TestFlight builds

Native iOS build + TestFlight upload. No Expo / EAS.

## One-time setup

1. Install Ruby deps (from `app/`):
   ```sh
   cd app
   bundle install
   ```

2. Create an **App Store Connect API Key** (Users and Access → Keys → App Store Connect API → `+`):
   - Role: `App Manager` (or higher)
   - Download the `.p8` file — you can only download it once
   - Note the **Key ID** and **Issuer ID** shown on that page

3. Export env vars (add to `~/.zshrc` or a local `.env` you source):
   ```sh
   export ASC_KEY_ID="XXXXXXXXXX"
   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   export ASC_KEY_PATH="/absolute/path/to/AuthKey_XXXXXXXXXX.p8"
   ```

## Shipping a build

```sh
cd app
bundle exec fastlane beta
```

This will:
- Install CocoaPods
- Pull latest TestFlight build number and increment
- Archive + export IPA via `gym`
- Upload to TestFlight via `pilot` (does not wait for processing)

## Build without uploading

```sh
bundle exec fastlane build
```

Produces `app/build/BroadcastBrain.ipa`.
