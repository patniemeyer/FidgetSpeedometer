//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface OpenCVSampleFilter: NSObject

+ (UIImage*) pixelizeWithOpenCV: (UIImage*) inputImage scale:(int)scale;
+ (UIImage*) processSampleBuffer: (CMSampleBufferRef)sampleBuffer scale:(int)scale;

@end
