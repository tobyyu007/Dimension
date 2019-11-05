//
//  Main.swift
//  ARKitInteraction
//
//  Created by Toby Yu on 2019/10/16.
//  Copyright © 2019 Apple. All rights reserved.
//
import ARKit
import SceneKit
import UIKit
import WebKit
import Foundation

class Main : UIViewController
{
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func start(_ sender: Any)
    {
        let multiusermode = UIAlertController(title:"模式選擇", message: "多人模式：允許 world map 傳送\n單人模式：其他使用者無法連入",preferredStyle: .alert)
        
        let okaction = UIAlertAction(title: "多人模式", style: .default) { (_) in
            MultiuserViewController.receivedata = true
            self.performSegue(withIdentifier: "mainToCamera", sender: self)
        }
        
        let denyaction = UIAlertAction(title: "單人模式", style: .default) { (_) in
            MultiuserViewController.receivedata = false
            self.performSegue(withIdentifier: "mainToCamera", sender: self)
        }
        
        multiusermode.addAction(okaction)
        multiusermode.addAction(denyaction)
        self.present(multiusermode, animated: true, completion: nil)
    }
}
