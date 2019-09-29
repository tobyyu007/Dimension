/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import WebKit

class ViewController: UIViewController{
    
    // MARK: IBOutlets
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var addObjectButton: UIButton!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        MultiuserViewController.multiuser = false
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
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObjectSelectionViewController))
        // Set the delegate to ensure this gesture is only used when there are no virtual objects in the scene.
        tapGesture.delegate = self
        sceneView.addGestureRecognizer(tapGesture)
        
        VirtualObject.availableObjects = VirtualObject.updateReferenceURL() // 每次進入首頁時更新 referenceURL -> 為了讓選單出現新的下載項目
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start the `ARSession`.
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

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
        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = self.sceneView.smartHitTest(screenCenter) {
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
            }
            addObjectButton.isHidden = false
            statusViewController.cancelScheduledMessage(for: .focusSquare)
        } else {
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
    
    // MARK: - 場景控制
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
            if let controller = self.storyboard?.instantiateViewController(withIdentifier: "Scene Library") {
                print(controller.storyboard ?? "nil")
                self.present(controller, animated: true, completion: nil)
            }
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
            URL = URL.appendingPathComponent(sceneName + ".dim") // 副檔名為 .dim

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
    
    
    @IBAction func moreModels(_ sender: UIButton) // 按下“更多”按鈕
    {
        
    }
    
}
