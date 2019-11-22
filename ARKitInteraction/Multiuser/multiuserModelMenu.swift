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
    @IBAction func cancelbutton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    static var deleteModel = false // 選單選擇刪除 model
    
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
            self.dismiss(animated: true, completion: nil)
        }
        
        alertController.addAction(deleteAction)
        
        // 建立按鈕2
        let moveAction = UIAlertAction(title: "移動", style: .default)
        { (_) in
            multiuserModelMenu.deleteModel = true
        }
        
        alertController.addAction(moveAction)
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        {(_) in
        }
        
        alertController.addAction(cancelAction)

        // 顯示提示框
        self.present(alertController, animated: true, completion: nil)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle
    {
        return UITableViewCellEditingStyle.delete
    }
}
