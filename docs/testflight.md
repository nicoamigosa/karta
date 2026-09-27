# TestFlight delivery

The `TestFlight` GitHub Actions workflow archives, signs and uploads Karta from
a hosted macOS runner. It is manual so no pull request or merge uploads a build
by accident.

## Apple setup

1. Join the Apple Developer Program.
2. Register `app.karta.Karta` as an explicit App ID in Certificates,
   Identifiers & Profiles.
3. Create the matching app record in App Store Connect.
4. Create an Apple Distribution certificate, export it with its private key as
   a password-protected `.p12`, and create an App Store provisioning profile
   for the App ID.
5. In App Store Connect, create a team API key with access to upload builds.
   Download its `.p8` file immediately; Apple only offers the download once.

If `app.karta.Karta` is unavailable, change `PRODUCT_BUNDLE_IDENTIFIER` in
`Karta/project.yml` and `APP_IDENTIFIER` in the workflow to the registered
identifier before creating the profile and app record.

## GitHub environment

Create an environment named `testflight` in the repository. Add:

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | The 10-character Apple Developer Team ID |
| Secret | `BUILD_CERTIFICATE_BASE64` | Base64-encoded distribution `.p12` |
| Secret | `P12_PASSWORD` | Password used when exporting the `.p12` |
| Secret | `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded App Store `.mobileprovision` |
| Secret | `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| Secret | `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer ID |
| Secret | `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded API `.p8` |

On macOS, encode each file without writing its contents to the terminal:

```sh
base64 -i Distribution.p12 | pbcopy
base64 -i Karta_AppStore.mobileprovision | pbcopy
base64 -i AuthKey_KEYID.p8 | pbcopy
```

Paste each clipboard value into its corresponding GitHub secret.

## Upload a build

1. Open **Actions → TestFlight → Run workflow**.
2. Enter the user-facing version, for example `0.1.0`.
3. Run the workflow from `main`.
4. After Apple finishes processing the build, add the intended internal tester
   in App Store Connect and accept the invitation in the TestFlight iPhone app.

GitHub's workflow run number is used as the build number, so every upload is
unique. Uploading to TestFlight does not publish the app in the App Store.
