//
//  Util.swift
//  FidgetSpeedometer
//
//  Created by Patrick Niemeyer on 9/21/17.
//

import Foundation

public func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x:lhs.x+rhs.x, y:lhs.y+rhs.y)
}
public func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x:lhs.x-rhs.x, y:lhs.y-rhs.y)
}

public func /(lhs: CGPoint, rhs: Float) -> CGPoint {
    return CGPoint(x:lhs.x/CGFloat(rhs), y:lhs.y/CGFloat(rhs))
}

public func *(lhs: CGPoint, rhs: Float) -> CGPoint {
    return CGPoint(x:lhs.x*CGFloat(rhs), y:lhs.y*CGFloat(rhs))
}

public func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
    return CGPoint(x:lhs.x*rhs, y:lhs.y*rhs)
}

public func *(lhs: CGRect, rhs: Float) -> CGRect {
    return lhs * Double(rhs)
}
public func *(lhs: CGRect, rhs: Double) -> CGRect {
    let s = CGFloat(rhs)
    return CGRect(x: lhs.origin.x * s, y: lhs.origin.y * s, width: lhs.width * s, height: lhs.height * s)
}

public func *(lhs: CGRect, rhs: CGFloat) -> CGRect {
    return CGRect(x: lhs.origin.x * rhs, y: lhs.origin.y * rhs, width: lhs.width * rhs, height: lhs.height * rhs)
}

public extension CGRect {
    public var center : CGPoint {
        return CGPoint(x:midX, y:midY)
    }
}
