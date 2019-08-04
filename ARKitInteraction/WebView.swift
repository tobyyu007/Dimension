//
//  WebView.swift
//  ARKitInteraction
//
//  Created by Toby on 2019/8/3.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import WebKit

class WebView: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    
    override func loadView() {
        webView = WKWebView()
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: "https://developer.apple.com/augmented-reality/quick-look/")!
        webView.load(URLRequest(url: url))
        
        // 2
        let refresh = UIBarButtonItem(barButtonSystemItem: .refresh, target: webView, action: #selector(webView.reload))
        toolbarItems = [refresh]
        navigationController?.isToolbarHidden = false
        
        let goBack = UIBarButtonItem(barButtonSystemItem: .refresh, target: webView, action: #selector(webView.goBack))
        //toolbarItems = [goBack]
        //navigationItem.rightBarButtonItem = [goBack]
        navigationController?.isToolbarHidden = false
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        title = webView.title
    }
}
