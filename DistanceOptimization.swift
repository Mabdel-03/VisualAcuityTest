import UIKit
import SceneKit
import ARKit

var averageDistanceCM = 0.0

class DistanceOptimization: UIViewController, ARSCNViewDelegate {
    @IBOutlet var sceneView: ARSCNView!
        var faceNode: SCNNode!
        var leftEye: SCNNode!
        var rightEye: SCNNode!

        override func viewDidLoad() {
            super.viewDidLoad()
            
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
//        
    @IBAction func capDistance(_ sender: Any) {
        let leftEyeDistance = leftEye.worldPosition.length()
        let rightEyeDistance = rightEye.worldPosition.length()
        let averageDistance = (leftEyeDistance + rightEyeDistance) / 2
        averageDistanceCM = Double(100*averageDistance)
        print("Distance: \(averageDistanceCM) cm")
    }
    
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            faceNode = node
            faceNode.addChildNode(leftEye)
            faceNode.addChildNode(rightEye)
            faceNode.transform = node.transform
            trackDistance()
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            faceNode.transform = node.transform
            guard let faceAnchor = anchor as? ARFaceAnchor else { return }
            leftEye.simdTransform = faceAnchor.leftEyeTransform
            rightEye.simdTransform = faceAnchor.rightEyeTransform
            trackDistance()
        }

        func trackDistance() {
            DispatchQueue.main.async {
                let leftEyeDistanceFromCamera = self.leftEye.worldPosition - SCNVector3Zero
                let rightEyeDistanceFromCamera = self.rightEye.worldPosition - SCNVector3Zero
                // Track the distance as needed
            }
        }
    }

    //------------------------------
    // MARK: - SCNVector3 Extensions
    //------------------------------

    extension SCNVector3 {
        func length() -> Float { return sqrtf(x * x + y * y + z * z) }
        static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 { return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z) }
    }
