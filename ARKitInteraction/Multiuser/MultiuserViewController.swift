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
    
    
    
    static var message: String = ""
    var node:SCNNode!
    static var multiuserloadScene = false
    // MARK: - UI Elements
    
    // 場景路徑
    var worldMap: URL =
    {
        // 如果沒有 scenes 資料夾，新增他
        let fileManager = FileManager.default
        if let tDocumentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath =  tDocumentDirectory.appendingPathComponent("scenes")
            if !fileManager.fileExists(atPath: filePath.path) {
                do {
                    try fileManager.createDirectory(atPath: filePath.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Couldn't create document directory")
                }
            }
        }
        
        do {
            var url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("scenes")
            return url
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
    // 完整場景路徑 (加上要儲存的檔案名稱)
    var worldMapURL: URL!
    
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
    lazy var virtualObjectInteraction = MultiuserVirtualObjectInteraction(sceneView: sceneView)
    
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
    
    func retrieveWorldMapData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            print("Error retrieving world map data.")
            return nil
        }
    }
    
    func unarchive(worldMapData data: Data) -> ARWorldMap? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
            let worldMap = unarchievedObject else { return nil }
        return worldMap
    }
    
    func resetTrackingConfiguration(with worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        if let worldMap = worldMap {
            configuration.initialWorldMap = worldMap
            print("Found saved world map.")
        } else {
            print("Move camera around to map your surrounding space.")
        }
        
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration, options: options)
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        MultiuserViewController.startMulti=false
        MultiuserViewController.updateWorldMapInMulti=false
        MultiuserViewController.multiuser = true
        MultiuserViewController.multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        dup_load = false
        MultiuserViewController.changeStatusBar = false
        MultiuserViewController.statusBarMessage = ""
        
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
        
        //multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        VirtualObject.availableObjects = VirtualObject.updateReferenceURL() // 每次進入首頁時更新 referenceURL -> 為了讓選單不要出現下載項目
        
        checkDelete()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        if MultiuserViewController.multiuserloadScene // 如果是讀取場景
        {
            guard let worldMapData = self.retrieveWorldMapData(from: multiuserSceneLibrary.multiuserselectedSceneURL),
                let worldMap = self.unarchive(worldMapData: worldMapData) else { return }
            self.resetTrackingConfiguration(with: worldMap)
            MultiuserViewController.multiuserloadScene = false
            VirtualObjectARView.modelName = nil
        }
        else // 正常開啟狀況
        {
            // Start the `ARSession`.
            resetTracking()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's AR session.
        session.pause()
    }
    
    // MARK: - Scene content setup
    
    var timer = Timer()
    static var showModelMenu = false
    
    func checkDelete(){
        // Scheduling timer to Call the function "checkDelete" with the interval of 1 seconds
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.longpressed_show), userInfo: nil, repeats: true)
    }
    
    func shareSessionForDeleteOrMove() {
        if MultiuserViewController.startMulti==true
        {
            session.getCurrentWorldMap { worldMap, error in
                guard let map = worldMap
                    else { print("Error1: \(error!.localizedDescription)"); return }
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    else { fatalError("can't encode map") }
                MultiuserViewController.multipeerSession.sendToAllPeers(data)
                MultiuserViewController.updateWorldMapInMulti = true
            }
        }
    }
    
    static var changeStatusBar = false
    
    @objc func longpressed_show(){
        if MultiuserViewController.changeStatusBar
        {
            statusViewController.showMessage(MultiuserViewController.message, autoHide: true)
            MultiuserViewController.changeStatusBar = false
        }
        if ARLibrary.arlibrary_to_view_updatetable==true
        {
            self.viewDidLoad()
            self.viewDidAppear(true)                    //直接更新列表
            ARLibrary.arlibrary_to_view_updatetable=false
        }
        if virtualObjectInteraction.is_longpressed==true
        {
            let alertController = UIAlertController(
                title: "模型操作",
                message: "",
                preferredStyle: .alert)
            
            /*
             建立[取消]按鈕
             注意 style .cancel 的按鈕在多選項畫面時，都會固定在「最下方」
             即使這段程式碼是在 最前面
             */
            let cancelAction = UIAlertAction(
                title: "取消",
                style: .cancel,
                handler: nil)
            
            alertController.addAction(cancelAction)
            
            // 建立按鈕1
            let okAction = UIAlertAction(title: "刪除",style: .default){ (_) in
                var index = 0
                for i in 0...VirtualObjectLoader.loadedObjects.count-1
                {
                    if VirtualObjectLoader.loadedObjects[i].modelName == self.virtualObjectInteraction.selectedObject?.modelName
                    {
                        index = i
                    }
                }
                VirtualObjectLoader.loadedObjects[index].removeFromParentNode()
                VirtualObjectLoader.loadedObjects[index].unload()
                VirtualObjectLoader.loadedObjects.remove(at: index)
                if let anchor = self.virtualObjectInteraction.selectedObject?.anchor {
                    self.sceneView.session.remove(anchor: anchor)
                }
                MultiuserViewController.statusBarMessage = ""
                self.virtualObjectInteraction.selectedObject = nil
                MultiuserVirtualObjectInteraction.moved = true
            }
            
            alertController.addAction(okAction)
            
            // 建立按鈕2
            let ok1Action = UIAlertAction(title: "移動",style: .default){ (_) in
                    MultiuserVirtualObjectInteraction.can_move=true
            }
            
            alertController.addAction(ok1Action)
            
            // 顯示提示框
            self.present(alertController, animated: true, completion: nil)
            virtualObjectInteraction.is_longpressed=false
        }
        
        if MultiuserVirtualObjectInteraction.moved
        {
            self.shareSessionForDeleteOrMove()
            MultiuserVirtualObjectInteraction.moved = false
        }
    }
    
    static var deleteModel = false // 從 modelMenu 收到刪除 model 的指令
    
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
        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = self.sceneView.smartHitTest(screenCenter)
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
    static var receivedata: Bool = true
    
    /// - Tag: ReceiveData
    static var startMulti: Bool = false // 開收到 worldMap -> 開始即時 (最新版)
    static var updateWorldMapInMulti: Bool = false // In startMulti 模式後，再更新或移動 model
    
    func receivedData(_ data: Data, from peer: MCPeerID) {
        if MultiuserViewController.receivedata
        {
            if !MultiuserViewController.startMulti // 收到 world map 更新 或 In startMulti 模式後，再更新或移動 model
            {
                do
                {
                    virtualObjectLoader.removeAllVirtualObjects()
                    if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                        // Run the session with the received world map.
                        let configuration = ARWorldTrackingConfiguration()
                        configuration.planeDetection = .horizontal
                        configuration.initialWorldMap = worldMap
                        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                        
                        // Remember who provided the map for showing UI feedback.
                        mapProvider = peer
                        MultiuserViewController.startMulti = true
                        VirtualObjectARView.modelName = nil
                        MultiuserViewController.updateWorldMapInMulti = false
                    }
                }
                catch
                {
                    print("can't decode map data recieved from \(peer)")
                }
            }
            else  // 收到 model 更新
            {
                do
                {
                    VirtualObjectARView.modelName = nil
                    if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                        // Add anchor to the session, ARSCNView delegate adds visible content.
                        modelProvider = peer
                        sceneView.session.add(anchor: anchor)
                    }
                    else {
                        print("unknown data recieved from \(peer)")
                    }
                }
                catch
                {
                    do // 傳過一次 worldmap 再傳一次的情況
                    {
                        virtualObjectLoader.removeAllVirtualObjects()
                        if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                            // Run the session with the received world map.
                            let configuration = ARWorldTrackingConfiguration()
                            configuration.planeDetection = .horizontal
                            configuration.initialWorldMap = worldMap
                            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                            
                            // Remember who provided the map for showing UI feedback.
                            mapProvider = peer
                            MultiuserViewController.startMulti = true
                            VirtualObjectARView.modelName = nil
                            MultiuserViewController.updateWorldMapInMulti = false
                        }
                    }
                    catch
                    {
                        print("can't decode map data recieved from \(peer)")
                    }
                }
            }
        }
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
            MultiuserViewController.startMulti = true
        }
    }

    // MARK: - AR session management
    
    static var statusBarMessage = ""
    func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        var state = ""
        if MultiuserViewController.statusBarMessage != ""
        {
            state = MultiuserViewController.statusBarMessage
        }
        switch trackingState {
        case .normal where !MultiuserViewController.multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = MultiuserViewController.multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            state += "\nConnected with \(peerNames)."
            
        case .limited(.initializing) where modelProvider != nil,
             .limited(.relocalizing) where modelProvider != nil:
            state += "\nReceived model from \(modelProvider!.displayName)."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            state += "\nReceived map from \(mapProvider!.displayName)."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            print("")
            
        }
        MultiuserViewController.message = state
        statusViewController.showMessage(MultiuserViewController.message, autoHide: true)
        
    }
    @IBAction func moreModels(_ sender: UIButton) // 按下“更多”按鈕
    {
        
    }
    
    var dup_load=false
    /// 根據 modelName 載入模型 (同時運作在放置以及下載模型中）
    
    func loadModel(_ anchorName: String) -> SCNNode {
        //let sceneURL = Bundle.main.url(forResource: "max", withExtension: "scn", subdirectory: "Assets.scnassets")!
        print("dup load")
        print(dup_load)
         if VirtualObjectARView.modelName != nil  // "+" 放置模型的情況
        {
            let referenceNode = SCNReferenceNode(url: VirtualObjectARView.modelURL)!
            if (dup_load) // 重複放模型的狀況
            {
                let hitTestResult = sceneView
                    .hitTest(screenCenter, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
                    .first
                
                // Place an anchor for a virtual character. The model appears in renderer(_:didAdd:for:).
                print("pooh2"+VirtualObjectARView.modelName)
                let anchor = ARAnchor(name: VirtualObjectARView.modelName, transform: hitTestResult!.worldTransform)
                sceneView.session.add(anchor: anchor)
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                    else { fatalError("can't encode anchor") }
                MultiuserViewController.multipeerSession.sendToAllPeers(data)
            }
            //referenceNode.load()
            return referenceNode
        }
        else // 從別人下載地圖載入模型的情況
        {
            /// 從內建的 Models.scnassets 中尋找所有模型，使用 anchorName 抓出該 model 的路徑
            /*
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
            }*/
            
            var modelURL: URL?
            var documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            documentsURL = documentsURL.appendingPathComponent("Models.scnassets")  // 加入指定檔案路徑
            let path:String = documentsURL.path  // URL 轉成 String
            let enumerator = FileManager.default.enumerator(atPath: path)
            let filePaths = enumerator?.allObjects as! [String]
            var scnFilePaths = [String]()
            for filepath in filePaths
            {
                if filepath.contains("usdz") || filepath.contains("scn") // 只抓取副檔名為 "usdz" 以及 "scn" 的檔案
                {
                    if filepath.contains(anchorName)
                    {
                        var newPath = "file:///private" + path + "/" + filepath
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
                
                self.worldMapURL = self.worldMap.appendingPathComponent(name ?? "")
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
        let datamanager = UIAlertAction(title: "檔案管理員", style: .default)
        {
            action -> Void in
            // 切換 storyboard 到檔案管理員
            self.performSegue(withIdentifier: "modelmanager", sender: self)  // storyboard 從 AR 相機切換到檔案管理員
        }
        let return_to_menu = UIAlertAction(title: "回主畫面", style: .default)
        {
            action -> Void in
            // 切換 storyboard 到主畫面
            self.performSegue(withIdentifier: "initialize", sender: self)  // storyboard 從 AR 相機切換到 主畫面
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        actionSheet.addAction(saveAction)
        actionSheet.addAction(readAction)
        actionSheet.addAction(datamanager)
        actionSheet.addAction(return_to_menu)
        actionSheet.addAction(cancelAction)
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: 820, y: 980, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    
    /// 負責場景儲存
    func writeScene(sceneName: String)
    {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let worldMap = worldMap
                else { // 因為特徵不足，無法儲存場景
                print("Error1: \(error!.localizedDescription)")
                let sceneError : UIAlertController = UIAlertController(title: "無法儲存場景", message: error!.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                
                let cancelAction : UIAlertAction = UIAlertAction(title: "了解", style: UIAlertActionStyle.cancel, handler:
                {(alert: UIAlertAction!) in
                })
                sceneError.addAction(cancelAction)
                self.present(sceneError, animated: true, completion: nil)
                return
            }
            
            do {
                try self.archive(worldMap: worldMap)
                DispatchQueue.main.async {
                    print("World map is saved.")
                }
            } catch {
                fatalError("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    func archive(worldMap: ARWorldMap) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: self.worldMapURL, options: [.atomic])
    }
    
    func loadRedPandaModel() -> SCNNode {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var path:String = documentsURL.path  // URL 轉成 String
        let enumerator = FileManager.default.enumerator(atPath: path)
        let filePaths = enumerator?.allObjects as! [String]
        for filepath in filePaths
        {
            let urlPath = URL(string: filepath)  // String 轉成 URLma
           
            if (urlPath?.pathExtension == "usdz" || urlPath?.pathExtension == "scn" && (urlPath?.path.contains(VirtualObjectARView.modelName))!) // 只抓取副檔名為 "usdz" 以及 "scn" 的檔案
            {
                //var/mobile/Containers/Data/Application/09C3D7E3-B7A8-4EC0-B8A0-04E4E9E1F9D0/Documents/Models.scnassets/cup/cup.scn
                path = "file://"+path + "/" + filepath  // 結合出完整的路徑
                print(URL(string: path))
                let referenceNode = SCNReferenceNode(url: URL(string: path)!)!
                referenceNode.load()
                return referenceNode
            }
        }
        let sceneURL = Bundle.main.url(forResource: "max", withExtension: "scn", subdirectory: "Assets.scnassets")!
        print(sceneURL)
        let referenceNode = SCNReferenceNode(url: sceneURL)!
        referenceNode.load()
        return referenceNode
    }
}
