# OHSU COOL Lab Visual Acuity Test App

## Overview

This repository contains an iOS research application for near visual acuity testing. The application supports ETDRS-style letter recognition with speech input and Landolt C testing with gesture input. It uses ARKit face tracking to estimate viewing distance and applies optotype scaling from the measured or selected test distance.

The project is intended for controlled research and development use. It should not be described or used as a validated clinical diagnostic device without the appropriate validation, regulatory review, and study-specific approval.

Developers: Mahmoud Abdelmoneum, Maggie Bao, and Anderson Men  
Supervision: Dr. David Huang and Dr. Hiroshi Ishikawa  
Primary contacts: Mahmoud Abdelmoneum, mabdel03@mit.edu; Maggie Bao, mbao202@mit.edu

## Current Implementation

- Native iOS application implemented in Swift and UIKit.
- ETDRS-style test flow with WhisperKit-based speech recognition support.
- Landolt C test flow with swipe input.
- ARKit-based distance calibration and monitoring.
- Local test history using `UserDefaults`.
- Manual CSV export through the iOS share sheet.
- Optional training-data cloud upload through a separately configured upload endpoint.
- Legacy Dropbox upload code remains in the repository. The tracked Dropbox token is intentionally retained for this controlled repository configuration. Public redistribution requires a separate credential policy.

## Repository Layout

```text
VisualAcuityTest/
├── Distance Measure Test/
│   ├── App/                         App lifecycle
│   ├── Core/                        Shared data, subject, and upload managers
│   ├── Features/
│   │   ├── ETDRS/                   ETDRS test and WhisperKit support
│   │   ├── Home/                    Main menu and instructions
│   │   ├── LandoltC/                Landolt C test controller
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
- Camera permission for distance estimation.
- Microphone and speech-recognition permission for ETDRS speech input.
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

The primary participant workflow is:

1. Launch the application from the main menu.
2. Review test instructions.
3. Complete distance calibration.
4. Select the starting acuity level.
5. Complete the right-eye test, followed by the left-eye test when applicable.
6. Review LogMAR and Snellen-formatted results.
7. Export CSV data manually through the iOS share sheet if data sharing is required.

The ETDRS flow displays letter optotypes and records recognized spoken responses. The Landolt C flow displays rotated optotypes and records swipe-direction responses. Both flows record per-response metadata when progression data collection is active.

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

Recommended checks before research use:

1. Build the iOS target with Xcode or `xcodebuild`.
2. Confirm AR distance calibration on the intended device model.
3. Confirm speech-recognition behavior in the intended testing environment.
4. Confirm CSV export with a test participant record.
5. If cloud upload is enabled, confirm the endpoint is reachable from the device and that uploaded files are stored in the expected location.
6. Confirm `PrivacyInfo.xcprivacy` appears in the built application bundle.

## Repository Hygiene

Generated Xcode build products, per-user Xcode state, local Python environments, upload output, logs, and local credential files are intentionally ignored. Shared project configuration, source files, documentation, app assets, and Swift Package resolution metadata remain tracked.

## Contributing

Contributions should be reviewed for correctness, participant safety, data handling, and reproducibility. Proposed changes should include a concise description of behavioral impact and any verification performed.

## License and Use

This project was developed for research purposes at the OHSU COOL Lab. Contact the development team for licensing, deployment, and study-use permissions.
