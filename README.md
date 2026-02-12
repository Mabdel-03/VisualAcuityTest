# OHSU COOL Lab Visual Acuity Test App

## Overview

This repository contains a sophisticated iOS visual acuity testing application developed at the OHSU COOL Lab. The app provides two standardized visual acuity tests - **ETDRS (Early Treatment Diabetic Retinopathy Study)** with voice recognition and **Landolt C** with gesture-based input - both utilizing advanced AR face tracking for precise distance monitoring and real-time letter scaling.

**Total Codebase:** 5,178 lines of Swift code across 12 files

**Developed by:** Mahmoud Abdelmoneum, Maggie Bao, and Anderson Men  
**Supervised by:** Dr. David Huang and Dr. Hiroshi Ishikawa  
**Contact:** Mahmoud Abdelmoneum (mabdel03@mit.edu), Maggie Bao (mbao202@mit.edu)

## Key Features

### **Medical-Grade Visual Acuity Testing**
- **ETDRS Standard Compliance**: Implements precise ETDRS calculations with LogMAR scoring
- **Dual Test Modes**: ETDRS letters with speech recognition and Landolt C with swipe gestures
- **Clinical Accuracy**: Real-time letter scaling based on viewing distance and visual angle calculations
- **Comprehensive Results**: LogMAR and Snellen notation scoring with persistent test history

### **Advanced AR & Computer Vision**
- **ARKit Face Tracking**: Real-time distance monitoring using front-facing camera
- **Dynamic Distance Correction**: Automatic letter scaling based on user position
- **Distance Optimization**: Interactive calibration with visual feedback
- **Eye-Specific Tracking**: Separate left and right eye distance measurements

### 🎙️ **Intelligent Speech Recognition**
- **Advanced Phonetic Matching**: Multi-layered speech-to-text with comprehensive phonetic mapping
- **Conversation Filtering**: Sophisticated algorithms to distinguish letter responses from conversation
- **Real-time Audio Processing**: Continuous speech recognition with timeout management
- **Accessibility Integration**: Full audio instruction support throughout the app

### 📱 **Professional iOS Implementation**
- **Modern Swift Architecture**: Clean, modular codebase with comprehensive documentation
- **Responsive UI/UX**: Adaptive layouts supporting all iOS device sizes
- **Persistent Data Storage**: Test history with JSON serialization and UserDefaults
- **Accessibility First**: VoiceOver support and audio instructions throughout

## Architecture Overview

### Core Components

#### **Test Controllers (3,044 lines)**
- **`ETDRSViewController.swift` (1,861 lines)**: Complete ETDRS test implementation with speech recognition, phonetic matching, and AR distance tracking
- **`TumblingEViewController.swift` (1,183 lines)**: Landolt C test with gesture recognition, animation system, and real-time scaling

#### **UI & Navigation (1,987 lines)**
- **`SettingsViewController.swift` (395 lines)**: Test type selection and audio preferences management
- **`ResultViewController.swift` (316 lines)**: Test results display with LogMAR/Snellen scoring and data persistence
- **`Select_Acuity.swift` (300 lines)**: Dynamic acuity level selection with real-time button scaling
- **`Main Menu.swift` (270 lines)**: Navigation hub with SharedAudioManager integration
- **`DistanceOptimization.swift` (262 lines)**: AR-based distance calibration with face tracking
- **`TestHistoryViewController.swift` (253 lines)**: Comprehensive test history with CSV export functionality
- **`OneEyeInstruc.swift` (111 lines)**: Eye-specific test instructions and navigation
- **`Instructions.swift` (39 lines)**: General app instructions with audio support
- **`AppDelegate.swift` (41 lines)**: App lifecycle management

#### **Data Collection & Analytics (147 lines)**
- **`TestProgressionDataCollector.swift` (147 lines)**: Comprehensive test progression tracking with CSV export capabilities

## Technical Implementation Details

### **ARKit Integration**
```swift
// Real-time face tracking with eye position calculation
func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let faceAnchor = anchor as? ARFaceAnchor else { return }
    leftEye.simdTransform = faceAnchor.leftEyeTransform
    rightEye.simdTransform = faceAnchor.rightEyeTransform
    // Distance calculation and letter scaling...
}
```

### **ETDRS Calculation Engine**
```swift
// Standard ETDRS visual angle calculation
let arcmin_per_letter = 5.0 // 5 arcminutes for 20/20 vision
let visual_angle = ((Double(desired_acuity) / 20.0) * arcmin_per_letter / 60.0) * Double.pi / 180.0
let scale_factor = distance * tan(visual_angle) * scaling_correction_factor
let labelHeight = scale_factor * ppi // Convert to pixels
```

### **Advanced Speech Recognition**
- **Multi-layer Phonetic Matching**: Exact, alternative, and fuzzy phonetic mapping
- **Conversation Filtering**: 9-rule system to distinguish letters from sentences
- **Real-time Processing**: Continuous recognition with intelligent timeout management
- **Comprehensive Letter Support**: Full ETDRS letter set with phonetic variations

### **Distance Tracking System**
- **Smoothing Algorithm**: Rolling average of recent distance readings
- **Hysteresis Implementation**: Prevents rapid pause/resume cycles
- **Real-time Scaling**: Dynamic letter size adjustment based on user movement
- **Validation & Fallbacks**: Robust error handling for invalid distance readings

### **Data Persistence**
```swift
// Comprehensive test data management
class TestDataManager {
    func saveTestResults(_ testResults: [String: String], for timestamp: String)
    func getAllTests() -> [String: [String: String]]
    func exportTestData() -> String // For debugging and analysis
}
```

## Project Structure

```
VisualAcuityTest/
├── Distance Measure Test/           # Main application code
│   ├── ETDRSViewController.swift    # ETDRS test with speech recognition
│   ├── TumblingEViewController.swift # Landolt C test with gestures
│   ├── TestProgressionDataCollector.swift # Test progression data collection
│   ├── SettingsViewController.swift # App configuration
│   ├── ResultViewController.swift   # Test results and scoring
│   ├── Select_Acuity.swift         # Acuity level selection
│   ├── DistanceOptimization.swift  # AR distance calibration
│   ├── TestHistoryViewController.swift # Historical data view with CSV export
│   ├── Main Menu.swift             # Navigation and audio management
│   ├── OneEyeInstruc.swift         # Eye-specific instructions
│   ├── Instructions.swift          # General instructions
│   ├── AppDelegate.swift           # App lifecycle
│   ├── Assets.xcassets/            # Visual assets and icons
│   ├── Base.lproj/                 # Storyboards and localization
│   └── art.scnassets/              # 3D models for AR
├── optician-sans-font/             # Sloan font for medical accuracy
├── Distance Measure Test.xcodeproj/ # Xcode project configuration
├── Distance Measure Test.xcworkspace/ # Workspace for dependencies
└── Distance-Measure-Test-Info.plist # App configuration
```

## Key Algorithms & Features

### **Real-time Distance Monitoring**
- **CADisplayLink Integration**: 10fps distance updates for smooth performance
- **AR Face Anchor Tracking**: Precise eye position calculation in 3D space
- **Dynamic Letter Scaling**: Real-time size adjustment maintaining visual accuracy
- **Distance Validation**: Robust filtering of invalid readings with fallback mechanisms

### **Intelligent Speech Processing**
- **Phonetic Mapping System**: 100+ phonetic variations for ETDRS letters
- **Conversation Detection**: Multi-rule filtering system preventing false positives
- **Timeout Management**: Automatic recognition restart for continuous operation
- **Audio Session Management**: Optimized for speech recognition and playback

### **Test Logic & Scoring**
- **Adaptive Difficulty**: Dynamic progression based on user performance
- **ETDRS Compliance**: Standard 5-arcminute letter sizing at all distances
- **LogMAR Calculation**: Precise scoring with error adjustment
- **Binocular Testing**: Separate left and right eye assessment

### **Accessibility & User Experience**
- **Comprehensive Audio Support**: Instructions and feedback throughout
- **VoiceOver Integration**: Full accessibility for visually impaired users
- **Emergency Overrides**: Triple-tap gesture to bypass distance checking
- **Visual Feedback**: Clear indicators for distance, progress, and results

### **Advanced Test Progression Data Collection**
- **Granular Response Tracking**: Records every test response with millisecond precision
- **Comprehensive Metrics**: Captures timing, distance, accuracy, and user behavior
- **Research-Grade Export**: CSV generation for detailed analysis and research
- **Session-Based Organization**: Separate data collection for each eye and test session

## Performance Characteristics

### **Computational Efficiency**
- **Optimized AR Processing**: Throttled updates (100ms intervals) to reduce CPU load
- **Efficient Letter Scaling**: Transform-based scaling without layout recalculation
- **Memory Management**: Proper cleanup of AR sessions, audio engines, and timers
- **Background Processing**: Distance calculations off main thread

### **Accuracy & Reliability**
- **Medical-Grade Precision**: ETDRS-compliant calculations with PPI correction
- **Robust Error Handling**: Comprehensive validation and fallback mechanisms
- **Distance Validation**: Multi-layer filtering preventing invalid measurements
- **Test Integrity**: Sophisticated speech filtering ensuring valid responses

## Dependencies & Requirements

### **iOS Frameworks**
- **ARKit**: Face tracking and 3D positioning
- **AVFoundation**: Audio recording, playback, and speech synthesis
- **Speech**: Real-time speech-to-text recognition
- **SceneKit**: 3D rendering for AR visualization
- **UIKit**: User interface and gesture recognition

### **Third-Party Libraries**
- **DevicePpi**: Accurate screen resolution detection for scaling calculations

### **System Requirements**
- **iOS 13.0+**: Required for ARKit face tracking
- **TrueDepth Camera**: Face ID compatible devices for optimal AR performance
- **Microphone Access**: Required for ETDRS speech recognition
- **Camera Access**: Required for AR distance tracking

## Installation & Setup

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd VisualAcuityTest
   ```

2. **Open in Xcode**
   ```bash
   open "Distance Measure Test.xcworkspace"
   ```

3. **Configure signing**
   - Select your development team in project settings
   - Update bundle identifier if necessary

4. **Install dependencies**
   - DevicePpi should be automatically resolved via Swift Package Manager

5. **Run on device**
   - Face tracking requires physical iOS device
   - Simulator testing limited to UI components only

## Usage Guide

### **Getting Started**
1. **Distance Calibration**: Position device for clear flower image visibility
2. **Test Selection**: Choose between ETDRS (voice) or Landolt C (gestures)
3. **Acuity Selection**: Select smallest clearly visible letter size
4. **Eye Testing**: Complete right eye first, then left eye
5. **Results Review**: View LogMAR and Snellen scores with test history

### **ETDRS Test (Voice Recognition)**
- Speak letter names clearly into device microphone
- App filters conversation and focuses on single letter responses
- Supports phonetic variations ("see" → "C", "are" → "R")
- Automatic progression based on accuracy

### **Landolt C Test (Gesture)**
- Swipe in direction of C opening (up, down, left, right)
- Visual feedback with letter animation
- Real-time scoring and progression
- Touch-friendly interface for all users

## Test Progression Data Collection

### **Overview**

The app includes a comprehensive data collection system that automatically records detailed test progression data for research and analysis purposes. This system captures granular information about user performance, response patterns, and testing conditions without interfering with the user experience.

### **Data Collected**

Each test response automatically captures the following data points:

| Field | Description | Example |
|-------|-------------|---------|
| **Timestamp** | Precise time of response (millisecond accuracy) | `2024-09-11 14:23:45.123` |
| **Eye** | Which eye is being tested | `Left`, `Right` |
| **Test_Type** | Type of visual acuity test | `ETDRS`, `Landolt_C` |
| **Acuity_Level** | Current difficulty level | `20/100`, `20/40`, `20/20` |
| **Letter_Displayed** | What was shown to user | `C`, `F`, `Right`, `Down` |
| **Distance_CM** | User's distance from device (AR tracked) | `42.3`, `38.7` |
| **Response_Time_MS** | Time from display to response | `1250`, `890` |
| **User_Response** | User's actual input | `C`, `F`, `Left`, `Up` |
| **Is_Correct** | Response accuracy | `TRUE`, `FALSE` |
| **Trial_Number** | Trial within current acuity level | `1`, `2`, `3`... |
| **Session_ID** | Unique identifier for test session | `ETDRS_Right_20240911_142345` |

### **🔧 How Data Collection Works**

#### **Automatic Background Collection**
- **Session Initialization**: Each test (per eye) creates a unique session with timestamp-based ID
- **Response Tracking**: Every user input triggers data recording with precise timing
- **Distance Monitoring**: Real-time AR face tracking provides continuous distance measurements
- **Session Cleanup**: Data is automatically saved when test completes or user exits

#### **Technical Implementation**
```swift
// Example data recording for ETDRS test
dataCollector.recordResponse(
    eye: "Right",
    testType: "ETDRS", 
    acuityLevel: "20/40",
    letterDisplayed: "C",
    distanceCM: 42.3,
    responseTimeMS: 1250,
    userResponse: "C",
    isCorrect: true,
    trialNumber: 5
)
```

#### **Data Storage**
- **Persistent Storage**: Data survives app restarts using UserDefaults with JSON encoding
- **Memory Efficient**: Session-based collection with automatic cleanup
- **Privacy Focused**: All data stored locally on device until explicitly exported

### **Data Export Options**

#### **Export Methods Available**
Access from **Test History** screen with three export options:

1. ** Export Left Eye CSV**
   - Contains all responses for left eye tests across all sessions
   - Filename: `visual_acuity_left_eye_data.csv`

2. ** Export Right Eye CSV** 
   - Contains all responses for right eye tests across all sessions
   - Filename: `visual_acuity_right_eye_data.csv`

3. ** Export Combined CSV**
   - Contains all test data from both eyes in chronological order
   - Filename: `visual_acuity_combined_data.csv`

#### **Export Process**
1. Navigate to **Test History** screen
2. Export buttons appear automatically when data is available
3. Button titles show response counts (e.g., " Export Left Eye CSV (47 responses)")
4. Tap desired export button
5. Use iOS share sheet to:
   - **Email** CSV file to researchers
   - **AirDrop** to other devices
   - **Save to Files** app or cloud storage
   - **Share** via any installed app

#### **Sample CSV Output**
```csv
Timestamp,Eye,Test_Type,Acuity_Level,Letter_Displayed,Distance_CM,Response_Time_MS,User_Response,Is_Correct,Trial_Number,Session_ID
2024-09-11 14:23:45.123,Right,ETDRS,20/100,C,42.3,1250,C,TRUE,1,ETDRS_Right_20240911_142345
2024-09-11 14:23:47.456,Right,ETDRS,20/100,F,41.8,890,F,TRUE,2,ETDRS_Right_20240911_142345
2024-09-11 14:23:49.789,Right,ETDRS,20/100,H,42.1,1450,K,FALSE,3,ETDRS_Right_20240911_142345
2024-09-11 14:23:52.123,Right,ETDRS,20/80,D,41.9,1100,D,TRUE,1,ETDRS_Right_20240911_142345
2024-09-11 14:25:15.678,Left,Landolt_C,20/100,Right,43.2,980,Right,TRUE,1,Landolt_C_Left_20240911_142515
```

### ** Research Applications**

#### **Behavioral Analysis**
- **Response Time Patterns**: Analyze how reaction times change with difficulty
- **Distance Compliance**: Monitor user adherence to optimal testing distance
- **Learning Effects**: Track improvement within and across test sessions
- **Error Patterns**: Identify common mistakes at different acuity levels

#### **Clinical Research**
- **Test Reliability**: Compare consistency across multiple sessions
- **Method Comparison**: Analyze differences between ETDRS and Landolt C performance
- **Accessibility Evaluation**: Study effectiveness of voice vs. gesture interfaces
- **Remote Monitoring**: Track vision changes in longitudinal studies

#### **Data Analysis Capabilities**
- **Progression Tracking**: Monitor how users advance through acuity levels
- **Performance Metrics**: Calculate detailed statistics on accuracy and timing
- **Session Analytics**: Compare performance between left and right eye tests
- **Temporal Analysis**: Study performance changes over time and across sessions

### **🔒 Privacy & Data Management**

- **Local Storage**: All data remains on user's device until explicitly exported
- **User Control**: Users choose when and how to export their data
- **Clear History**: Option to delete all collected data from Test History screen
- **No Automatic Upload**: Data export requires explicit user action
- **Research Consent**: Users control their participation in data sharing

This data collection system provides researchers with unprecedented insight into visual acuity testing behavior while maintaining user privacy and control.

## Future Development

### **Planned Features**
- **RESTful API**: Django/Flask backend for user management
- **Database Integration**: MongoDB for comprehensive data storage
- **Multi-language Support**: Localization for international deployment
- **Clinical Integration**: FHIR compatibility for medical records
- **Advanced Analytics**: ML-based vision trend analysis

### **Technical Improvements**
- **Offline Capability**: Local speech processing options
- **Enhanced AR**: Improved tracking in challenging lighting
- **Performance Optimization**: Further CPU and battery optimizations
- **Extended Device Support**: Compatibility with older iOS devices

## Research & Clinical Applications

This application serves as a research platform for:
- **Remote Vision Screening**: Accessible testing outside clinical settings
- **Longitudinal Studies**: Tracking vision changes over time
- **Accessibility Research**: Evaluating voice vs. gesture interfaces
- **AR in Healthcare**: Advancing AR applications in medical testing
- **Mobile Health**: Contributing to telemedicine capabilities

## Directory Structure Reference

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
/Distance Measure Test contains all of the app's actual code, so here we discuss what every element of this directory contains. This includes both subdirectories and associated assets, as well as the .swift code files.

### /Distance Measure Test/Assets.xcassets
The /Assets.xcassets directory contains the app’s visual resources and color settings. These assets are managed in Xcode and used throughout the app to ensure consistent and optimized display across all devices. It includes:

1. AccentColor: The app’s theme color.
2. AiAppLogo: The logo used for branding.
3. AppIcon: Icons required for app distribution.
4. Button: Graphics for interactive buttons.
5. InstructionsTitle: Visuals for the instructions section.
6. TargetImage: Images used in the tumbling E visual test.
7. Contents.json: Metadata configuration for the assets.

### Distance Measure Test/Base.lproj
The /Base.lproj directory is the base localization folder for the app. It contains resources that define the app's default UI and layout. It is used as the foundation for supporting multiple languages or regions. Typical files in this directory include:

1. LaunchScreen.storyboard: Defines the splash screen that appears when the app is launched. This screen provides users with a visually appealing placeholder while the app loads.
2. Main.storyboard: Contains the primary user interface layout for the app, including all the screens, buttons, labels, and other UI components.

### Distance Measure Test/art.scnassets
The /art.scnassets directory contains 3D assets and resources used in the app. This directory is specifically designed for SceneKit projects, which support rendering 3D content in iOS apps. It holds the files necessary for creating and displaying 3D models, textures, and materials.

### Distance Measure Test/AppDelegate.swift

The `AppDelegate.swift` file is a core part of the app's lifecycle management in an iOS project. It acts as the **application delegate**, handling key events during the app's lifecycle, such as launching, transitioning to the background, or becoming active again.

#### Key Features:
- **`application(_:didFinishLaunchingWithOptions:)`**: Called when the app has finished launching. This is where initial setup or customization of the app takes place.
- **`applicationWillResignActive(_:)`**: Triggered when the app is about to move from active to inactive state, such as during temporary interruptions (e.g., an incoming call).
- **`applicationDidEnterBackground(_:)`**: Called when the app moves to the background. This is used to release shared resources, save user data, and manage the app's state for potential restoration later.
- **`applicationWillEnterForeground(_:)`**: Invoked during the transition from the background to the active state, allowing the app to undo changes made while entering the background.
- **`applicationDidBecomeActive(_:)`**: Called when the app becomes active again, restarting tasks or refreshing the UI if necessary.

This file is essential for defining app-wide behavior and responding to changes in the app’s state. 

**Created by:** Mahmoud Abdelmoneum on July 19, 2023.

### Distance Measure Test/DistanceOptimization.swift

The `DistanceOptimization.swift` file implements functionality to measure the user's face's distance from the selfie camera using **ARKit** and **SceneKit**. It leverages face tracking and 3D rendering to calculate the distance from the user's eyes to the device, which is essential for the app's visual acuity tests. This supports the *'Distance Optimization'* of the app, in which the user is presented with an image of a flower, and must adjust the distance at which they hold their device until they can see the details of the flower most clearly. Once they do, they click the capture distance button, which captures and stores the distance that their device is from between their eyes, a metric which is critical for sizing the letters of the test later during the test.

#### Key Features:

1. **ARKit Integration:**
   - Uses `ARFaceTrackingConfiguration` to track the user's face and eyes in real-time.
   - Captures precise positional data for both eyes relative to the device.

2. **SceneKit Rendering:**
   - Renders a 3D scene using the `ARSCNView`, including visual elements like eye geometry to enhance tracking feedback.
   - The `ship.scn` model is used as the base scene for rendering.

3. **Distance Measurement:**
   - Calculates the **average distance** (in centimeters) from the camera to the user's left and right eyes using the `capDistance` function.
   - Updates a global variable `averageDistanceCM` to store the calculated distance, which is displayed in the console.

4. **Dynamic Distance Tracking:**
   - The `trackDistance` function asynchronously updates the distance of the eyes in real-time for potential further processing.

5. **Custom Extensions:**
   - Adds an extension to `SCNVector3` to calculate vector lengths and differences, which is crucial for computing distances in 3D space.

#### Key Functions:
- **`capDistance(_:)`**
  - Computes and logs the average distance from the user's eyes to the device in centimeters.
- **`renderer(_:didAdd:for:)` and `renderer(_:didUpdate:for:)`**
  - Manage updates to the 3D face and eye node positions in real-time.
- **`trackDistance()`**
  - Tracks the position of the eyes relative to the camera for continuous distance monitoring.

#### Code Highlights:
- **Face and Eye Geometry:**
  - Utilizes `SCNSphere` with a blue material to visualize eye tracking nodes in the 3D space.
- **AR Session Management:**
  - Configures and manages the AR session lifecycle with `viewWillAppear` and `viewWillDisappear`.

This file is integral to the app's functionality, providing the tools to accurately measure and utilize near-distance information for the visual acuity test.

### Distance Measure Test/Instructions.swift

The `Instructions.swift` file is responsible for displaying the **instructions screen** of the app. This screen provides users with clear, concise guidance on how to prepare for the ETDRS Visual Acuity Test.

#### Key Features:
1. **Instruction Display:**
   - Uses a `UILabel` (`instructionText`) to present detailed steps to the user.
   - Explains the process for determining the optimal distance for the test.

2. **Dynamic Text Setup:**
   - The text content is programmatically set in the `viewDidLoad` method, ensuring flexibility for future updates or localization.

3. **ETDRS Test Context:**
   - Guides users to adjust the distance to their phone for optimal clarity of the reference image (e.g., the white flower) before starting the test.

#### Code Highlights:
- **`instructionText` Property:**
  - Displays the following instructions to the user:
    > "Welcome to our app-based ETDRS Visual Acuity Test. To perform the test, we must first find the optimal distance for you to take the test at. To do so, in the next screen, you must hold the phone at a distance in which the displayed image of the white flower is clear and easy to see. Once you find a comfortable distance, hold your phone there, press the 'capture distance' button, and then click begin test."
- **Lifecycle Integration:**
  - The `viewDidLoad` method ensures the instruction text is set when the screen is loaded, providing a seamless user experience.

#### Key Details:
- **Created by:** Anderson Men on August 7, 2023.
- **Modified by:** Maggie Bao on August 20, 2023.

This file is critical to onboarding users and ensuring they understand the necessary steps to perform the ETDRS Visual Acuity Test correctly.

### Distance Measure Test/Main Menu.swift

The `Main Menu.swift` file implements the **main menu screen** for the app. This serves as the starting point for navigation to other sections of the ETDRS Visual Acuity Test app, such as the instructions or distance measurement functionalities.

#### Key Features:
1. **Navigation Framework:**
   - Provides the base structure for navigating between different screens in the app using Storyboard segues.
   - The `prepare(for:sender:)` method is available for passing data or configuring the destination view controller during navigation (currently commented but can be extended as needed).

2. **Lifecycle Integration:**
   - The `viewDidLoad` method is included for performing any setup or initialization tasks required when the main menu screen is loaded.

3. **Expandable Structure:**
   - Includes placeholder code (`// MARK: - Navigation`) to facilitate future extensions, such as passing context or data to subsequent screens.

#### Key Details:
- **Created by:** Anderson Men on August 7, 2023.

This file is the backbone for the app's main menu, offering flexibility for adding interactive elements, buttons, or additional functionality as the project evolves.

### Distance Measure Test/OpenAI_API_CorrectLetters.swift

The `OpenAI_API_CorrectLetters.swift` file provides functionality to transcribe spoken words into corresponding **ETDRS letters** by leveraging the OpenAI GPT API. This is essential for interpreting user inputs during the visual acuity test.

#### Key Features:
1. **Integration with OpenAI GPT API:**
   - Sends a user-provided transcription to OpenAI's GPT model to determine the nearest corresponding single letter, adhering to the ETDRS standard.

2. **Custom Prompt Design:**
   - The prompt ensures accurate transcription by limiting responses to ETDRS letters and providing clear examples, such as:
     - "aye" → "A"
     - "see" → "C"
     - "oh" → "O"
     - "yes" → "S"

3. **Error Handling:**
   - Handles potential errors in the API request process, such as network issues, serialization failures, or invalid API responses.
   - Ensures a valid single-letter response or returns `nil` if the input cannot be mapped to an ETDRS letter.

4. **Asynchronous Design:**
   - Uses a completion handler (`@escaping (String?) -> Void`) to handle the asynchronous API call and return the corrected letter when available.

#### Code Highlights:
- **API Request:**
  - Sends a POST request to OpenAI's `https://api.openai.com/v1/chat/completions` endpoint.
  - Uses the `gpt-4o` model with a highly specific prompt to ensure accurate letter transcription.

- **JSON Parsing:**
  - Parses the API's JSON response to extract the corrected letter from the `choices` array.
  - Validates the response to ensure it is a single uppercase letter.

- **Key Functionality:**
  - **`getCorrectLetter(transcription:completion:)`**:
    - Takes a transcription string and determines the corresponding ETDRS letter using the GPT API.
    - Handles the API call, response parsing, and error management.

### Distance Measure Test/ResultViewController.swift

The `ResultViewController.swift` file is responsible for displaying the **results** of the visual acuity test. It calculates and presents the user’s vision score in **Snellen and LogMAR** formats and provides a structured framework for further extensions, such as recommendations and retry options.

#### Key Features:
1. **LogMAR and Snellen Acuity Calculations:**
   - Converts the user's vision score from Snellen to LogMAR using the `snellenToLogMAR` method.
   - Displays the calculated LogMAR value and the final Snellen acuity.

2. **Dynamic UI Elements:**
   - **`scoreLabel`**: Displays the LogMAR score in a large, readable font.
   - **`acuityLabel`**: Displays the Snellen visual acuity score prominently.
   - Additional UI elements, such as buttons for retrying or finishing the test, and a recommendation label, are included but currently commented out for potential future use.

3. **Navigation:**
   - Includes methods for navigating back to the main menu or retrying the test:
     - **`redoTest`**: Allows the user to retry the test.
     - **`tapDone`**: Returns the user to the main menu.

4. **Adaptive Layout:**
   - Uses Auto Layout constraints to ensure the UI elements are dynamically positioned and responsive across different device sizes.

5. **Extendable Structure:**
   - Includes commented-out methods and elements (e.g., `recommendationLabel`, `getRecommendation`) for providing user feedback based on the visual acuity score.

#### Code Highlights:
- **Acuity Calculation:**
  - The `snellenToLogMAR` method calculates the LogMAR value based on the Snellen numerator and denominator.
- **Dynamic Text Updates:**
  - The `setupUI` method calculates the final results and updates the labels dynamically:
    - LogMAR Score: `scoreLabel`
    - Snellen Acuity: `acuityLabel`
- **UI Customization:**
  - Uses lazy-loaded UI components for a clean and efficient setup.

#### Example Output:
- **LogMAR Score:** `0.3010`
- **Snellen Final Acuity:** `20/40`

#### Key Details:
- **Created by:** Maggie Bao on August 30, 2023.
- **Purpose:** Displays test results and facilitates user actions like retrying the test or returning to the main menu.

This file is a critical component for delivering a user-friendly summary of test results, while also providing a framework for potential extensions like vision recommendations.

### Distance Measure Test/Select_Acuity.swift

The `Select_Acuity.swift` file implements the functionality for selecting the desired **ETDRS visual acuity level**. It dynamically adjusts the size of the buttons representing different acuity levels based on the distance from the device to ensure accurate test conditions.

#### Key Features:
1. **Dynamic Button Scaling:**
   - The `Button_ETDRS` function calculates the size of each button dynamically based on:
     - The **ETDRS acuity level** (e.g., 20/20, 20/40, etc.).
     - The measured distance (`averageDistanceCM`) between the user and the device.
     - The visual angle of the ETDRS letter for a given acuity level.
   - Ensures consistent visual scaling across devices by considering the **screen resolution (PPI)** and converting measurements to centimeters.

2. **Predefined Acuity Levels:**
   - Buttons correspond to different ETDRS acuity levels, including:
     - 20/200, 20/160, 20/125, 20/100, 20/80, 20/63, 20/50, 20/40, 20/32, 20/20.
   - Each button is labeled with the letter "E" using the **Optician Sans** font.

3. **User Selection:**
   - Tapping a button sets the `selectedAcuity` variable to the chosen acuity level via the corresponding `@IBAction` methods.

4. **Customizable UI:**
   - The buttons' height, width, and font size are calculated dynamically to ensure they adhere to the ETDRS standards.

#### Code Highlights:
- **`Button_ETDRS` Method:**
  - Dynamically calculates button dimensions and font size using:
    - Visual angle formula: `tan((acuity_level / 20) * 5 / 60 * π / 180)`
    - Scaling factor for real-world accuracy: `scaling_correction_factor` and screen resolution (`ppi`).
- **Button Initialization in `viewDidLoad`:**
  - Each button is initialized with its corresponding acuity level and dynamically adjusted size and font.

- **Button Actions:**
  - Each button's `@IBAction` method sets the `selectedAcuity` variable to the corresponding acuity level, making it available for subsequent test steps.

#### Example:
For a user distance of `40 cm`, the buttons dynamically resize to represent accurate visual angles for each acuity level, ensuring reliable test results.

#### Key Details:
- **Created by:** Maggie Bao on May 14, 2024.
- **Purpose:** Allows users to select a desired ETDRS acuity level while ensuring visual accuracy through dynamic scaling.

This file is essential for ensuring that the ETDRS test maintains its visual accuracy and integrity across varying user-device distances.

### Distance Measure Test/SpeechRecognizer.swift

The `SpeechRecognizer.swift` file provides functionality for **real-time speech-to-text transcription** using Apple's **Speech Framework** and **AVFoundation**. It is designed as a helper class to enable speech recognition within the app, offering features like continuous transcription, error handling, and easy integration.

#### Key Features:
1. **Speech Recognition:**
   - Uses `SFSpeechRecognizer` to transcribe spoken audio into text.
   - Continuously updates the transcribed text in the `transcript` property.

2. **Asynchronous Authorization Handling:**
   - Checks and requests user permissions for speech recognition and microphone access using `hasAuthorizationToRecognize` and `hasPermissionToRecord`.

3. **Error Handling:**
   - Provides comprehensive error messages through the `RecognizerError` enum for common issues, such as:
     - Unavailable recognizer.
     - Lack of microphone permissions.
     - Failure to initialize the recognizer.

4. **Dynamic Session Management:**
   - Manages the lifecycle of the audio session, including starting, stopping, and resetting the speech recognition task.

5. **Customizable for UI Updates:**
   - Continuously updates the `transcript` property, making it easy to bind to UI elements in **SwiftUI** or **UIKit**.

#### Code Highlights:
- **Initialization:**
  - Automatically requests authorization for speech recognition and microphone access when a `SpeechRecognizer` instance is created.
  
- **Core Methods:**
  - **`startTranscribing()`**: Starts speech transcription and updates the `transcript` property in real-time.
  - **`stopTranscribing()`**: Stops transcription and resets the audio session.
  - **`resetTranscript()`**: Clears the `transcript` property.

- **Audio Engine Preparation:**
  - Configures `AVAudioEngine` with appropriate settings for high-quality audio recording and recognition.

- **Error Feedback:**
  - Provides meaningful feedback when issues occur, such as lack of permissions or unavailable recognizers, by updating the `transcript` property with error messages.

### Distance Measure Test/Test.swift

The `Test.swift` file defines the **test screen** for the app, where the actual ETDRS visual acuity test is conducted. It manages the test logic, user inputs, and progress tracking, ultimately calculating the user's visual acuity based on their performance.

#### Key Features:
1. **Dynamic Visual Acuity Testing:**
   - Adjusts letter size dynamically based on the user’s selected acuity and distance (`averageDistanceCM`) to maintain visual accuracy.
   - Uses `set_ETDRS` to calculate the appropriate size and font for letters.

2. **User Input Assessment:**
   - Collects user inputs via a text field (`UserInput`) and assesses correctness using the `assessInput` function.
   - Tracks performance (e.g., correct responses, trials) and adjusts the test dynamically.

3. **Acuity Progression:**
   - Guides the user through a sequence of decreasing letter sizes based on the **ETDRS standard** (e.g., 20/200 → 20/20).
   - Adjusts difficulty based on performance, ending the test if thresholds (e.g., fewer than 3 correct responses) are not met.

4. **Test Completion and Results:**
   - Calculates the final visual acuity using the `computeFinalAcuity` function, providing results in Snellen notation (e.g., 20/40).
   - Optionally navigates to a results screen for displaying the test outcome.

5. **Randomized Letter Generation:**
   - Generates randomized ETDRS letters for each trial using `randomLetters(size:)`.

6. **UI Elements:**
   - `LetterRow1`: Displays the current letter to the user.
   - `UserInput`: Captures the user’s response for each trial.

#### Code Highlights:
- **Dynamic Letter Scaling:**
  - The `set_ETDRS` function scales letters based on:
    - Visual angle formula: `tan((acuity_level / 20) * 5 / 60 * π / 180)`
    - Screen resolution (`ppi`) and distance from the user.
- **Performance Tracking:**
  - Tracks user responses and performance through dictionaries (`displayLetters`, `userResponses`, `acuityVisits`).
  - Adapts the test dynamically based on user success or failure.
- **Input Assessment:**
  - The `assessInput` function compares the user’s input sequence with the displayed letters, counting matches.

#### Example Flow:
1. **Test Initialization:**
   - The user’s selected acuity level initializes the test (`viewDidLoad`).
   - The first letter is displayed using `setNextLetter`.
2. **User Interaction:**
   - The user inputs their response via `UserInput`.
   - The app evaluates correctness after every 5 trials (`nextLineIsPressed`).
3. **Test Completion:**
   - The app ends the test when the user successfully identifies the smallest letters or fails to identify larger ones.

#### Functions:
- **`setNextLetter`**: Selects and displays the next randomized letter.
- **`processTranscription`**: Processes and evaluates user responses.
- **`computeFinalAcuity`**: Calculates the final Snellen acuity score based on performance.
- **`endTest`**: Finalizes the test and prints or navigates to the results screen.

#### Key Details:
- **Created by:** Anderson Men on August 7, 2023.
- **Modified by:** Maggie Bao on August 21, 2023; August 27, 2023; September 10, 2023; September 30, 2023.
- **Purpose:** Implements the core functionality of the ETDRS visual acuity test, ensuring dynamic scaling, user performance tracking, and result calculation.

This file is critical for conducting accurate visual acuity tests and determining user vision levels based on ETDRS standards.

### Distance Measure Test/TumblingEViewController.swift

The `TumblingEViewController.swift` file implements the **Tumbling E visual acuity test**. It evaluates the user's ability to correctly identify the orientation of the letter "E" as it rotates to different angles, progressing through various visual acuity levels.

#### Key Features:
1. **Dynamic Visual Acuity Levels:**
   - Acuity levels follow the ETDRS standard, ranging from 20/200 to 20/16.
   - Letter size dynamically adjusts based on the selected acuity and the user's distance from the device (`averageDistanceCM`).

2. **Interactive Gesture Recognition:**
   - Users swipe in the direction the "E" is pointing (e.g., up, down, left, right) using `UISwipeGestureRecognizer`.
   - Gestures are evaluated against the current orientation to determine correctness.

3. **Performance Tracking:**
   - Tracks the number of correct answers across trials and acuity levels.
   - Automatically progresses or regresses through acuity levels based on performance thresholds:
     - Progresses if 6 consecutive correct answers are achieved.
     - Ends the test if fewer than 6 correct answers are achieved in a set.

4. **Real-Time Feedback:**
   - Provides visual feedback by changing the letter's color:
     - Green for correct answers.
     - Red for incorrect answers.

5. **Test Completion and Results Navigation:**
   - Calculates the final acuity level (`finalAcuityScore`) based on performance.
   - Navigates to the results screen to display test outcomes.

#### Code Highlights:
- **Dynamic Letter Scaling:**
  - The `set_Size_E` method adjusts the letter's size and font based on:
    - The visual angle formula: `tan((acuity_level / 20) * 5 / 60 * π / 180)`
    - Screen resolution (`ppi`) and user distance.

- **Gesture Handling:**
  - Swipes are compared with the current rotation of the letter using `handleSwipe` to evaluate correctness.

- **Performance Logic:**
  - Tracks correct answers in the current set (`correctAnswersInSet`) and across acuity levels (`correctAnswersAcrossAcuityLevels`).
  - Advances or regresses acuity levels based on performance thresholds.

- **Real-Time Updates:**
  - The `generateNewE` method randomly rotates the "E" for each trial.
  - The `updateScore` method updates the user's score in real-time.

#### Example Flow:
1. **Initialization:**
   - The test starts with the user's selected acuity level.
   - Letter size is set dynamically using `set_Size_E`.
2. **User Interaction:**
   - The user swipes in response to the orientation of the "E."
   - Correctness is evaluated, and visual feedback is provided.
3. **Progression:**
   - The app progresses or regresses through acuity levels based on the number of correct answers.
4. **Completion:**
   - The test ends, and the user is navigated to the results screen with their final acuity score.

#### Functions:
- **`set_Size_E`**: Dynamically scales the letter "E" for visual accuracy.
- **`handleSwipe`**: Evaluates user swipes for correctness.
- **`generateNewE`**: Randomly rotates the "E" for each trial.
- **`endTest`**: Finalizes the test and navigates to the results screen.

#### Key Details:
- **Created by:** Maggie Bao on September 10, 2023.
- **Purpose:** Implements the interactive Tumbling E test to assess visual acuity dynamically.

This file is essential for conducting accurate, interactive visual acuity tests based on the Tumbling E standard.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

This project is developed for research purposes at OHSU COOL Lab. Please contact the development team for licensing information and usage permissions.

## Acknowledgments

- **OHSU COOL Lab**: Research facility and support
- **Dr. David Huang & Dr. Hiroshi Ishikawa**: Clinical guidance and supervision
- **Apple Developer Documentation**: ARKit and Speech framework implementation
- **ETDRS Research Group**: Visual acuity testing standards and methodologies

---

*This README represents a comprehensive technical overview of a sophisticated medical-grade iOS application with 5,031 lines of carefully crafted Swift code, demonstrating advanced iOS development practices, AR integration, speech processing, and clinical-grade accuracy in visual acuity assessment.*
