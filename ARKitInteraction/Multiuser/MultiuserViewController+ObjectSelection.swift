import UIKit
import ARKit

extension MultiuserViewController: VirtualObjectSelectionViewControllerDelegate {
    /**
     Adds the specified virtual object to the scene, placed at the world-space position
     estimated by a hit test from the center of the screen.
     
     - Tag: PlaceVirtualObject
     */
    func placeVirtualObject(_ virtualObject: VirtualObject) {
        guard focusSquare.state != .initializing else {
            statusViewController.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
            if let controller = objectsViewController {
                virtualObjectSelectionViewController(controller, didDeselectObject: virtualObject) // 在這裡 load model
            }
            return
        }
        
        virtualObjectInteraction.translate(virtualObject, basedOn: screenCenter, infinitePlane: false, allowAnimation: false)
        virtualObjectInteraction.selectedObject = virtualObject
        
        updateQueue.async {
            self.sceneView.scene.rootNode.addChildNode(virtualObject)
            self.sceneView.addOrUpdateAnchor(for: virtualObject)
        }
    }

    // MARK: - VirtualObjectSelectionViewControllerDelegate
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didSelectObject object: VirtualObject) {
        let selectedModelName = object.referenceURL.lastPathComponent.replacingOccurrences(of: ".scn", with: "")
       /* if VirtualObjectLoader.loadedObjects.count>0
        {
            for i in 0...VirtualObjectLoader.loadedObjects.count-1
            {
                if selectedModelName==VirtualObjectLoader.loadedObjects[i].modelName
                {
                    dup_load=true
                }
            }
        }*/
        MultiuserViewController.statusBarMessage = "Selected Object: "
        MultiuserViewController.statusBarMessage += selectedModelName
        MultiuserViewController.message = MultiuserViewController.statusBarMessage
        statusViewController.showMessage(MultiuserViewController.message, autoHide: false)
        print(MultiuserViewController.message)
        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            do {
                let scene = try SCNScene(url: object.referenceURL, options: nil)  // 使用該 object 的 referenceURL 來載入 model
                self.sceneView.prepare([scene], completionHandler: { _ in
                    DispatchQueue.main.async {
                        self.hideObjectLoadingUI()
                        self.placeVirtualObject(loadedObject)
                        loadedObject.isHidden = false
                    }
                })
            } catch {
                fatalError("Failed to load SCNScene from object.referenceURL")
            }
            
        })

        displayObjectLoadingUI()
    }
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didDeselectObject object: VirtualObject) {
       /* guard let objectIndex = VirtualObjectLoader.loadedObjects.index(of: object) else {
            fatalError("Programmer error: Failed to lookup virtual object in scene.")
        }
        virtualObjectLoader.removeVirtualObject(at: objectIndex)
        
       virtualObjectInteraction.selectedObject = nil
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }*/
        var selectedModelName = object.referenceURL.lastPathComponent.replacingOccurrences(of: ".scn", with: "")
        MultiuserViewController.message = "Selected Object: "
        MultiuserViewController.message+=selectedModelName
        MultiuserViewController.message = MultiuserViewController.statusBarMessage
        statusViewController.showMessage(MultiuserViewController.message, autoHide: false)
        print(MultiuserViewController.message)
        dup_load = true
        loadModel(selectedModelName)
        /*print(object.referenceURL)
        print(object.referenceURL.scheme)
        print(object.referenceURL.host)
        print(object.referenceURL.path)
        print(object.referenceURL.query)
        print(object.referenceURL.pathComponents)*/
        /*virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            do {
                let scene = try SCNScene(url:object.referenceURL, options: nil)  // 使用該 object 的 referenceURL 來載入 model
                self.sceneView.prepare([scene], completionHandler: { _ in
                    DispatchQueue.main.async {
                        self.hideObjectLoadingUI()
                        self.placeVirtualObject(loadedObject)
                        loadedObject.isHidden = false
                    }
                })
            } catch {
                fatalError("Failed to load SCNScene from object.referenceURL")
            }
            
        })
        displayObjectLoadingUI()*/
    }
    // MARK: Object Loading UI

    func displayObjectLoadingUI() {
        // Show progress indicator.
        spinner.startAnimating()
        
        addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])

        addObjectButton.isEnabled = false
        isRestartAvailable = false
    }

    func hideObjectLoadingUI() {
        // Hide progress indicator.
        spinner.stopAnimating()

        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])

        addObjectButton.isEnabled = true
        isRestartAvailable = true
    }
}
