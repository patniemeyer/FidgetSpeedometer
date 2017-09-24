//
//  UIImage+RGB.swift
//  RealtimeFilterExample
//

import Foundation

public extension UIImage {
    
    /*
    func getPixelColor(pos: CGPoint) -> UIColor
    {
        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let pixelInfo: Int = ((Int(self.size.width) * Int(pos.y)) + Int(pos.x)) * 4
        
        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    func getPixelValuesRGBA(x: Int, y: Int) ->
        (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)
    {
        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let pixelInfo: Int = ((Int(self.size.width) * Int(y)) + Int(x)) * 3
        
        let r = (data[pixelInfo]) 
        let g = (data[pixelInfo+1])
        let b = (data[pixelInfo+2])
        let a = (data[pixelInfo+3])
        
        return (red: r, green: g, blue: b, alpha: a)
    }*/
    
    func getPixelValueGrayscale(x: Int, y: Int) -> UInt8
    {
        let pixelData = self.cgImage!.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let pixelInfo: Int = ((Int(self.size.width) * Int(y)) + Int(x)) 
        return data[pixelInfo]
    }
    
}
