import UIKit
import ARKit



/// - Tag: VirtualObjectInteraction
class MultiuserVirtualObjectInteraction: NSObject, UIGestureRecognizerDelegate {
    
    
    /// Developer setting to translate assuming the detected plane extends infinitely.
    let translateAssumingInfinitePlane = true
    
    /// The scene view to hit test against when moving virtual content.
    let sceneView: VirtualObjectARView
    
    var currentAngleY: Float = 0.0
    
    var currentNode: SCNReferenceNode!

    var selectedObject: VirtualObject?
    
    static var can_move=false
    var is_longpressed=false
    static var moved = false // 移動完了 -> 重新 sendWorldMap (為了 startMulti 使用)
    
    private var trackedObject: VirtualObject? {
        didSet {
            guard trackedObject != nil else { return }
            selectedObject = trackedObject
        }
    }
    
    /// The tracked screen position used to update the `trackedObject`'s position in `updateObjectToCurrentTrackingPosition()`.
    private var currentTrackingPosition: CGPoint?

    init(sceneView: VirtualObjectARView) {
        self.sceneView = sceneView
        super.init()
        
        let panGesture = ThresholdPanGesture(target: self, action: #selector(didPan(_:)))
        panGesture.delegate = self
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        rotationGesture.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        longPressRecognizer.minimumPressDuration = 0.5
        longPressRecognizer.delaysTouchesBegan = true
        
        // Add gestures to the `sceneView`.
        sceneView.addGestureRecognizer(panGesture)
        sceneView.addGestureRecognizer(rotationGesture)
        sceneView.addGestureRecognizer(tapGesture)
        sceneView.addGestureRecognizer(longPressRecognizer)
    }
    
    // MARK: - Gesture Actions
    
    @objc
    func didPan(_ gesture: ThresholdPanGesture) {
        switch gesture.state {
        case .began:
            // Check for interaction with a new object.
            if let object = objectInteracting(with: gesture, in: sceneView) {
                trackedObject = object
            }
            
        case .changed where gesture.isThresholdExceeded:
            guard let object = trackedObject else { return }
            let translation = gesture.translation(in: sceneView)
            
            let currentPosition = currentTrackingPosition ?? CGPoint(sceneView.projectPoint(object.position))
            
            // The `currentTrackingPosition` is used to update the `selectedObject` in `updateObjectToCurrentTrackingPosition()`.
            currentTrackingPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)

            gesture.setTranslation(.zero, in: sceneView)
            
            MultiuserVirtualObjectInteraction.moved = true
            MultiuserViewController.statusBarMessage = "Selected Object: "
            MultiuserViewController.statusBarMessage += selectedObject?.modelName ?? ""
            MultiuserViewController.message = MultiuserViewController.statusBarMessage
            MultiuserViewController.changeStatusBar = true
            
        case .changed:
            // Ignore changes to the pan gesture until the threshold for displacment has been exceeded.
            break
            
        case .ended:
            // Update the object's anchor when the gesture ended.
            guard let existingTrackedObject = trackedObject else { break }
            sceneView.addOrUpdateAnchor(for: existingTrackedObject)
            fallthrough
            
        default:
            // Clear the current position tracking.
            currentTrackingPosition = nil
            trackedObject = nil
        }
    }

    // 拖移手勢，轉換 2D 點擊位置到 3D world map 上的相對位置
    @objc
    func updateObjectToCurrentTrackingPosition() {
        guard let object = trackedObject, let position = currentTrackingPosition else { return }
        translate(object, basedOn: position, infinitePlane: translateAssumingInfinitePlane, allowAnimation: true)
    }

    /// - Tag: didRotate
    @objc
    func didRotate(_ gesture: UIRotationGestureRecognizer) {
        guard gesture.state == .changed else { return }
        
        trackedObject?.eulerAngles.y -= Float(gesture.rotation)
        gesture.rotation = 0
        MultiuserVirtualObjectInteraction.moved = true
    }

    
    @objc
    func didTap(_ gesture: UITapGestureRecognizer) {
        let touchLocation = gesture.location(in: sceneView)
        
        if(!multiuserModelMenu.deleteModel) // 原本的模型移動方式
        {
            if let tappedObject = sceneView.virtualObject(at: touchLocation) {
                // Select a new object.
                selectedObject = tappedObject
            }
            else if let object = selectedObject {
                // Teleport the object to whereever the user touched the screen.
                if(MultiuserVirtualObjectInteraction.can_move==true){
                translate(object, basedOn: touchLocation, infinitePlane: false, allowAnimation: false)
                    sceneView.addOrUpdateAnchor(for: object)
                    MultiuserViewController.statusBarMessage = "Selected Object: "
                    MultiuserViewController.statusBarMessage += selectedObject?.modelName ?? ""
                    MultiuserViewController.message = MultiuserViewController.statusBarMessage
                    MultiuserViewController.changeStatusBar = true
                    MultiuserVirtualObjectInteraction.can_move=false
                    MultiuserVirtualObjectInteraction.moved = true
                }
            }
        }
    }
    
    
    static var objectLocation = [simd_float4x4]()
    static var anchor_name = [String]()
    static var modelAnchors = [ARAnchor]()
    static var modelCount = 0
    
    @objc
    /// 長按螢幕
    func longPressed(_ gesture: UILongPressGestureRecognizer)
    {
        if gesture.state != UIGestureRecognizer.State.ended {
            //When lognpress is start or running
        }
        else {
            /*  func getAnchor(_ worldMap: ARWorldMap)
             {
             //print(worldMap.anchors)
             let anchors = worldMap.anchors
             for index in 0...anchors.count-1
             {
             if(anchors[index].name != nil) // 當有加入模型才會顯示選單
             {
             MultiuserVirtualObjectInteraction.anchor_name.insert(anchors[index].name!, at: MultiuserVirtualObjectInteraction.modelCount)
             MultiuserVirtualObjectInteraction.objectLocation.insert(anchors[index].transform, at: MultiuserVirtualObjectInteraction.modelCount)
             MultiuserVirtualObjectInteraction.modelAnchors.insert(anchors[index], at: MultiuserVirtualObjectInteraction.modelCount)
             MultiuserVirtualObjectInteraction.modelCount += 1
             }
             }
             
             if(!MultiuserVirtualObjectInteraction.anchor_name.isEmpty)
             {
             MultiuserViewController.showModelMenu = true
             MultiuserVirtualObjectInteraction.modelCount = 0
             }
             }
             
             if(!MultiuserViewController.showModelMenu)
             {
             sceneView.session.getCurrentWorldMap {(worldMap, error) in
             guard let worldMap = worldMap else {
             return print("Error")
             }
             getAnchor(worldMap)
             }
             }*/
            
            is_longpressed=true
            /*var index = 0
            for i in 0...VirtualObjectLoader.loadedObjects.count-1
            {
                if VirtualObjectLoader.loadedObjects[i].modelName == selectedObject?.modelName
                {
                    index = i
                }
            }
            VirtualObjectLoader.loadedObjects[index].removeFromParentNode()
            VirtualObjectLoader.loadedObjects[index].unload()
            VirtualObjectLoader.loadedObjects.remove(at: index)
            if let anchor = selectedObject?.anchor {
                sceneView.session.remove(anchor: anchor)
            }
            selectedObject = nil*/
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow objects to be translated and rotated at the same time.
        return true
    }

    /// A helper method to return the first object that is found under the provided `gesture`s touch locations.
    /// - Tag: TouchTesting
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> VirtualObject? {
        for index in 0..<gesture.numberOfTouches {
            let touchLocation = gesture.location(ofTouch: index, in: view)
            
            // Look for an object directly under the `touchLocation`.
            if let object = sceneView.virtualObject(at: touchLocation) {
                return object
            }
        }
        
        // As a last resort look for an object under the center of the touches.
        return sceneView.virtualObject(at: gesture.center(in: view))
    }
    
    // MARK: - Update object position

    /// - Tag: DragVirtualObject
    func translate(_ object: VirtualObject, basedOn screenPos: CGPoint, infinitePlane: Bool, allowAnimation: Bool) {
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform,
            let result = sceneView.smartHitTest(screenPos,
                                                infinitePlane: infinitePlane,
                                                objectPosition: object.simdWorldPosition,
                                                allowedAlignments: object.allowedAlignments) else { return }
        
        let planeAlignment: ARPlaneAnchor.Alignment
        if let planeAnchor = result.anchor as? ARPlaneAnchor {
            planeAlignment = planeAnchor.alignment
        } else if result.type == .estimatedHorizontalPlane {
            planeAlignment = .horizontal
        } else if result.type == .estimatedVerticalPlane {
            planeAlignment = .vertical
        } else {
            return
        }
        let transform = result.worldTransform
        let isOnPlane = result.anchor is ARPlaneAnchor
        object.setTransform(transform,
                            relativeTo: cameraTransform,
                            smoothMovement: !isOnPlane,
                            alignment: planeAlignment,
                            allowAnimation: allowAnimation)
    }
}

/// Extends `UIGestureRecognizer` to provide the center point resulting from multiple touches.
extension UIGestureRecognizer {
    func center(in view: UIView) -> CGPoint {
        let first = CGRect(origin: location(ofTouch: 0, in: view), size: .zero)

        let touchBounds = (1..<numberOfTouches).reduce(first) { touchBounds, index in
            return touchBounds.union(CGRect(origin: location(ofTouch: index, in: view), size: .zero))
        }

        return CGPoint(x: touchBounds.midX, y: touchBounds.midY)
    }
}
