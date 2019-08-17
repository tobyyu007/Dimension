/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the AR experience.
 */

import ARKit
import SceneKit
import UIKit
import WebKit
import MultipeerConnectivity

class MultiuserViewController: UIViewController{
    
    // MARK: IBOutlets
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var addObjectButton: UIButton!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var sendMapButton: UIButton!
    
    @IBOutlet weak var mappingStatusLabel: UILabel!
    
    // MARK: - UI Elements
    
    var focusSquare = FocusSquare()
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    /// The view controller that displays the virtual object selection menu.
    var objectsViewController: VirtualObjectSelectionViewController?
    
    // MARK: - ARKit Configuration Properties
    
    /// A type which manages gesture manipulation of virtual content in the scene.
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView)
    
    /// Coordinates the loading and unloading of reference nodes for virtual objects.
    let virtualObjectLoader = VirtualObjectLoader()
    
    /// Marks if the AR experience is available for restart.
    var isRestartAvailable = true
    
    /// A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "com.example.apple-samplecode.arkitexample.serialSceneKitQueue")
    
    var screenCenter: CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    var multipeerSession: MultipeerSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Set up scene content.
        setupCamera()
        sceneView.scene.rootNode.addChildNode(focusSquare)
        
        sceneView.setupDirectionalLighting(queue: updateQueue)
        
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleSceneTap(_:)))
        // Set the delegate to ensure this gesture is only used when there are no virtual objects in the scene.
        tapGesture.delegate = self
        sceneView.addGestureRecognizer(tapGesture)
        
        
        //multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        VirtualObject.availableObjects = VirtualObject.updateReferenceURL() // 每次進入首頁時更新 referenceURL -> 為了讓選單出現新的下載項目
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        // Start the `ARSession`.
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's AR session.
        session.pause()
    }
    
    // MARK: - Scene content setup
    
    func setupCamera() {
        guard let camera = sceneView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }
        
        /*
         Enable HDR camera settings for the most realistic appearance
         with environmental lighting and physically based materials.
         */
        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }
    
    // MARK: - Session management
    
    /// Creates a new AR configuration to run on the `session`.
    func resetTracking() {
        virtualObjectInteraction.selectedObject = nil
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        statusViewController.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
    }
    
    // MARK: - Focus Square
    
    func updateFocusSquare(isObjectVisible: Bool) {
        if isObjectVisible {
            focusSquare.hide()
        } else {
            focusSquare.unhide()
            statusViewController.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
        }
        
        // Perform hit testing only when ARKit tracking is in a good state.
        /// 在這裡與原本的 ViewController 不同，將原本只在 normal state 才會執行的限制移除，這樣才可以在收到別人的 map 後繼續執行
        if let camera = session.currentFrame?.camera, let result = self.sceneView.smartHitTest(screenCenter)
        {
            updateQueue.async
                {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
                }
            addObjectButton.isHidden = false
            statusViewController.cancelScheduledMessage(for: .focusSquare)
        }
        else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
            addObjectButton.isHidden = true
        }
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Blur the background.
        blurView.isHidden = false
        
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.blurView.isHidden = true
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    var mapProvider: MCPeerID?
    
    static var received: Bool = false
    /// - Tag: ReceiveData
    func receivedData(_ data: Data, from peer: MCPeerID) {
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                // Run the session with the received world map.
                MultiuserViewController.received = true
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                // Remember who provided the map for showing UI feedback.
                mapProvider = peer
                print("mapProvicer: ", terminator:"")
                print(mapProvider)
            }
            else
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                    // Add anchor to the session, ARSCNView delegate adds visible content.
                    sceneView.session.add(anchor: anchor)
                }
                else {
                    print("unknown data recieved from \(peer)")
            }
        }
        catch
        {
            print("can't decode data recieved from \(peer)")
        }
    }
    
    /// - Tag: PlaceCharacter
    @objc func handleSceneTap(_ sender: UITapGestureRecognizer) {
        print("tapped")
        // Hit test to find a place for a virtual object.
        guard let hitTestResult = sceneView
            .hitTest(sender.location(in: sceneView), types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
            .first
            else { return }
        
        // Place an anchor for a virtual character. The model appears in renderer(_:didAdd:for:).
        let anchor = ARAnchor(name: "max", transform: hitTestResult.worldTransform)
        session.add(anchor: anchor)
        
        // Send the anchor info to peers, so they can place the same content.
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else { fatalError("can't encode anchor") }
        self.multipeerSession.sendToAllPeers(data)
    }
    
    
    // MARK: - Multiuser shared session
    
    /// - Tag: GetWorldMap
    @IBAction func shareSession(_ button: UIButton) {
        print("send")
        session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error1: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    func loadRedPandaModel(_ anchorName: String) -> SCNNode {
        //let sceneURL = Bundle.main.url(forResource: "max", withExtension: "scn", subdirectory: "Assets.scnassets")!
        if VirtualObjectARView.modelName != nil
        {
            let sceneURL = Bundle.main.url(forResource: VirtualObjectARView.modelName, withExtension: "scn", subdirectory: "Models.scnassets")!
            let referenceNode = SCNReferenceNode(url: sceneURL)!
            referenceNode.load()
            return referenceNode
        }
        else
        {
            print("anchor Name is")
            print(anchorName)
            let sceneURL = Bundle.main.url(forResource: anchorName, withExtension: "scn", subdirectory: "Models.scnassets")!
            let referenceNode = SCNReferenceNode(url: sceneURL)!
            referenceNode.load()
            return referenceNode
        }
    }

    
    
    @IBAction func moreModels(_ sender: UIButton) // 按下“更多”按鈕
    {
        
    }
}
