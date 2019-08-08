//
//  WebView.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/8/3.
//  Copyright © 2019 Apple. All rights reserved.
//
// Reference: https://southernerd.us/blog/tutorial/2017/04/15/Download-Manager-Tutorial.html#downloadingFromURL

import UIKit
import WebKit


class WebView: UIViewController, WKNavigationDelegate, UIWebViewDelegate
{
    @IBOutlet weak var webView: UIWebView!
    override func viewDidLoad()
    {
        super.viewDidLoad()
        webView.delegate = self
        webView.loadRequest(URLRequest(url: URL(string: "https://ttyl.ddns.net/ttyl/model/uploads/leroy/")!))
    }
    
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool
    {
        title = "DIMENSION"
        
        print(request)
        if requestIsDownloadable(request: request)
        {
            initializeDownload(download: request)
            
            
            return false
        }
        
        
        return true
    }
    
    
    func requestIsDownloadable( request: URLRequest) -> Bool
    {
        let requestString : NSString = (request.url?.absoluteString)! as NSString
        let fileType : String = requestString.pathExtension
        print(fileType)
        let isDownloadable : Bool = (
            (fileType.caseInsensitiveCompare("zip") == ComparisonResult.orderedSame) ||
                (fileType.caseInsensitiveCompare("rar") == ComparisonResult.orderedSame) ||
                (fileType.caseInsensitiveCompare("usdz") == ComparisonResult.orderedSame) ||
                (fileType.caseInsensitiveCompare("scn") == ComparisonResult.orderedSame)
        )
        
        
        return isDownloadable
    }
    
    
    func initializeDownload( download: URLRequest)
    {
        let downloadAlertController : UIAlertController = UIAlertController(title: "Download Detected!", message: "Would you like to download this file?", preferredStyle: UIAlertControllerStyle.alert)
        
        let cancelAction : UIAlertAction = UIAlertAction(title: "Nope", style: UIAlertActionStyle.cancel, handler:
        {(alert: UIAlertAction!) in
            print("Download Cancelled.")
        })
        
        let okAction : UIAlertAction = UIAlertAction(title: "Yes!", style: UIAlertActionStyle.default, handler:
        {(alert: UIAlertAction!) in
            let downloadingAlertController : UIAlertController = UIAlertController(title: "Downloading...", message: "Please wait while your file downloads.\nThis alert will disappear when it's done.", preferredStyle: UIAlertControllerStyle.alert)
            self.present(downloadingAlertController, animated: true, completion: nil)
            
            do
            {
                let urlToDownload : NSString = (download.url?.absoluteString)! as NSString
                let url : NSURL = NSURL(string: urlToDownload as String)!
                let urlData : NSData = try NSData.init(contentsOf: url as URL)
                
                if urlData.length > 0
                {
                    let paths : Array = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                    let documentsDirectory : String = paths[0]
                    let filePath : String = String.localizedStringWithFormat("%@/%@", documentsDirectory, urlToDownload.lastPathComponent)
                    
                    urlData.write(toFile: filePath, atomically: true)
                    downloadingAlertController.dismiss(animated: true, completion: nil)
                }
            }
            catch let error as NSError
            {
                print(error.localizedDescription)
            }
        })
        
        downloadAlertController.addAction(cancelAction)
        downloadAlertController.addAction(okAction)
        self.present(downloadAlertController, animated: true, completion: nil)
    }
}
