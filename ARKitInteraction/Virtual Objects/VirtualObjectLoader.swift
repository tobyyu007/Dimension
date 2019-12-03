/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A type which loads and tracks virtual objects.
*/

import Foundation
import ARKit

/**
 Loads multiple `VirtualObject`s on a background queue to be able to display the
 objects quickly once they are needed.
*/
class VirtualObjectLoader {
    static var loadedObjects = [VirtualObject]()
    
    private(set) var isLoading = false
    
    // MARK: - Loading object

    /**
     Loads a `VirtualObject` on a background queue. `loadedHandler` is invoked
     on a background queue once `object` has been loaded.
    */
    func loadVirtualObject(_ object: VirtualObject, loadedHandler: @escaping (VirtualObject) -> Void) {
        isLoading = true
        
        VirtualObjectLoader.loadedObjects.append(object)
        print("new")
        for i in 0...VirtualObjectLoader.loadedObjects.count-1
        {
            print(VirtualObjectLoader.loadedObjects[i].modelName)
            print(VirtualObjectLoader.loadedObjects[i].anchor)
        }
        
        // Load the content into the reference node.
        DispatchQueue.global(qos: .userInitiated).async {
            object.reset()
            object.load()  // 使用此行 load model
            self.isLoading = false
            loadedHandler(object)
        }
    }
    
    // MARK: - Removing Objects
    
    func removeAllVirtualObjects() {
        // Reverse the indices so we don't trample over indices as objects are removed.
        for index in VirtualObjectLoader.loadedObjects.indices.reversed() {
            removeVirtualObject(at: index)
        }
        MultiuserViewController.statusBarMessage = ""
    }
    
    func removeVirtualObject(at index: Int) {
        guard VirtualObjectLoader.loadedObjects.indices.contains(index) else { return }
        
        VirtualObjectLoader.loadedObjects[index].removeFromParentNode()
        VirtualObjectLoader.loadedObjects[index].unload()
        VirtualObjectLoader.loadedObjects.remove(at: index)
    }
}
