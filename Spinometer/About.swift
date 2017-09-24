//
//  About.swift
//  FidgetSpeedometer
//

import Foundation

class About : UIWebView, UIWebViewDelegate
{
    init()
    {
        print("about init")
        super.init(frame: CGRect.zero)
        
        self.delegate = self
        
        let filePath = Bundle.main.path(forResource: "about", ofType: "html")!
        let html =  try! String(contentsOfFile: filePath, encoding: .utf8)
        loadHTMLString(html, baseURL: nil)
        
        // clear background
        self.backgroundColor = .clear
        self.isOpaque = false
        
        //self.scalesPageToFit = true
        self.scrollView.isScrollEnabled = false
    }
    
    // Support opening links with safari
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if navigationType == UIWebViewNavigationType.linkClicked {
            //UIApplication.shared.openURL(request.url!)
            UIApplication.shared.open(request.url!, options: [:], completionHandler: nil)
            return false
        }
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
