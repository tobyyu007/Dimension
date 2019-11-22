//
//  sceneManager.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/9/29.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

var loadScene = false  // 更新場景指示

class SceneLibrary: UITableViewController
{
    // MARK: - scene 列表抓取
    
    /// 儲存場景資訊
    var scenes: [String] = []
    
    /// 從 Documents 中抓 model 列表
    func getScenes()
    {
        let fileManager = FileManager.default
        var documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        documentsURL = documentsURL.appendingPathComponent("scenes")  // 加入指定檔案路徑
        
        // Create folder if not exist
        if !fileManager.fileExists(atPath: documentsURL.path) {
            do {
                try fileManager.createDirectory(atPath: documentsURL.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("Couldn't create document directory")
            }
        }
        
        let path:String = documentsURL.path  // URL 轉成 String
        let enumerator = FileManager.default.enumerator(atPath: path)
        let filePaths = enumerator?.allObjects as! [String]
        var scnFilePaths = [String]()
        for filePath in filePaths
        {
            print(filePath)
            let newfilePath = filePath.replacingOccurrences(of: " ", with: "%20")  // 修正路徑中有空格的問題
            let urlPath = URL(string: newfilePath)  // String 轉成 URL
            let file = String(urlPath?.lastPathComponent.replacingOccurrences(of: ".dim", with: "") ?? "")
            if file != ""
            {
                scnFilePaths.append(file)
            }
        }
        scenes = scnFilePaths
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getScenes()
        
        navigationItem.rightBarButtonItem = editButtonItem
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
        return scenes.count
    }
        
        
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        // 將 scenes 中的列表顯示在 tableView
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = scenes[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        // 設定支援編輯
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            // 刪除 tableView 中的列表
            let fileName = scenes[indexPath.row] // 要刪除的檔案名稱
            scenes.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // 刪除實際的檔案
            var documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            documentsURL = documentsURL.appendingPathComponent("scenes")  // 加入指定檔案路徑
            documentsURL = documentsURL.appendingPathComponent(fileName)
            var path:String = documentsURL.path  // URL 轉成 String
            
            // 嘗試刪除檔案
            do
            {
                try FileManager.default.removeItem(atPath: path)
            }
            catch let error as NSError
            {
                print(error.localizedDescription)
            }
        }
    }
    
    static var selectedSceneURL: URL!
    
    /// 選擇了一個項目
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let fileName = scenes[indexPath.row] // 要刪除的檔案名稱
        var documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        documentsURL = documentsURL.appendingPathComponent("scenes")  // 加入指定檔案路徑
        documentsURL = documentsURL.appendingPathComponent(fileName)
        
        SceneLibrary.selectedSceneURL = documentsURL
        loadScene = true
        performSegue(withIdentifier: "backToCamera", sender: self)  // 切換 storyboard 回 AR 相機畫面
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle
    {
        return UITableViewCellEditingStyle.delete
    }
}
