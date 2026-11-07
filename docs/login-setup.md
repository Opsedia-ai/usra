# Login setup: Google and Apple

Usra's optional account signs in with Google or Apple, using the phone's own sign-in sheet. There's no SMS and no password. This page lists what the founder has to do. Until it's done the app has no account entry at all and works fully without one.

**No real family signs in until an Egyptian lawyer has answered the questions in step 6.** The beta runs without login unless that answer arrives first.

## What it costs

| Step | Cost |
| --- | --- |
| Google Cloud project and OAuth client IDs | Free. No billing account needed |
| Sign in with Apple and its key | Included in the Apple Developer Program, which the App Store already needs ($99 a year, fixed, not per user) |
| Supabase Pro | About $25 a month, approved by the founder, from the moment real member numbers exist (they can't be recreated, and Free has no backups). Until then nothing runs. Includes Auth for the users we expect |
| Google Play account, needed for its signing fingerprint | $25 once, already planned |
| Calls to Google and Apple when someone signs in or deletes their account | Free |

Nothing here charges per user at the numbers we expect. See the cost check in the pull request that added this page.

## What you'll end up with

Keep these in a password manager. Only the Apple key is a secret, but keep real values out of this public repo anyway.

| Value | Example | Goes in |
| --- | --- | --- |
| Google web client ID | `123-abc.apps.googleusercontent.com` | App build, Supabase |
| Google iOS client ID | `123-def.apps.googleusercontent.com` | App build, Supabase |
| Google iOS URL scheme | `com.googleusercontent.apps.123-def` | iOS build |
| Apple Team ID | `ABCDE12345` | Supabase secrets |
| Apple Key ID | `FGHIJ67890` | Supabase secrets |
| Apple key file (`.p8`) | Secret | Supabase secrets only |

## 1. Google Cloud (free)

Go to <https://console.cloud.google.com> and create a project called `Usra`.

1. Open **Google Auth Platform → Branding**. Enter the app name, a support email, and the privacy policy and home page links.
2. Open **Audience**, choose **External**, then **Publish app**. While the app is in testing, only listed test users can sign in. Usra asks for basic scopes only, so publishing needs no Google review.
3. Open **Data Access** and add `openid`, `userinfo.email` and `userinfo.profile`. Add nothing else: other scopes can trigger a review.
4. Open **Clients** and create these:
   - **Web application**, named `Usra web`. Leave the redirect URIs empty. Native sign-in doesn't use this client's secret, so don't copy it anywhere.
   - **iOS**, with bundle ID `com.opsedia.usra` and your Apple Team ID. Copy the client ID and the **iOS URL scheme** it shows.
   - **Android**, with package `com.opsedia.usra` and a SHA-1 fingerprint. Create one Android client for each fingerprint:
     - Google Play's app signing key, from **Play Console → Test and release → Setup → App signing**. This is the one real users need.
     - Your upload key, for builds you install directly.
     - Your debug key, for local testing. You can get it with the command below.

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

The Android client ID doesn't go in the app. Google recognises the app by its package name and fingerprint.

## 2. Apple (included in the developer account)

Go to <https://developer.apple.com/account/resources>.

1. Under **Identifiers**, open the App ID `com.opsedia.usra` and turn on **Sign in with Apple**, as a primary App ID. Leave the server-to-server notification URL empty. Xcode picks up the change the next time it makes a signing profile.
2. Under **Keys**, create a key, turn on **Sign in with Apple**, and choose the same App ID. Download the `.p8` file. Apple lets you download it only once. Note the Key ID.
3. Find your Team ID under **Membership details**.

**You don't need a Services ID or Supabase's Apple secret.** Those are only for Apple's web flow. Usra uses the native sheet on iOS, and doesn't offer Apple on Android.

The key has one job: when someone deletes their account, the `delete-account` function uses it to revoke Apple's tokens, as Apple requires. That function makes a fresh short-lived secret from the key each time, so there's nothing to renew every six months.

**Every signed iOS build needs this capability,** including builds with accounts off, because `Runner.entitlements` asks for it in all of them. Turn it on before the first signed build, even if accounts come later. Free Apple accounts can't use it, so build with the Opsedia team. Simulator builds and CI's unsigned builds aren't affected.

## 3. Supabase (Pro, about $25 a month)

Create the project in **Frankfurt**. Supabase has no region in the Middle East, and the founder's backend research recommends Frankfurt over the other nearby regions. Confirm this with the lawyer (see step 6), because moving a project later is work.

In the project dashboard:

1. **Authentication → Sign In / Providers → Google**: turn it on. In **Client IDs**, enter the web client ID first, then the iOS one, separated by a comma. Leave **Skip nonce check** off. If the dashboard insists on a client secret, use the web client's, though Usra doesn't use it.
2. **Apple**: turn it on. In **Client IDs**, enter `com.opsedia.usra`. Leave the secret key empty.
3. **Phone**: turn it off. **Email**: turn it off. Google and Apple are the only ways in.

Then deploy from `supabase/`, with the values from step 2:

```bash
supabase db push
```

```bash
supabase functions deploy delete-account
```

```bash
supabase secrets set APPLE_TEAM_ID=ABCDE12345 APPLE_KEY_ID=FGHIJ67890 APPLE_PRIVATE_KEY="$(cat AuthKey_FGHIJ67890.p8)"
```

Without these three secrets, accounts still delete, but Apple's tokens stay until the person removes Usra from their Apple ID. That wouldn't meet Apple's rule, so set them before you submit to the App Store.

For a local stack, `config.toml` reads the client IDs from `supabase/.env`. See `supabase/.env.example`.

## 4. Build the app

Each button appears only when its values are set. If none are, the account screen says sign-in isn't available.

Android:

```bash
flutter build appbundle --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=GOOGLE_WEB_CLIENT_ID=<web client ID>
```

iOS needs the URL scheme as well. Create `app/ios/Flutter/Login.local.xcconfig`, which git ignores, with this line:

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.123-def
```

Then build:

```bash
flutter build ipa --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=GOOGLE_WEB_CLIENT_ID=<web client ID> --dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client ID> --dart-define=SIGN_IN_WITH_APPLE=true
```

Two rules for iOS builds:

- **Set the URL scheme whenever you set `GOOGLE_IOS_CLIENT_ID`.** Without it, Google's iOS library stops the app when someone taps the button.
- **Set `SIGN_IN_WITH_APPLE=true` whenever you offer Google.** App Store guideline 4.8 requires Apple beside Google, so without it the app hides Google on iOS.

Never put the service-role key or the Apple key in an app build.

## 5. Check it before release

This code has only been tested with fake sign-in. No real Google or Apple client existed when it was written, so try each of these on real phones:

- [ ] iPhone: sign in with Apple, including **Hide My Email**.
- [ ] iPhone: sign in with Google.
- [ ] Android from Google Play: sign in with Google. This proves the Play signing fingerprint.
- [ ] Close each sheet without signing in: nothing happens and no error shows.
- [ ] Sign out, then sign in again: Google asks which account.
- [ ] Delete an Apple account: Apple's sheet appears, and afterwards Usra is gone from **Settings → Apple ID → Sign in with Apple**.
- [ ] Turn on the app lock with **Right away**, then sign in: the app doesn't lock behind the sheet.

| What you see | Likely cause |
| --- | --- |
| Android: Google's sheet fails straight away, or error 10 | The fingerprint or package name doesn't match an Android client |
| iPhone: the app closes when you tap Google | The URL scheme isn't set |
| "Something went wrong" after choosing an account | Supabase's **Client IDs** don't include the client ID, or the provider is off |
| Supabase's logs mention a nonce or `at_hash` | The app and Google disagree about the token. Tell the developer. Don't turn on **Skip nonce check** without checking first |
| Only test users can sign in with Google | The app is still in testing: see step 1.2 |

## 6. Before shipping a build with accounts

Today's store listings, policy and legal text describe an app with no accounts. All of this has to change in the same release that turns accounts on.

**Legal, first.** An account row is personal data on a server outside Egypt. Before accounts go live, have an Egyptian lawyer answer these questions:

- [ ] Is a developer whose records stay on the phone a controller or a holder of this data?
- [ ] Does a table holding only login details need a licence, and a cross-border licence?
- [ ] Does it count as sensitive data, given that it shows a named person uses a family health app?
- [ ] Can Opsedia get any licence that's needed in time?
- [ ] Does tapping a sign-in button count as "explicit written" consent? The app currently treats signing in as agreeing, with a notice and a link on the account screen.
- [ ] Is Frankfurt the right region for the Supabase project?

No real family signs in until these are answered. Take separate advice before opening accounts in Saudi Arabia or Jordan. UAE is off the list for launch.

**Privacy policy** (`docs/legal/privacy-policy.en.md` and `.ar.md`):

- [ ] Move the account bullet out of section 10, "Later optional cloud features", into the main policy, and write it as what happens now, not what would happen.
- [ ] Rewrite the summary at the top, which says "we have no account for you".
- [ ] Update sections 4, 6 and 7 so they cover the account, what leaves the phone, and how to delete it.
- [ ] Check that the policy matches what the account screen says, and publish it before the release.

**Terms** (`docs/legal/terms-of-use.en.md` and `.ar.md`):

- [ ] Move the accounts bullet out of the "planned" section.

**Store listings**, which already have the text to switch to:

- [ ] `docs/store/app-store.md`: App Review notes.
- [ ] `docs/store/google-play.md`: the "No account, no sign-in" line in Arabic and English.

**Store forms** (`docs/store/data-safety.md`):

- [ ] Google Play Data safety and Apple App Privacy: use the answers under "When accounts, the paywall and later features ship".
- [ ] Play's deletion question, and its required web page for deletion requests, which doesn't exist yet.
- [ ] Play's app access declaration and Apple's guideline 5.1.1 row.

**App and backend:**

- [ ] Add the `APPLE_*` secrets (step 3).
- [ ] Run the checks in step 5.
- [ ] With `SUPABASE_URL` set, check that More > About & privacy says an account is optional, in both languages.
- [ ] Check that everything still works with no account until the paywall. Login must stay optional until then.

## Good to know

- **One email, one account.** Google and Apple sign-ins with the same verified email become one Usra account. Someone who chooses **Hide My Email** with Apple gets a relay address, so that becomes a separate account.
- **Recovering an account is Google's or Apple's job.** We have no other way to sign someone in. Records stay on the phone either way.
- **Removing Usra from a Google account:** deleting a Usra account doesn't do this for them. They can do it at <https://myaccount.google.com/connections>.
- **Why Pro:** a free Supabase project pauses after a week without activity, and it has no automatic backups. An account can be recreated by signing in again, but a member number can't, so real member numbers go on Pro from the start. Health records aren't stored there.
