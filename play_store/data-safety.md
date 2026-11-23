# Google Play declarations — Flutris

Draft answers based on the current source, Android manifest, and locked dependencies. Recheck this form whenever dependencies or data practices change.

## Data safety

- Does the app collect or share required user data types? **No.** The Android manifest does not request internet access and app code does not send data to a server.
- Is data encrypted in transit? **Not applicable** because Flutris does not transmit user data.
- Can users request data deletion? **Not applicable.** There is no account or remote user data. Local scores are deleted when the user uninstalls the app or clears its app data.
- Data processed locally: per-mode best scores are saved in Android app preferences by `shared_preferences`; no score leaves the device.
- SDK note: Flutter and Flame render/run the game; `flame_audio` plays bundled sounds; `shared_preferences` stores scores locally. No ads, analytics, attribution, or tracking SDKs are included.

## App content

- Ads: **No.**
- App access: **No restrictions or sign-in.**
- Target audience: **not selected**. Play Console currently disables under-13 selections until the content-rating questionnaire is complete. Confirm the intended audience before submitting.
- Content rating questionnaire: puzzle game, no violence, sexual content, profanity, drugs, gambling, user-generated content, or online social features.
- Government app: **No.**
- Financial features: **None.**
- Health features: **None.**
- News, COVID-19, or user-generated-content declarations: **None.**

These are draft declarations for the Play Console, not a substitute for the developer's final review of the exact submitted binary and every SDK's current behavior.
