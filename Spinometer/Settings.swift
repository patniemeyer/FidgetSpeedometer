//
//  Settings.swift
//  FidgetSpeedometer
//
//  Created by Patrick Niemeyer on 9/21/17.
//

import Foundation
import Eureka

class SettingsCarouselItemView : CarouselItemView
{
    let settings: SettingsFormViewController
    let about: UIWebView
    
    init() {
        settings = Settings.shared.fvc
        about = About()
        
        super.init(mode: .about)
        
        addSubview(settings.view)
        addSubview(about)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        
        let iPad1x = UIScreen.main.bounds.height <= 480
        // should use bounds and center here
        let pad = 32
        if iPad1x {
            // 1x on old iPad
            settings.view.frame = bounds
        } else {
            settings.view.frame = bounds.insetBy(dx: CGFloat(pad), dy: 150).offsetBy(dx:0, dy:-100)
        }
        
        // Properly sizing has a problem: The web view shrinks
        // when laid out at smaller sizes and never resizes larger
        // don't know why... so just giving it a fixed size.
        if iPad1x {
            about.frame = CGRect(x:5, y:250, width: 250, height: 200)
        } else {
            about.frame = CGRect(x:pad, y:270, width: 290, height: 200)
        }
        about.isHidden = bounds.height < 420
        /*
        about.bounds = settings.view.frame
        about.center = bounds.center + CGPoint(x:0, y:100)
        about.scrollView.contentSize = about.bounds.size
        print("about bounds=", about.bounds)
        print("about contentSize =", about.scrollView.contentSize)
        about.contentMode = .scaleToFill
        print("about scrollview size = ", about.scrollView.frame)
        about.scalesPageToFit = true
        */
        
        super.layoutSubviews()
    }
}

class SettingsFormViewController : FormViewController
{
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class Settings
{
    static let shared = Settings()
    
    let fvc = SettingsFormViewController()
    let tintColor = UIColor(red: 135/255.0, green: 217/255.0, blue: 116/255.0, alpha: 1.0)
    // green: 87D974, blue: 260CE8
    
    var display: String = ""
    var colorFrequency: Bool = false
    var syncFrames: Bool = true
    
    init()
    {
        //fvc.view.alpha = 0.8
        //fvc.view.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        fvc.view.backgroundColor = .clear
        fvc.tableView?.backgroundView = nil // needed for alpha on iPhone
        fvc.tableView?.backgroundColor = UIColor.clear
        fvc.tableView?.isScrollEnabled = false
        
        // Normally would use defaultCellSetup but text color is changed based on setting so
        // we need to override
        SliderRow.defaultCellUpdate = { cell,row in
            cell.backgroundColor = UIColor.clear
            cell.textLabel?.textColor = UIColor.white
            cell.tintColor = self.tintColor
        }
        CheckRow.defaultCellUpdate = { cell,row in
            cell.backgroundColor = UIColor.clear
            cell.textLabel?.textColor = UIColor.white
            cell.tintColor = self.tintColor
        }
        ButtonRow.defaultCellUpdate = { cell,row in
            cell.backgroundColor = UIColor(white: 1.0, alpha: 0.7)
            cell.textLabel?.textColor = UIColor.white
            cell.tintColor = self.tintColor
        }
        SegmentedRow<String>.defaultCellUpdate = {
            cell, row in
            cell.backgroundColor = UIColor.clear
            cell.textLabel?.textColor = UIColor.white
        }
       
        // TODO: Can't figure out how to set the color of the header view text
        /*
        Section("Frequently Used") { section in
            print("section header =\(type(of:section.header!))")
        }*/
        fvc.form +++ Section()
        
        <<< SegmentedRow<String>(){
            let title = "Display"
            $0.title = title
            $0.options = ["RPM", "RPS"]
            self.display = UserDefaults.standard.string(forKey: title) ?? $0.options[0]
            $0.value = self.display
            $0.onChange { row in
                UserDefaults.standard.set(row.value!, forKey: title)
                self.display = row.value!
            }
            }.cellSetup { cell, row in
                cell.backgroundColor = .white // not working
                cell.tintColor = self.tintColor
        }
        
        <<< CheckRow() {
            let title = "Sync Framerate"
            $0.title = title
            if UserDefaults.standard.object(forKey: title) != nil {
                self.syncFrames = UserDefaults.standard.bool(forKey: title)
            }
            $0.value = self.syncFrames
            $0.onChange { row in
                UserDefaults.standard.set(row.value!, forKey: title)
                self.syncFrames = row.value!
            }
        }
            
        <<< CheckRow() {
            let title = "Color Frequency"
            $0.title = title
            self.colorFrequency = UserDefaults.standard.bool(forKey: title)
            $0.value = self.colorFrequency
            $0.onChange { row in
                UserDefaults.standard.set(row.value!, forKey: title)
                self.colorFrequency = row.value!
            }
        }
        
        
    }
    
}
