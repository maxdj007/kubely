# Kubely — Release Runbook

Status of store-release preparation, what changed, and what is still outstanding.
Nothing in this file is secret; credentials live only in gitignored files.

**Last updated:** 2026-07-14

---

## Identity

| | |
|---|---|
| **Bundle ID / applicationId** | `com.falqor.kubely` (both platforms) |
| **Apple team** | Falqor — Team ID goes in `ios/Flutter/Local.xcconfig` (gitignored) |
| **App Store listing name** | **Kubelly** — "Kubely" was already reserved by another developer |
| **iOS device name** | **Kubelly** (`CFBundleDisplayName`) — matches the store listing, per Apple Guideline 2.3 |
| **Play listing / Android label** | **Kubely** — no conflict on Play, each store is internally consistent |
| **Version** | `1.0.0+1` (`pubspec.yaml`) |
| **iOS min deployment target** | **15.5** (forced by the QR scanner; drops iOS 13/14) |

> Android's `applicationId` was `com.kubely.kubely` and had already been pushed to a
> Play **beta** track. A Play Console listing's package name is permanent, so a **new
> Play Console app** must be created under `com.falqor.kubely` and beta testers
> re-invited. The old listing is orphaned.

## Toolchain

- Flutter **3.44.6** (upgraded from 3.35.3)
- Xcode **16.4** — ⚠️ **must be updated**, see below
- CocoaPods 1.16.2

---

## What was changed

### iOS / App Store compliance
- `ios/Runner/Info.plist` — added `NSCameraUsageDescription` (QR kubeconfig scan) and
  `NSLocalNetworkUsageDescription` (minikube/k3s/homelab clusters would otherwise fail
  silently on iOS 14+). Added `ITSAppUsesNonExemptEncryption = false` (TLS + Keychain
  only, standard exemption) so export compliance is not asked on every upload.
  `CFBundleName`/`CFBundleDisplayName` → `Kubelly`.
- `ios/Runner/PrivacyInfo.xcprivacy` — **new**; declares no tracking, no data collection,
  no required-reason API use. Registered in `project.pbxproj` (build file, file ref,
  Runner group, Copy Bundle Resources) so it actually ships in the `.app`.
- App icons regenerated **without an alpha channel** (`remove_alpha_ios` +
  `background_color_ios: "#0A0B0F"` in `pubspec.yaml`). All 21 icons previously had
  alpha, which is an automatic App Store rejection (ITMS-90717). Android's adaptive
  foreground deliberately keeps its transparency.
- `project.pbxproj` — legacy `iPhone Developer` signing identity → `Apple Development`.
- `ios/Flutter/{Debug,Release}.xcconfig` — optional `#include? "Local.xcconfig"` so the
  Team ID stays out of this open-source repo.
- `ios/Podfile` + `Podfile.lock` — now committed; platform pinned to iOS 15.5.

### Removed Google ML Kit (the big one)
`mobile_scanner` linked **Google ML Kit** into the iOS binary: ~15MB, a **Clearcut**
telemetry client, a pseudonymous-ID store, and live `firebaselogging.googleapis.com`
endpoints. Google's own privacy manifests declared it collects **Device ID + diagnostics**.
That would have forced a data-collection disclosure on both stores and contradicted
Kubely's "100% on-device, no backend" claim. A Dart `if (Platform.isIOS)` branch would
**not** have helped — `GeneratedPluginRegistrant.m` imports plugins unconditionally, so
the pod ships regardless of what runs.

Swapped to **`qr_code_scanner_plus`** (ZXing-based; AVFoundation on iOS, ZXing on Android,
zero Google dependencies, no extra Dart deps).

Verified in the built binaries:

| | Before | After |
|---|---|---|
| ML Kit symbols (iOS) | 1004 | **0** |
| Clearcut / Phenotype / pseudonymous-ID | present | **0** |
| Google logging endpoints | `firebaselogging`, `firelog` | **none** |
| Google frameworks embedded | 6 | **0** |
| iOS app size | 45.4MB | **25.7MB** |
| Android ML Kit / Play Services barcode | present | **0** (ZXing instead) |

Result: **"Data Not Collected" is now truthful on both stores.**

### Other
- `lucide_icons` (abandoned 2023) broke on Flutter 3.44 — it subclasses `IconData`, which
  is now `final`. Swapped to **`lucide_icons_flutter`**; all 46 icons present, same class
  name, import rewritten in 33 files.
- `add_cluster_screen.dart` — QR tab now degrades gracefully (message + Paste/File
  fallback) when there is no camera, permission is denied, or the camera fails to start.
  Added `pauseCamera()` on detect; `scannedDataStream` fires continuously otherwise.
- `android/app/build.gradle.kts` — release signing now reads `android/key.properties`
  (gitignored), falling back to the debug key when absent. **Release builds were
  previously signed with the Android debug key**, which Play rejects.
- `android/app/src/main/AndroidManifest.xml` — added `CAMERA` permission (the old scanner
  package supplied it; the new one does not) and `camera` as a non-required feature.
- `.gitignore` — kubeconfigs, certs, keystores, provisioning profiles, App Store Connect
  keys, `Local.xcconfig`, `key.properties`, `reviewer-kubeconfig.yaml`.
- `deploy/app-review/` — demo cluster manifests for App Review (see below).

---

## Outstanding

### Blocking iOS submission
1. **Update Xcode from 16.4.** Xcode 16.4 may be below Apple's current minimum SDK for
   App Store uploads. Install side-by-side so 16.4 remains a fallback:
   ```bash
   # download latest Xcode 26.x .xip from developer.apple.com/download/applications
   open ~/Downloads/Xcode_26.x.xip
   mv ~/Downloads/Xcode.app /Applications/Xcode-26.app
   sudo xcode-select -s /Applications/Xcode-26.app/Contents/Developer
   sudo xcodebuild -license accept
   sudo xcodebuild -runFirstLaunch
   xcodebuild -downloadPlatform iOS
   brew upgrade cocoapods
   cd ios && pod install --repo-update && cd ..
   flutter clean && flutter build ios --release --no-codesign
   ```
   Roll back with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
   (macOS is 15.6.1; if the newest Xcode requires macOS 26, macOS must be upgraded first.)

2. ~~**Apple Team ID.**~~ ✅ Done — `DEVELOPMENT_TEAM` set in the gitignored
   `ios/Flutter/Local.xcconfig`.

3. ~~**Register the App ID** `com.falqor.kubely`.~~ ✅ Done — registered under the Falqor
   team. Certificates and provisioning profiles are created automatically by Xcode.

4. ~~**Test the QR scanner on a physical iPhone.**~~ ✅ Done — scan → parse → context-select
   verified on device with `test-assets/kubeconfig-test-qr.png`. Three fixes were needed
   for `qr_code_scanner_plus` 2.2.0 on a real device:
   - Removed the deprecated `QRViewController.dispose()` call in
     `add_cluster_screen.dart` (the controller self-disposes on unmount).
   - `main.dart` now swallows the benign `CameraException(404, 'No barcode scanner found')`
     the plugin throws unawaited from its own teardown (`_disposeImpl → stopCamera`) when
     the QRView unmounts. Every other error still falls through.
   - `_probeCamera()` retries `getSystemFeatures()` (5×, ~2s) instead of treating a single
     early failure as fatal — the old code tore down the preview during the camera's init
     race, so it never started. Preview now stays mounted while probing.

   The **iOS Simulator has no camera** and will always fail — that is expected, not a bug.

5. **iOS screenshots.** The existing `screenshots/` are 1440×3120 (Android) and are
   unusable. Capture on an iOS simulator: **6.9" iPhone** and **13" iPad** (iPad is
   required because `TARGETED_DEVICE_FAMILY = "1,2"`). Also actually *check* the iPad
   layout — the log viewer and YAML editor are the likely casualties.

### Blocking Play production
6. **Generate the upload keystore** (keep it OUTSIDE the repo, and back it up):
   ```bash
   keytool -genkey -v -keystore ~/kubely-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   cp android/key.properties.example android/key.properties   # then fill it in
   flutter build appbundle --release
   ```
7. **New Play Console listing** under `com.falqor.kubely`; re-invite beta testers.

### Store listing
8. ~~Privacy Policy URL.~~ ✅ Done — `PRIVACY.md` in the repo root is Kubelly-specific and
   states no data is collected. Use `https://github.com/maxdj007/kubely/blob/main/PRIVACY.md`
   (must be committed/pushed first). Full listing copy is in `APP_STORE_LISTING.md`.
9. App Privacy → **Data Not Collected**. Category: Developer Tools. Age rating: 4+.
10. App Review Notes — point the reviewer at **"Try demo cluster"**; see below. No demo
    kubeconfig or live cluster is needed.

### Optional follow-up
- Enable R8 (`isMinifyEnabled`) on Android to shrink the bundle. Deliberately left off:
  R8 can strip ZXing classes resolved by reflection, and this needs device testing.

---

## App Review: the in-app demo cluster

A reviewer **cannot test a Kubernetes client without a cluster** — the single biggest
rejection risk (Guideline 2.1, App Completeness). This is solved **in the app**: no
infrastructure, no credentials handed to Apple, no token that can expire mid-review.

**"Try demo cluster"** on the Add Cluster screen connects a cluster served entirely from
on-device fixtures (`lib/data/services/demo_cluster.dart`). It swaps Dio's transport for
an adapter that answers Kubernetes API calls from canned data, so *every* screen works
unchanged — pods, deployments, nodes, storage, config, Helm, pod detail, and live log
streaming. A `DEMO` badge sits in the app-bar cluster pill so sample data is never
mistaken for a real cluster.

It is deliberately a **visible feature**, not a debug flag: Guideline 2.3.1 prohibits
hidden or undocumented functionality, so a reviewer-only switch would itself be grounds
for rejection. It also genuinely helps users evaluate Kubelly with no cluster to hand.

`test/demo_cluster_test.dart` asserts every endpoint the app calls returns data.

**App Review Notes** then only need:

> Kubelly is a client for Kubernetes. To evaluate it without a cluster, tap
> **"Try demo cluster"** on the Add Cluster screen — this loads sample data on-device and
> every screen becomes browsable, including live log streaming. No account or sign-in is
> required.
>
> The "QR" tab scans a kubeconfig from a QR code and requires camera permission. The
> camera is used only to read a QR code; no image data leaves the device. If camera
> access is declined, the Paste and File tabs still work.

Set **Sign-in required: No**.

### Optional: a real demo cluster

`deploy/app-review/` still contains manifests for a throwaway *real* cluster
(ServiceAccount, read-only ClusterRole derived from Kubely's actual API calls, and a
kubeconfig generator). It is **no longer needed for App Review** — the in-app demo
supersedes it — but it remains useful for end-to-end testing against a live API server.
Note the built-in `view` ClusterRole is insufficient: it grants no access to nodes,
secrets or metrics, so Nodes and Helm would 403.

---

## Verify before submitting

```bash
flutter analyze          # expect 0 errors
flutter test             # expect 23/23
flutter build ios --release --no-codesign
flutter build appbundle --release
```

Then in Xcode: **Product → Archive** (target "Any iOS Device"), and run **Validate**
before Distribute — validation catches icon/plist rejections for free.

Every subsequent upload needs the build number bumped (`1.0.0+2`, …) or App Store
Connect rejects it as a duplicate.
