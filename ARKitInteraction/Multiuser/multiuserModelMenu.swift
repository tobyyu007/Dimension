//
//  multiuserModelMenu.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/11/21.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import ARKit
import SceneKit

class multiuserModelMenu: UITableViewController
{
    @IBOutlet var sceneView: VirtualObjectARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(MultiuserVirtualObjectInteraction.anchor_name)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        MultiuserVirtualObjectInteraction.anchor_name = []
        MultiuserVirtualObjectInteraction.objectLocation = []
    }
    
    // MARK: - Table view 設定、顯示、操作
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        // return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        // return the number of rows
        return MultiuserVirtualObjectInteraction.anchor_name.count
    }
        
        
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // 將 anchor name 中的列表顯示在 tableView
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = MultiuserVirtualObjectInteraction.anchor_name[indexPath.row]
        return cell
    }
    
    static var delModelName: String = ""
    
    /// 選擇了一個項目
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let modelName = MultiuserVirtualObjectInteraction.anchor_name[indexPath.row] // 要刪除的檔案名稱
        let alertController = UIAlertController(
            title: "模型操作",
            message: "選擇的模型名稱：" + modelName,
            preferredStyle: .alert)
        
        // 建立按鈕1
        let deleteAction = UIAlertAction(title: "刪除", style: .destructive){ (_) in
            multiuserModelMenu.delModelName = modelName
            MultiuserViewController.deleteModel = true
        }
        
        alertController.addAction(deleteAction)
        
        // 建立按鈕2
        let moveAction = UIAlertAction(
            title: "移動",
            style: .default,
            handler: nil)
        
        alertController.addAction(moveAction)
        
        let cancelAction = UIAlertAction(
            title: "取消",
            style: .cancel,
            handler: nil)
        
        alertController.addAction(cancelAction)

        // 顯示提示框
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle
    {
        return UITableViewCellEditingStyle.delete
    }
}
