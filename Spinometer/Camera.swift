//
//  Camera.swift
//  FidgetSpeedometer
//

import Foundation
import UIKit
import AVFoundation
import ImageIO
import MSSimpleGauge

extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    {
        DispatchQueue.main.sync(execute: { () -> Void in
            handleImage(sampleBuffer: sampleBuffer)
        })
    }
    
    func setupCamera() -> Bool
    {
        self.session.sessionPreset = AVCaptureSessionPresetLow
        
        // Find the camera device
        var foundDevice : AVCaptureDevice?
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        for device in devices {
            if device.position == .back {
                foundDevice = device
                break
            }
        }
        guard let targetDevice = foundDevice else { print("no device"); return false }
        print("found device: ", targetDevice)
        
        // Find the format supporting our desired size and fps
        guard let formats = targetDevice.formats as? [AVCaptureDeviceFormat] else {
            print("no formats")
            return false
        }
        
        func getMaxframeRate(format: AVCaptureDeviceFormat) -> Int {
            guard let ranges = format.videoSupportedFrameRateRanges as? [AVFrameRateRange] else {
                print("can't find frame rate for format: ", format)
                return 0
            }
            let frameRates: AVFrameRateRange = ranges[0] // TODO?
            return Int(frameRates.maxFrameRate)
        }
        var foundFormat: AVCaptureDeviceFormat? // desired format if found
        var bestFormat: AVCaptureDeviceFormat? // fallback, highest fps at size if found
        for format in formats
        {
            print("format available: ", format)
            // Look for our 1280x720 size
            guard CMVideoFormatDescriptionGetDimensions(format.formatDescription).height == Int32(ViewController.format) else {
                continue
            }
            
            let maxFrameRate = getMaxframeRate(format: format)
            
            // Found target framerate?
            if maxFrameRate >= ViewController.fps {
                foundFormat = format
            }
            
            // Best so far?
            if let bestFormatFound = bestFormat, maxFrameRate > getMaxframeRate(format: bestFormatFound) {
                bestFormat = format
            } else {
                bestFormat = format
            }
            
        }
        
        // Did we find a suitable format?
        if foundFormat == nil {
            print("Desired format not found")
            if let bestFormat = bestFormat {
                print("Using best format found: \(bestFormat)")
                foundFormat = bestFormat
                ViewController.fps = getMaxframeRate(format: bestFormat)
            } else {
                return false
            }
        }
        
        print("chose format = \(String(describing: foundFormat))")
        
        // Set up the session
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: targetDevice)
        } catch {
            return false
        }
        
        if self.session.canAddInput(input) {
            self.session.addInput(input)
        } else {
            return false
        }
        
        var lockError: NSError?
        do {
            try targetDevice.lockForConfiguration()
            if let error = lockError {
                print("lock error: \(error.localizedDescription)")
                return false
            } else {
                if targetDevice.isSmoothAutoFocusSupported {
                    targetDevice.isSmoothAutoFocusEnabled = true
                }
                if targetDevice.isAutoFocusRangeRestrictionSupported {
                    targetDevice.focusMode = .continuousAutoFocus
                }
                
                targetDevice.activeFormat = foundFormat;
                
                targetDevice.activeVideoMinFrameDuration = CMTimeMake(1, Int32(ViewController.fps))
                targetDevice.activeVideoMaxFrameDuration = CMTimeMake(1, Int32(ViewController.fps))
                targetDevice.unlockForConfiguration()
            }
        } catch let error as NSError {
            lockError = error
        }
        
        let queue = DispatchQueue(label: "realtime_filter_example_queue", attributes: [])
        
        let output : AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : NSNumber(value: Int32(kCVPixelFormatType_32BGRA))]
        for type in output.availableVideoCVPixelFormatTypes {
            print("avail video type = ", type)
        }
        
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        
        if self.session.canAddOutput(output) {
            self.session.addOutput(output)
        } else {
            return false
        }
        
        for connection in output.connections as! [AVCaptureConnection] {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        
        return true
    }
    
    func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let newContext = CGContext(
            data: CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0),
            width: CVPixelBufferGetWidth(imageBuffer),
            height: CVPixelBufferGetHeight(imageBuffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue
        );

        let imageRef = newContext?.makeImage()
        let resultImage = UIImage(cgImage: imageRef!)
        
        // TODO(Pat)!!! Added ths speculatively to get rid of message
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return resultImage
    }
    
    public func now() -> UInt64 {
        return UInt64(NSDate().timeIntervalSince1970 * Double(1000))
    }
}


extension CVPixelBuffer
{
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")
        
        var _copy : CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &_copy)
        
        guard let copy = _copy else { fatalError() }
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))
        
        
        let copyBaseAddress = CVPixelBufferGetBaseAddress(copy)
        let currBaseAddress = CVPixelBufferGetBaseAddress(self)
        
        memcpy(copyBaseAddress, currBaseAddress, CVPixelBufferGetDataSize(self))
        
        CVPixelBufferUnlockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        
        return copy
    }
}
