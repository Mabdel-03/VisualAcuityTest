import UIKit
import SceneKit
import ARKit
import AVFoundation

var averageDistanceCM = 0.0

/*
 The DistanceTracker class is designed to manage distance measurements. 
 It provides real-time distance tracking with smoothing algorithms and persistent 
 storage capabilities.
 */

class DistanceTracker {
    static let shared = DistanceTracker()

    var currentDistanceCM: Double = 0.0  // Live tracking distance
    var targetDistanceCM: Double = 0.0   // Captured optimal distance
    
    // Buffer for smoothing distance readings
    private var recentReadings: [Double] = []
    private let maxReadings = 5

    /* Private initializer enforcing singleton pattern
    */
    private init() {}
    
    /* Adds a new distance reading with smoothing algorithm. 
        Validates input (rejects values ≤ 0), adds reading to buffer, 
        maintains buffer size limit, and updates currentDistanceCM with 
        smoothed average.
        @param distance: Distance value in centimeters
    */
    func addReading(_ distance: Double) {
        // Don't add invalid readings
        if distance <= 0 {
            return
        }
        // Add to recent readings
        recentReadings.append(distance)
        // Keep only the most recent readings
        if recentReadings.count > maxReadings {
            recentReadings.removeFirst()
        }
        // Update current distance with smoothed value
        if !recentReadings.isEmpty {
            currentDistanceCM = recentReadings.reduce(0, +) / Double(recentReadings.count)
        }
    }
}



/* DistanceOptimization class is designed to manage the distance optimization scene on the
    visual acuity app. On this page, the user is asked to hold their phone at a distance where
    they can clearly see the flower image. When the image appears the most clear, the user
    taps 'Capture Distance' button to save this distance as the optimal distance for their test.
*/

class DistanceOptimization: UIViewController, ARSCNViewDelegate {
    @IBOutlet var sceneView: ARSCNView!
    var faceNode: SCNNode!
    var leftEye: SCNNode!
    var rightEye: SCNNode!
    var distanceStable = false
    var stableReadingCount = 0
    var lastCapturedDistance: Double = 0.0
    
    // Header label
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Get Best Distance"
        label.drawHeader()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add decorative daisies
        addDecorativeDaisies()
        
        // Add header label
        view.addSubview(headerLabel)
        view.bringSubviewToFront(headerLabel)
        
        // Set up header constraints
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        // Create a new scene
        let scene = SCNScene(named: "/ship.scn")!
        // Set the scene to the view
        sceneView.scene = scene

        // Set up the face node and eyes
        let eyeGeometry = SCNSphere(radius: 0.01)
        eyeGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode(geometry: eyeGeometry)
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1

        leftEye = node.clone()
        rightEye = node.clone()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }

    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Position phone for clear flower view, then tap Capture Distance."
        SharedAudioManager.shared.playText(instructionText, source: "Distance Optimization")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    /* Captures the distance and immediately transitions to the next scene when the 
    user taps the 'Capture Distance' button.
    */
    @IBAction func capDistanceTransition(_ sender: Any) {
        // Make sure we have valid eye positions before capturing
        guard let frame = sceneView.session.currentFrame,
              leftEye != nil && rightEye != nil else {
            print("⚠️ Cannot capture distance: Face not detected")
            return
        }
        
        let cameraTransform = frame.camera.transform
        let cameraPosition = SCNVector3(cameraTransform.columns.3.x,
                                        cameraTransform.columns.3.y,
                                        cameraTransform.columns.3.z)                       
        let leftEyePos = leftEye.worldPosition
        let rightEyePos = rightEye.worldPosition
        
        // Validate that eye positions are valid
        if leftEyePos.length() < 0.001 || rightEyePos.length() < 0.001 {
            print("⚠️ Eye positions not valid yet - cannot capture distance")
            return
        }
        
        // Calculate distance from camera to eyes
        let leftEyeDistance = SCNVector3Distance(leftEyePos, cameraPosition) * 100  // Convert to cm
        let rightEyeDistance = SCNVector3Distance(rightEyePos, cameraPosition) * 100  // Convert to cm
        let averageDistance: Float
        if (eyeNumber == 1){
            print("Left eye tracking enabled")
            averageDistance = leftEyeDistance
        }
        else {
            print("Right eye tracking enabled")
            averageDistance = rightEyeDistance
        }

        // Validate the measured distance is reasonable
        if averageDistance < 10 || averageDistance > 100 {
            print("⚠️ Distance measurement out of expected range: \(averageDistance) cm")
            return
        }

        // Store the target distance
        let distanceValue = Double(averageDistance)
        averageDistanceCM = distanceValue
        DistanceTracker.shared.targetDistanceCM = distanceValue
        
        // Reset the recent readings with the new target
        DistanceTracker.shared.addReading(distanceValue)
        
        // Set current distance to match target
        DistanceTracker.shared.currentDistanceCM = distanceValue

        print("🎯 Target Distance Captured: \(String(format: "%.1f", averageDistanceCM)) cm")
        lastCapturedDistance = distanceValue
        
        // Save to UserDefaults for persistence across app launches
        UserDefaults.standard.set(distanceValue, forKey: "SavedTargetDistance")
    }
    
    /* Called when ARKit first detects a face and creates the initial face 
        node. Sets up the initial face tracking structure, called only once per 
        face detection session.
    */
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode = node
        faceNode.addChildNode(leftEye)
        faceNode.addChildNode(rightEye)
        faceNode.transform = node.transform
        trackDistance()
    }

    /* Called every frame(60 times per second on most devices) while the 
        face is being tracked. Continuously updates face and eye positions as 
        the user moves.
    */
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        leftEye.simdTransform = faceAnchor.leftEyeTransform
        rightEye.simdTransform = faceAnchor.rightEyeTransform
        trackDistance()
    }

    /* Tracks the distance between the camera and the eyes.
    */
    func trackDistance() {
        DispatchQueue.main.async {
            guard let frame = self.sceneView.session.currentFrame else { return }
            
            let cameraTransform = frame.camera.transform
            let cameraPosition = SCNVector3(cameraTransform.columns.3.x,
                                           cameraTransform.columns.3.y,
                                           cameraTransform.columns.3.z)
            
            let leftEyePos = self.leftEye.worldPosition
            let rightEyePos = self.rightEye.worldPosition
            
            // Skip if positions are invalid
            if leftEyePos.length() < 0.001 || rightEyePos.length() < 0.001 {
                return
            }
            
            // Calculate distance from camera to eyes
            let leftEyeDistance = SCNVector3Distance(leftEyePos, cameraPosition)
            let rightEyeDistance = SCNVector3Distance(rightEyePos, cameraPosition)
            let averageDistance = (leftEyeDistance + rightEyeDistance) / 2 * 100  // Convert to cm
            
            // Validate measurement before saving
            if averageDistance > 5 && averageDistance < 100 {
                // Add the reading to our tracker with built-in smoothing
                DistanceTracker.shared.addReading(Double(averageDistance))
                
                // Only print occasionally to reduce console spam
                if Int(Date().timeIntervalSince1970 * 10) % 20 == 0 {
                    print("📏 Distance Tracked: \(String(format: "%.1f", Double(averageDistance))) cm")
                }
            }
        }
    }
}

//------------------------------
// MARK: - SCNVector3 Extensions
//------------------------------

extension SCNVector3 {
    func length() -> Float { return sqrtf(x * x + y * y + z * z) }
    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 { return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)     }
}

extension DistanceOptimization {
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    func addDecorativeDaisies() {
        // Decorative daisy 1 - top right (magenta)
        addDecorativeDaisy(
            size: 90,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.07,
            trailingOffset: 25,
            topOffset: 150
        )
        
        // Decorative daisy 2 - bottom left (teal)
        addDecorativeDaisy(
            size: 85,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.11,
            leadingOffset: 30,
            bottomOffset: 100
        )
    }
}

// Helper function to calculate distance between two SCNVector3 points
func SCNVector3Distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
    return sqrtf(
        powf(a.x - b.x, 2) +
        powf(a.y - b.y, 2) +
        powf(a.z - b.z, 2)
    )
}
