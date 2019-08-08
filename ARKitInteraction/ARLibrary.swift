//
//  ARLibrary.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/8/8.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import Foundation
import QuickLook

/// Reference: https://www.appcoda.com.tw/ar-quick-look/
class ARLibrary: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, QLPreviewControllerDelegate, QLPreviewControllerDataSource
{
    @IBOutlet var collectionView: UICollectionView!

    /// 從 Documents 中抓 model 列表
    var models : [String]
    {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path:String = documentsURL.path  // URL 轉成 String
        let enumerator = FileManager.default.enumerator(atPath: path)
        let filePaths = enumerator?.allObjects as! [String]
        var scnFilePaths = [String]()
        for path in filePaths
        {
            let urlPath = URL(string: path)  // String 轉成 URL
            if urlPath?.pathExtension == "usdz" || urlPath?.pathExtension == "scn" // 只抓取副檔名為 "usdz" 以及 "scn" 的檔案
            {
                var file = String(urlPath?.lastPathComponent.replacingOccurrences(of: ".scn", with: "") ?? "")
                file = file.replacingOccurrences(of: ".usdz", with: "")
                if file != ""  // 因為 31 行的關係，可能為空值
                {
                    scnFilePaths.append(file)
                }
            }
        }
        return scnFilePaths
    }
    
    var thumbnails = [UIImage]()
    var thumbnailIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for model in models {
            if let thumbnail = UIImage(named: "\(model).jpg") {
                thumbnails.append(thumbnail)
            }
        }
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return models.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LibraryCell", for: indexPath) as? LibraryCollectionViewCell
        if let cell = cell {
            //cell.modelThumbnail.image = thumbnails[indexPath.item]
            cell.modelThumbnail.image = thumbnails[3]  // 列表 model 圖片
            cell.modelTitle.text = models[indexPath.item]  // 列表 model 名稱
            //cell.modelTitle.text = title.capitalized
        }
        
        return cell!
    }
    
    /// 我們設定 thumbnailIndex 的值給使用者點選的 index。這幫助 Quick Look 的 Data Source 方法知道要使用哪一個模型。如果你在 App 中，使用 Quick Look 去預覽任何種類的檔案，你就總是會在 QLPreviewController 顯示預覽。無論檔案是文件、影像、或我們這次需要的 3D 模型，QuickLook 框架都會要求你在 QLPreviewController 中顯示。我們設定 previewController 的 data source 與 delegates 的值為 self，然後顯示這些物件
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        thumbnailIndex = indexPath.item
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        if isscn == true  // scn 檔，顯示錯誤訊息
        {
            let downloadAlertController : UIAlertController = UIAlertController(title: "無法預覽", message: "目前 Apple Quick View 不支援此檔案類型的預覽", preferredStyle: UIAlertControllerStyle.alert)
            
            let cancelAction : UIAlertAction = UIAlertAction(title: "了解", style: UIAlertActionStyle.cancel, handler:
            {(alert: UIAlertAction!) in
                //print("Download Cancelled.")
            })
            downloadAlertController.addAction(cancelAction)
            present(downloadAlertController, animated: true, completion: nil)
        }
        else // usdz 檔，使用 Quick View 預覽
        {
            present(previewController, animated: true)
        }
    }
    
    /// 在第一個函式中，我們被問到一次要顯示多少個物件。既然我們要瀏覽一個3D模型，在此我們將回傳值設定為 1
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    /// 檢查是否為 usdz 以外的檔案
    var isscn : Bool
    {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path:String = documentsURL.path  // URL 轉成 String
        let enumerator = FileManager.default.enumerator(atPath: path)
        let filePaths = enumerator?.allObjects as! [String]
        for filepath in filePaths
        {
            let urlPath = URL(string: filepath)  // String 轉成 URL
            if urlPath?.pathExtension == "usdz" || urlPath?.pathExtension == "scn" // 只抓取副檔名為 "usdz" 以及 "scn" 的檔案
            {
                let modelLocation: String = urlPath!.path
                if modelLocation.contains(models[thumbnailIndex])
                {
                    print(modelLocation)
                    if !modelLocation.contains(".usdz")
                    {
                        return true
                    }
                    else
                    {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    /// 在第二個函式中，我們被問到當游標指向某個物件時，應該預覽哪種檔案。我們定義一個名為 url 的常數，亦是我們儲存 .usdz 的路徑。然後，我們回傳此檔案為 QLPreviewItem
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var path:String = documentsURL.path  // URL 轉成 String
        let enumerator = FileManager.default.enumerator(atPath: path)
        let filePaths = enumerator?.allObjects as! [String]
        for filepath in filePaths
        {
            let urlPath = URL(string: filepath)  // String 轉成 URL
            if urlPath?.pathExtension == "usdz" || urlPath?.pathExtension == "scn" // 只抓取副檔名為 "usdz" 以及 "scn" 的檔案
            {
                let modelLocation: String = urlPath!.path
                if modelLocation.contains(models[thumbnailIndex])
                {
                    path = path + "/" + filepath  // 結合出完整的路徑
                    return URL(string: path)! as QLPreviewItem  // 傳回選擇的檔案的路徑
                }
            }
        }
        return documentsURL as QLPreviewItem
    }
}
