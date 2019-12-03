import ARKit

extension MultiuserViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        let isAnyObjectInView = VirtualObjectLoader.loadedObjects.contains { object in
            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
        }
        
        DispatchQueue.main.async {
            self.virtualObjectInteraction.updateObjectToCurrentTrackingPosition()
            self.updateFocusSquare(isObjectVisible: isAnyObjectInView)
        }
        
        // If the object selection menu is open, update availability of items
        if objectsViewController != nil {
            let planeAnchor = focusSquare.currentPlaneAnchor
            objectsViewController?.updateObjectAvailability(for: planeAnchor)
        }
        
        // If light estimation is enabled, update the intensity of the directional lights
        if let lightEstimate = session.currentFrame?.lightEstimate {
            sceneView.updateDirectionalLighting(intensity: lightEstimate.ambientIntensity, queue: updateQueue)
        } else {
            sceneView.updateDirectionalLighting(intensity: 1000, queue: updateQueue)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        /*
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.statusViewController.cancelScheduledMessage(for: .planeEstimation)
            self.statusViewController.showMessage("SURFACE DETECTED")
            if self.virtualObjectLoader.loadedObjects.isEmpty {
                self.statusViewController.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
            }
        }
        updateQueue.async {
            for object in self.virtualObjectLoader.loadedObjects {
                object.adjustOntoPlaneAnchor(planeAnchor, using: node)
            }
        }
        */
        if(dup_load)
        {
            if let name = anchor.name, name.hasPrefix(VirtualObjectARView.modelName) {
                print("pooh3"+VirtualObjectARView.modelName)
                node.addChildNode(loadRedPandaModel())
                //node.addChildNode(loadModel(name))
                dup_load = false
            }
        }
        else  // "+" 放置模型的情況
        {
            DispatchQueue.main.async {
            if let name = anchor.name
            {
                node.addChildNode(self.loadModel(name))
            }
            }
        }
    }

    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        updateQueue.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                for object in VirtualObjectLoader.loadedObjects {
                    object.adjustOntoPlaneAnchor(planeAnchor, using: node)
                }
            } else {
                if let objectAtAnchor = VirtualObjectLoader.loadedObjects.first(where: { $0.anchor == anchor }) {
                    objectAtAnchor.simdPosition = anchor.transform.translation
                    objectAtAnchor.anchor = anchor
                }
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        statusViewController.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusViewController.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusViewController.cancelScheduledMessage(for: .trackingStateEscalation)
            
            // Unhide content after successful relocalization.
            VirtualObjectLoader.loadedObjects.forEach { $0.isHidden = false }
        }
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        switch frame.worldMappingStatus {
        
        case .notAvailable, .limited:
            sendMapButton.isEnabled = false
 
        case .extending:
            sendMapButton.isEnabled = !MultiuserViewController.multipeerSession.connectedPeers.isEmpty
        case .mapped:
            sendMapButton.isEnabled = !MultiuserViewController.multipeerSession.connectedPeers.isEmpty
        }
        //print(for: frame, trackingState: frame.camera.trackingState)
        if MultiuserViewController.receivedata == false
        {
            sendMapButton.isEnabled = false
        }
        mappingStatusLabel.text = frame.worldMappingStatus.description
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Hide content before going into the background.
        VirtualObjectLoader.loadedObjects.forEach { $0.isHidden = true }
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}
