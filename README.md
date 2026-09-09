# OHSU COOL Lab Visual Acuity Test App

## Overview

This repository contains the test-ready build of the OHSU COOL Lab iOS near visual acuity application.

**ETDRS letter recognition with speech input is the primary test.** It is the default pipeline, the flow intended for participant sessions, and the configuration this branch is prepared to run.

**Landolt C with swipe input is an optional alternate test.** It remains fully implemented and selectable in Settings for studies or participants where a non-verbal, orientation-based optotype is preferable, but it is not the default path.

Both flows share the same ARKit face-tracking distance estimation, optotype scaling from the measured or selected test distance, results presentation, and CSV export.

"Test-ready" here means the ETDRS pipeline is feature-complete and ready to run participant testing sessions on supported hardware, subject to the device-level checks in the [Verification Checklist](#verification-checklist). It does not mean the application is a validated clinical diagnostic device. It should not be described or used as one without the appropriate validation, regulatory review, and study-specific approval.

Developers: Mahmoud Abdelmoneum, Maggie Bao, and Anderson Men  
Supervision: Dr. David Huang and Dr. Hiroshi Ishikawa  
Primary contacts: Mahmoud Abdelmoneum, mabdel03@mit.edu; Maggie Bao, mbao202@mit.edu

## Current Implementation

- Native iOS application implemented in Swift and UIKit.
- ETDRS-style test flow with WhisperKit-based speech recognition. Default pipeline and the intended flow for participant sessions.
- Landolt C test flow with swipe input. Optional alternate pipeline, selected in Settings.
- ARKit-based distance calibration and monitoring, shared by both flows.
- Local test history using `UserDefaults`.
- Manual CSV export through the iOS share sheet.
- Optional training-data cloud upload through a separately configured upload endpoint.
- Legacy Dropbox upload code remains in the repository. The tracked Dropbox token is intentionally retained for this controlled repository configuration. Public redistribution requires a separate credential policy.

## Test Modes

The application ships with two optotype pipelines. The active one is chosen under **Settings → Test Type**, which presents a `Landolt C` / `ETDRS` segmented control.

| | ETDRS (default) | Landolt C (optional) |
|---|---|---|
| Optotype | 11-letter set (`C D F H K N P R X J Z`) rendered in the Sloan typeface | Landolt C at four orientations (0°, 90°, 180°, 270°) |
| Participant response | Spoken letter, recognized by WhisperKit | Swipe in the direction the C points |
| Requires microphone | Yes | No |
| Intended use | Standard participant sessions | Non-verbal participants, or protocols calling for an orientation task |

The selection is persisted in `UserDefaults` under the `etdrs_test_enabled` key, defined by `TestTypePreferences` in [MainMenuViewController.swift](Distance%20Measure%20Test/Features/Home/MainMenuViewController.swift). The registered default is `true`, so a fresh install starts in ETDRS mode. The choice changes only the optotype presentation and response capture; distance calibration, acuity selection, scoring, results, and export are identical in both modes.

## Repository Layout

```text
VisualAcuityTest/
├── Distance Measure Test/
│   ├── App/                         App lifecycle
│   ├── Core/                        Shared data, subject, and upload managers
│   ├── Features/
│   │   ├── ETDRS/                   Primary ETDRS test and WhisperKit support
│   │   ├── Home/                    Main menu, instructions, test-type preference
│   │   ├── LandoltC/                Optional Landolt C test controller
│   │   ├── Results/                 Results, history, and data collection views
│   │   ├── Settings/                User-facing preferences
│   │   └── TestSetup/               Distance guidance and acuity selection
│   ├── Shared/                      UI styling, extensions, and reusable views
│   ├── Assets.xcassets/             App images, color assets, and icons
│   ├── Base.lproj/                  Storyboards
│   └── art.scnassets/               SceneKit resources
├── simple-cloud-server/             Optional CSV upload services
├── optician-sans-font/              Optotype font resources
├── Distance Measure Test.xcodeproj/ Xcode project
├── Distance Measure Test.xcworkspace/
├── Distance-Measure-Test-Info.plist
└── PrivacyInfo.xcprivacy
```

## Requirements

- macOS 14 or later with Xcode 16 or later.
- iOS device with ARKit face tracking support for full distance-tracking behavior.
- Camera permission for distance estimation, in both test modes.
- Microphone and speech-recognition permission for ETDRS speech input. Not required when running the optional Landolt C mode, which takes swipe input only.
- Internet access on the Mac while Xcode resolves Swift Package Manager dependencies.
- Internet access on the iOS device while WhisperKit downloads its model on first launch.

Simulator builds are useful for compile checks and some user-interface review. A physical device is required for AR face tracking and complete test execution.

## Build and Run

1. Open the Xcode project:

   ```bash
   open "Distance Measure Test.xcodeproj"
   ```

   Do not open the top-level `Distance Measure Test.xcworkspace`; it does not contain the application project.

2. Allow Xcode to resolve the Swift Package Manager dependencies automatically.

3. Select the `Distance Measure Test` scheme.

4. Configure signing for the local development team and target device.

5. Build and run on a compatible iOS device.

### WhisperKit setup

No manual WhisperKit setup is required. Xcode resolves the pinned WhisperKit package automatically; collaborators do not need to install a model, CocoaPods, Python, or Homebrew.

The repository intentionally contains an empty `Distance Measure Test/Resources/WhisperModels` directory. When the app does not find a bundled model there, it automatically downloads the device-recommended WhisperKit model and tokenizer, then prewarms and loads them. Keep the iOS device online during the first launch and allow the loading screen to reach `WhisperKit ready.` Downloaded files are cached for subsequent launches.

Developers can still test a bundled model by placing its complete folder under `Resources/WhisperModels`. Local model files remain ignored by Git so large generated artifacts are not committed accidentally.

Command-line build check:

```bash
xcodebuild \
  -scheme "Distance Measure Test" \
  -project "Distance Measure Test.xcodeproj" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/VisualAcuityTestAuditDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Application Workflow

The primary participant workflow runs the ETDRS test, which is active by default and requires no configuration:

1. Launch the application from the main menu.
2. Review test instructions.
3. Complete distance calibration.
4. Select the starting acuity level.
5. Complete the right-eye test, followed by the left-eye test when applicable.
6. Review LogMAR and Snellen-formatted results.
7. Export CSV data manually through the iOS share sheet if data sharing is required.

In this default mode the app displays letter optotypes and records recognized spoken responses through WhisperKit.

### Spoken responses during the ETDRS test

Each ETDRS trial is scored from what WhisperKit hears after the microphone is armed for that letter:

- A recognized letter scores the trial and the test moves on.
- Saying "skip" (or a common Whisper mis-hearing of it) scores the trial incorrect with `User_Response = skip` and the test moves on. The on-screen instruction tells the participant that saying "skip" is allowed. A skip word spoken together with a letter ("okay skip", "C skip") is neither a skip nor a letter, and the microphone keeps listening.
- If 5 seconds pass with no usable speech from an armed microphone, the trial scores incorrect with `User_Response = no input registered` and the test moves on. The window is timed from when listening actually starts, not from when the letter appears. An utterance still in progress at the deadline is given up to about 1 second to finish. Text that WhisperKit produces from a window in which no sound rose above the silence threshold (a muted or disconnected microphone) is treated as silence, not as an answer.
- Filler or unclear speech is not a miss. The same letter is retried up to twice before the no-input miss is scored. The first retry is announced with a spoken "Try again." when **Settings → Audio Instructions** is enabled; the second retry is silent.
- Three consecutive no-input letters pause the test and the Pause button reads `Resume`. The test stays paused until someone taps Resume.

For a no-input row, `Response_Time_MS` is measured from when the letter appeared, so it includes the inter-letter gap, any spoken prompt, any retries, and the 5-second window. The `skip` and `no input registered` strings are identical to the ones Myotect writes, so `User_Response` from both apps can be analyzed the same way. `Response_Time_MS` is not directly comparable for those rows: Myotect times from when its microphone arms, Visinear from when the letter appeared.

To run the optional Landolt C test instead, switch **Settings → Test Type** to `Landolt C` before starting a session. The surrounding workflow is unchanged: the app then displays rotated Landolt rings and records swipe-direction responses in place of step 5's spoken input. Both flows record per-response metadata when progression data collection is active, and both write the same CSV schema.

## Data Collection and Export

The application records structured test response data for research review. Typical exported fields include:

- Participant name, when provided during export.
- Timestamp.
- Eye tested.
- Test type.
- Acuity level.
- Displayed optotype or orientation.
- Estimated viewing distance in centimeters.
- Response time in milliseconds.
- Participant response.
  - For ETDRS trials, `User_Response` is a letter, `skip`, or `no input registered`.
- Correctness indicator.
- Trial number.
- Session identifier.

By default, export is manual through `UIActivityViewController`. The app does not attempt to upload to `localhost` by default. To enable optional cloud upload for training data collection, set the `CloudUploadURL` value in `Distance-Measure-Test-Info.plist` or the target build settings to a reachable HTTPS endpoint that implements the server contract described below.

The optional cloud endpoint accepts:

```json
{
  "filename": "example.csv",
  "content": "Letter_Displayed,Transcribed_Text,Mapped_Result\nC,see,C\n",
  "timestamp": "2026-07-08T00:00:00Z",
  "source": "visual_acuity_ios_app"
}
```

The local Dropbox manager remains present for legacy workflows. The token in `DropboxUploadManager.swift` is intentionally tracked for this controlled repository state.

## Optional Cloud Server

The `simple-cloud-server` directory contains optional Flask-based services for CSV upload workflows:

- `app.py` stores uploaded CSV files locally and can email attachments when email is explicitly enabled.
- `google_drive_uploader.py` stores uploaded CSV files locally and uploads them to a configured Google Drive folder.

These services are not required for ordinary manual export from the iOS app. See [simple-cloud-server/README.md](simple-cloud-server/README.md) for configuration and tests.

## Privacy and Data Handling

The application requests camera and microphone permissions for test execution. The repository includes `PrivacyInfo.xcprivacy`, and the app target should include it as a bundled resource. Exported CSV files may contain participant names if entered by the operator. Study teams should apply the consent, de-identification, access-control, and retention policies required by the relevant protocol.

## Verification Checklist

The application is test-ready at the code level, but each deployment should confirm the following on the actual study hardware before participant sessions:

1. Build the iOS target with Xcode or `xcodebuild`.
2. Run the unit test suite in `Distance Measure TestTests` (optotype sizing, calibration and distance, ETDRS progression engine, persistence).
3. Confirm AR distance calibration on the intended device model.
4. Confirm **Settings → Test Type** reads `ETDRS` on a fresh install, and that the intended mode is selected for the session.
5. Confirm WhisperKit reaches `WhisperKit ready.` and speech recognition behaves acceptably in the intended testing environment, including its ambient noise level.
6. If the optional Landolt C mode will be used, confirm swipe capture and orientation scoring separately.
7. Confirm CSV export with a test participant record.
8. If cloud upload is enabled, confirm the endpoint is reachable from the device and that uploaded files are stored in the expected location.
9. Confirm `PrivacyInfo.xcprivacy` appears in the built application bundle.

## Repository Hygiene

Generated Xcode build products, per-user Xcode state, local Python environments, upload output, logs, and local credential files are intentionally ignored. Shared project configuration, source files, documentation, app assets, and Swift Package resolution metadata remain tracked.

## Contributing

Contributions should be reviewed for correctness, participant safety, data handling, and reproducibility. Proposed changes should include a concise description of behavioral impact and any verification performed.

## License and Use

This project was developed for research purposes at the OHSU COOL Lab. Contact the development team for licensing, deployment, and study-use permissions.
