# COOL Lab Near Distance Visual Acuity Test App

## About
This Github repository houses the code underlying our near distance visual acuity test app. Its contents were developed by Mahmoud Abdelmoneum, Maggie Bao, and Anderson Men at the COOL Lab with the support of Dr. David Huang and Dr. Hiroshi Ishikawa. This ReadME is intended to serve as high level documentation for the different components of our codebase. Please see the individual files for the thoroughly annotated code. Please reach out to Mahmoud Abdelmoneum (mabdel03@mit.edu) if you have any questions or concerns regarding the code. All development thus far has been in Swift, but we as we gear up to release the app on the appstore we will build a RESTful API using Django or Flaks to handle logins as well as a database system for storing user information using a MongoDB.

## Codebase Overview
The .swift files housing the majority of the app's code can be found in the /Distance Measure Test directory, but here we will list out the directories of this project and what they correspond to.

### /Distance Measure Test.xcodeproj
Xcode project file that stores metadata and configuration settings for your project. It contains information about how Xcode should build and manage the app, such as:
References to your Swift files, asset catalogs, and other resources.

1. Build settings (e.g., compiler flags, code signing configurations).
2. Schemes for running the app or tests.

This is the file you double-click to open your project in Xcode if you don’t use a workspace.

### /Distance Measure Test.xcworkspace
Workspace file that allows you to manage multiple projects or dependencies in a single Xcode window; If you used CocoaPods, Swift Package Manager, or other external dependencies, this file was created to manage those integrations.

### /Distance Measure Test
Directory containing all of the app's .swift files as well as related UI Elements. Will cover this section more thoroughly in the [/Distance Measure Test Deep Dive](#distance-measure-test-deep-dive)
 section

### /optician-sans-font
Contains custom font files (e.g., .ttf or .otf files) for the app. Specifically, contains the "Optician Sans" font for our Tumbling E test.

### /Distance-Measure-Test-Info.plist
Property list file that stores configuration information for the app.

Information in the Info.plist includes:
1. App name, bundle identifier, and version number.
2. Permissions requested by the app, such as access to the camera or location services.
3. Configuration for app behavior, like supported device orientations or status bar appearance.

## Distance Measure Test Deep Dive
XX
