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
    
    // mark if it is running Multiuser mode
    static var multiuser: Bool = true
    
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
    
    static var multipeerSession: MultipeerSession!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        MultiuserViewController.multiuser = true
        MultiuserViewController.multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        
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
        
        // let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSceneTap(_:)))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObjectSelectionViewController))
        // Set the delegate to ensure this gesture is only used when there are no virtual objects in the scene.
        tapGesture.delegate = self
        sceneView.addGestureRecognizer(tapGesture)
        
        if multiuserloadScene // 收到 world map 更新
        {
            do
            {
                let file = try Data(contentsOf: multiuserselectedSceneURL!)
                if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: file)
                {
                    // Run the session with the received world map.
                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = .horizontal
                    configuration.initialWorldMap = worldMap
                    multiuserloadScene = false
                }
            }
            catch
            {
                print("error loading map")
                print(error.localizedDescription)
            }
        }
        
        //multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        VirtualObject.availableObjects = VirtualObject.updateReferenceURL() // 每次進入首頁時更新 referenceURL -> 為了讓選單不要出現下載項目
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
    var modelProvider: MCPeerID?
    
    
    /// - Tag: ReceiveData
    static var received: Bool = false  // 是否有收到地圖
    var receivedMap: Bool = false // 是否有收到 worldMap -> 開啟即時傳送功能
    
    func receivedData(_ data: Data, from peer: MCPeerID) {
        if !receivedMap  // 收到 world map 更新
        {
            do
            {
                if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                    // Run the session with the received world map.
                    MultiuserViewController.received = true
                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = .horizontal
                    configuration.initialWorldMap = worldMap
                    sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                    
                    // Remember who provided the map for showing UI feedback.
                    mapProvider = peer
                    receivedMap = true
                }
            }
            catch
            {
                print("can't decode data recieved from \(peer)")
            }
        }
        else  // 收到 model 更新
        {
            do
            {
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                    // Add anchor to the session, ARSCNView delegate adds visible content.
                    MultiuserViewController.received = true
                    modelProvider = peer
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
        
    }
    
    /// - Tag: PlaceCharacter
    @objc func handleSceneTap(_ sender: UITapGestureRecognizer) {
        // Hit test to find a place for a virtual object.
        guard let hitTestResult = sceneView
            .hitTest(sender.location(in: sceneView), types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
            .first
            else { return }
        
        // Place an anchor for a virtual character. The model appears in renderer(_:didAdd:for:).
        let anchor = ARAnchor(name: "VirtualObjectARView.modelName", transform: hitTestResult.worldTransform)
        session.add(anchor: anchor)
        
        // Send the anchor info to peers, so they can place the same content.
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else { fatalError("can't encode anchor") }
        MultiuserViewController.multipeerSession.sendToAllPeers(data)
    }
    
    
    // MARK: - Multiuser shared session
    
    /// - Tag: GetWorldMap
    @IBAction func shareSession(_ button: UIButton) {
        session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error1: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            MultiuserViewController.multipeerSession.sendToAllPeers(data)
        }
    }

    // MARK: - AR session management
    
    func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where !MultiuserViewController.multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = MultiuserViewController.multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
        case .limited(.initializing) where modelProvider != nil,
             .limited(.relocalizing) where modelProvider != nil:
            message = "Received model from \(modelProvider!.displayName)."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        statusViewController.showMessage(message, autoHide: true)
    }
    
    @IBAction func moreModels(_ sender: UIButton) // 按下“更多”按鈕
    {
        
    }
    
    
    /// 根據 modelName 載入模型 (同時運作在放置以及下載模型中）
    func loadModel(_ anchorName: String) -> SCNNode {
        //let sceneURL = Bundle.main.url(forResource: "max", withExtension: "scn", subdirectory: "Assets.scnassets")!
        if VirtualObjectARView.modelName != nil  // "+" 放置模型的情況
        {
            let referenceNode = SCNReferenceNode(url: VirtualObjectARView.modelURL)!
            referenceNode.load()
            return referenceNode
        }
        else // 從別人下載地圖載入模型的情況
        {
            /// 從內建的 Models.scnassets 中尋找所有模型，使用 anchorName 抓出該 model 的路徑
            var modelURL: URL?
            let documentsURL = Bundle.main.url(forResource: "Models.scnassets", withExtension: nil)!
            let path:String = documentsURL.path  // URL 轉成 String
            let enumerator = FileManager.default.enumerator(atPath: path)
            let filePaths = enumerator?.allObjects as! [String]
            for filepath in filePaths
            {
                if filepath.contains("usdz") || filepath.contains("scn") // 只抓取副檔名為 "usdz" 以及 "scn" 的檔案
                {
                    if filepath.contains(anchorName)
                    {
                        var newPath = "file:///private" + path + "/" + filepath  // 結合出完整的路徑
                        newPath = newPath.replacingOccurrences(of: " ", with: "%20")  // 修正路徑中有空格的問題
                        modelURL = URL(string: newPath)
                        break
                    }
                }
            }
            let referenceNode = SCNReferenceNode(url: modelURL!)!
            referenceNode.load()
            return referenceNode
        }
    }
    
    // MARK: - 場景控制選單
    @IBAction func sceneControl(_ sender: Any)
    {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let saveAction = UIAlertAction(title: "場景儲存", style: .default)
        {
            action -> Void in
            
            /// 加入 textField 讓使用者輸入想要儲存的場景名稱
            let controller = UIAlertController(title: "場景儲存", message: "請輸入想要儲存的場景名稱", preferredStyle: .alert)
            controller.addTextField { (textField) in
               textField.placeholder = "名稱"
            }
            
            /// 先輸入場景名稱後執行檔案寫入
            let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
               let name = controller.textFields?[0].text
                
                // 如果沒有輸入場景名稱則出現警告
                if name == ""
                {
                    let nameError : UIAlertController = UIAlertController(title: "場景儲存", message: "請輸入場景名稱！", preferredStyle: UIAlertControllerStyle.alert)
                    
                    let cancelAction : UIAlertAction = UIAlertAction(title: "了解", style: UIAlertActionStyle.cancel, handler:
                    {(alert: UIAlertAction!) in
                    })
                    nameError.addAction(cancelAction)
                    self.present(nameError, animated: true, completion: nil)
                    return
                }
                                
                self.writeScene(sceneName: name ?? "")
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            
            controller.addAction(okAction)
            controller.addAction(cancelAction)
            self.present(controller, animated: true, completion: nil)
            
        }
        let readAction = UIAlertAction(title: "場景庫", style: .default)
        {
            action -> Void in
            // 切換 storyboard 到場景庫
            self.performSegue(withIdentifier: "multiusercameraToSceneLibrary", sender: self)  // storyboard 從 AR 相機切換到 Scene Library
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        actionSheet.addAction(saveAction)
        actionSheet.addAction(readAction)
        actionSheet.addAction(cancelAction)
        
        if let popoverController = actionSheet.popoverPresentationController {
          popoverController.sourceView = self.view
          popoverController.sourceRect = CGRect(x: 750, y: 50, width: 0, height: 0)
        }
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    /// 負責場景儲存
    func writeScene(sceneName: String)
    {
        session.getCurrentWorldMap
        {
            worldMap, error in
            guard let map = worldMap
                else { // 當場景的特徵不足時無法儲存，顯示提示訊息
                    print("Error1: \(error!.localizedDescription)")
                    let sceneError : UIAlertController = UIAlertController(title: "無法儲存場景", message: error!.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                    
                    let cancelAction : UIAlertAction = UIAlertAction(title: "了解", style: UIAlertActionStyle.cancel, handler:
                    {(alert: UIAlertAction!) in
                    })
                    sceneError.addAction(cancelAction)
                    self.present(sceneError, animated: true, completion: nil)
                    return
            }
            
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            
            // Create folder if not exist
            let fileManager = FileManager.default
            if let tDocumentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let filePath =  tDocumentDirectory.appendingPathComponent("scenes")
                if !fileManager.fileExists(atPath: filePath.path) {
                    do {
                        try fileManager.createDirectory(atPath: filePath.path, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        NSLog("Couldn't create document directory")
                    }
                }
            }
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var URL = documentsURL.appendingPathComponent("scenes")  // 加入指定檔案路徑
            URL = URL.appendingPathComponent(sceneName)
            
            if !FileManager.default.fileExists(atPath: URL.path) {
                print("File does NOT exist -- \(URL) -- is available for use")
                do {
                    print("Write scene")
                    try data.write(to: URL)
                }
                catch {
                    print("Error Writing scene: \(error)")
                }
            }
            else {
                print("This file exists -- something is already placed at this location")
            }
        }
    }
}
