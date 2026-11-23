# Google Play production checklist

## Prepared

- Application ID: `game.workwithafridi.flutris`
- Release signing configuration and upload certificate generated locally.
- Signed Android App Bundle and signed APK built for version `1.0.0` (version code `1`).
- The production track now has a saved draft release named `Flutris 1.0.0 (1)` with the signed AAB and English (UK) release notes. It has **0 countries/regions** selected and is not eligible to roll out yet.
- Store listing saved to Play Console: title, short and full descriptions, category `Game → Puzzle`, tag `Block puzzle`, support contact, icon, feature graphic, and two phone screenshots.
- Privacy policy created in Google Drive, shared as **Anyone with the link — Viewer**, and included in the app as an in-app screen.
- Saved Console declarations: no ads, no restricted sign-in, no advertising ID, no government features, no financial features, and no health features.
- Data Safety answers state no required user data is collected or shared; they are saved as a draft, pending completion of Target audience and content.
- App category/contact details and the default store listing are saved.

## Release artifacts

- AAB: `build/app/outputs/bundle/release/app-release.aab`
- AAB SHA-256: `f81c4c05f0d86b048baf5702d7e13752585a23b1629f8f990767cf281a3150c6`
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- APK SHA-256: `60f95676fddae6139dba47900e9a1fe4d149754a746a932dfbc3dc1225a44dd4`
- Upload certificate: `flutris-upload-certificate.pem` (SHA-256 `65:36:24:0F:1A:87:D4:20:09:F6:EA:B4:94:CE:E2:F0:32:3C:4B:A0:C5:91:05:34:3D:86:01:64:22:F6:92:D7`)
- Keystore and `android/key.properties` stay local and are ignored by Git. Keep an offline backup of both; the PEM is public and safe to share.

## Complete in Play Console before production submission

- Complete the IARC content-rating questionnaire. Play Console states that completing it accepts IARC's terms of service; review and accept those terms as the account owner.
- Complete Target audience and content once the content rating is available. Under-13 age selections are currently disabled in Console until the rating is set; confirm the intended audience rather than treating 13+ as final.
- Finish and submit the Data Safety declaration after the target-audience form is complete.
- Choose countries/regions for the production track. Console currently reports an error because none are selected.
- Set the app's free or paid price and review availability. Pricing and regions have intentionally not been chosen.
- Console currently shows that releases are signed by Google Play. Review the app-signing settings before publishing; the first open-track publication fixes the app-signing key choice. The generated certificate is the upload certificate, not the distributed app-signing key.
- Check whether the account requires a testing track or additional verification; review the generated pre-launch report and policy status.
- Submit the release for review only after the account owner has completed the items above.

The AAB is uploaded to a saved production-track draft. It has not been submitted for review or rolled out.
