//
//  Carousel.swift
//  FidgetSpeedometer
//
//  Created by Patrick Niemeyer on 9/21/17.
//

import Foundation
import UIKit
import iCarousel

extension ViewController: iCarouselDataSource, iCarouselDelegate
{
    enum DisplayMode {
        case twoLobe, threeLobe, frequency, about
    }
    
    func initCarousel() {
        let carousel = iCarousel()
        
        carousel.delegate = self
        carousel.dataSource = self
        //carousel.type = .coverFlow
        carousel.type = .wheel
        carousel.decelerationRate = 0.5
        
        // The carousel will be centered in its frame but we want it to be large enough so that when we expand up the screen we can still swipe on it... So we have to make it a big frame centered down near the bottom.
        let bottomOffset: CGFloat = 110
        let height = (view.bounds.height - bottomOffset)*2.0
        carousel.frame = CGRect(x:0, y:0, width: view.bounds.width, height: height)
        carousel.center = CGPoint(x:view.bounds.width/2.0, y:view.bounds.height-bottomOffset)
        
        view.addSubview(carousel)
    }
    
    func carousel(_ carousel: iCarousel, viewForItemAt index: Int, reusing view: UIView?) -> UIView
    {
        if let view = view { return view }
        var mode: DisplayMode
        switch(index) {
        case 0:
            mode = .threeLobe
        case 1:
            mode = .twoLobe
        case 2:
            mode = .about
        case 3:
            mode = .frequency
        default:
            fatalError()
        }
        
        if mode == .about {
            return SettingsCarouselItemView()
        } else {
            return CarouselItemView(mode: mode)
        }
    }

    func numberOfItems(in carousel: iCarousel) -> Int {
        return 4
    }
    
    func carouselCurrentItemIndexDidChange(_ carousel: iCarousel) {
        self.displayMode = (carousel.currentItemView as! CarouselItemView).mode
    }
    
    func carousel(_ carousel: iCarousel, valueFor option: iCarouselOption, withDefault value: CGFloat) -> CGFloat
    {
        if (option == .fadeMin) {
            return 0
        } else
        if (option == .fadeMinAlpha) {
            return 0.35
        } else
        if (option == .fadeMax) {
            return 0
        }
        return value;
    }
    
    func carousel(_ carousel: iCarousel, itemTransformForOffset offset: CGFloat, baseTransform transform: CATransform3D) -> CATransform3D
    {
        return CATransform3DScale(transform, offset/10.0, offset/10.0, offset/10.0)
    }
    
    func carouselDidScroll(_ carousel: iCarousel)
    {
        // Expand itemview as we approach center
        let aboutItemIndex = 2
        let start: CGFloat = 0.5
        let offset = carousel.offsetForItem(at: aboutItemIndex)
        let frac = max(0,(start - abs(offset))/start) // 0 at start to 1 at center
        let itemView = carousel.itemView(at: aboutItemIndex) as! CarouselItemView
        let pad: CGFloat = 30
        let targetWidth = self.view.bounds.width - 2*pad
        let diffWidth = targetWidth-CarouselItemView.size.width
        let targetHeight = self.view.bounds.height - 2*pad
        let diffHeight = targetHeight-CarouselItemView.size.height
        /*
        if let itemSuperview = itemView.superview {
            print("\nview width=\(self.view.bounds.width)")
            print("itemView.bounds=\(itemView.bounds)")
            print("itemView.center=\(itemView.center)")
            print("itemSuperview.bounds=\(itemSuperview.bounds)")
            print("itemSuperview.center=\(itemSuperview.center)")
            itemView.backgroundColor = .green
            itemSuperview.backgroundColor = .blue
        }*/
        
        // Expand the bounds first
        itemView.bounds = CGRect( x:0, y:0,
            width: CarouselItemView.size.width+diffWidth*frac,
            height: CarouselItemView.size.height+diffHeight*frac)
        
        // Update the center position within superview
        if let itemSuperview = itemView.superview {
            // If we are expanding item view just blow up itemSuperview bounds to cover everything
            // (don't try moving itemSuperview center, I think carousel is updating it?)
            itemSuperview.bounds = itemView.bounds * (frac>0 ? 2.0 : 1.0)
            
            // itemSuperview bounds have changed but itemSuperview does not lay out itemView
            // so adjust for it.
            // item view center in itemSuperview is center of itemSuperview bounds
            itemView.center = itemSuperview.bounds.center - CGPoint(x:0, y:diffHeight/2.0*frac)
        }
        
        itemView.backgroundColor = UIColor.init(white: CarouselItemView.whiteColor, alpha: max(CarouselItemView.minAlpha, frac * 0.7))
    }
    
}

class CarouselItemView : UIView
{
    static let size = CGSize(width: 280, height: 185)
    static let whiteColor: CGFloat = 0.2
    static let minAlpha: CGFloat = 0.3
    
    let mode: ViewController.DisplayMode
    let imgView = UIImageView()
    
    init(mode: ViewController.DisplayMode)
    {
        self.mode = mode
        super.init(frame: CGRect.zero)
        
        //backgroundColor = .clear
        layer.cornerRadius = 45.0
        
        bounds = CGRect(x:0, y:0, width: CarouselItemView.size.width, height: CarouselItemView.size.height)
        
        backgroundColor = UIColor.init(white: CarouselItemView.whiteColor, alpha: CarouselItemView.minAlpha)
        
        imgView.bounds = CGRect(x:0, y:0, width: 85, height: 85)
        imgView.backgroundColor = .clear
        imgView.contentMode = .scaleAspectFit
        switch(mode) {
            case .threeLobe:
                imgView.image = #imageLiteral(resourceName: "np_fidget-spinner_1103438_77D561")
            case .twoLobe:
                imgView.image = #imageLiteral(resourceName: "np_spinner-toy_1224316_77D561")
            case .frequency:
                imgView.image = #imageLiteral(resourceName: "np_frequency_1240770_77D561")
            case .about:
                imgView.image = #imageLiteral(resourceName: "np_settings_924898_77D561")
        }
        addSubview(imgView)
    }
    
    override func layoutSubviews()
    {
        imgView.center = CGPoint(x:bounds.width/2, y:bounds.height-imgView.bounds.height+30.0)
        super.layoutSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

