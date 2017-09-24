//
//  OpenCVSampleFilter.m
//
//

#import "OpenCVSampleFilter-Bridging-Header.h"
#import "UIImage+OpenCV.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@implementation OpenCVSampleFilter

// @see : http://dev.classmethod.jp/smartphone/opencv-manga-2/

+ (IplImage *)iplImageFromCGImage:(CGImageRef)image
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *tempIplImage = cvCreateImage(cvSize((int)CGImageGetWidth(image), (int)CGImageGetHeight(image)), IPL_DEPTH_8U, 4);
    
    CGContextRef context = CGBitmapContextCreate(tempIplImage->imageData,
                                                 tempIplImage->width,
                                                 tempIplImage->height,
                                                 tempIplImage->depth,
                                                 tempIplImage->widthStep,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    IplImage *iplImage = cvCreateImage(cvGetSize(tempIplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(tempIplImage, iplImage, CV_RGBA2RGB);
    
    cvReleaseImage(&tempIplImage);
    
    return iplImage;
}

+ (CGImageRef)cgImageFromIplImage:(IplImage *)image
{
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(image->width,
                                       image->height,
                                       image->depth,
                                       image->depth * image->nChannels,
                                       image->widthStep,
                                       colorSpace,
                                       kCGImageAlphaNone | kCGBitmapByteOrderDefault,
                                       provider,
                                       NULL,
                                       false,
                                       kCGRenderingIntentDefault);
    
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    
    return cgImage;
}

+ (UIImage*) processSampleBuffer: (CMSampleBufferRef)sampleBuffer scale:(int)scale
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));

    cv::Mat matImage;

    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        // For grayscale mode, the luminance channel of the YUV data is used
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        //获得0通道的pixle位置
        void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC1, baseaddress, 0);
        matImage = mat;
        //location = [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    else if (format == kCVPixelFormatType_32BGRA) {
        // For color mode a 4-channel cv::Mat is created from the BGRA data
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC4, baseaddress, 0);
        matImage = mat;
        //location = [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    else {
        NSLog(@"Unsupported video format");
    }

    // expensive
    //equalizeHist( matImage, matImage );
    
    // Scale down first
    matImage = pixelize(matImage, scale);
    cvtColor( matImage, matImage, CV_BGR2GRAY );
    
    // returning the small image
    UIImage* result =  [UIImage imageWithCVMat:matImage];
    return result;
}

/*
+ (cv::Mat) processSampleBuffer2: (CMSampleBufferRef)sampleBuffer scale:(int)scale
{
    CVPixemak1lBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));

    cv::Mat matImage;

    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        // For grayscale mode, the luminance channel of the YUV data is used
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        //获得0通道的pixle位置
        void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC1, baseaddress, 0);
        matImage = mat;
        //location = [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    else if (format == kCVPixelFormatType_32BGRA) {
        // For color mode a 4-channel cv::Mat is created from the BGRA data
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC4, baseaddress, 0);
        matImage = mat;
        //location = [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    else {
        NSLog(@"Unsupported video format");
    }

    // expensive
    cvtColor( matImage, matImage, CV_BGR2GRAY );
    //equalizeHist( matImage, matImage );
    
    // returning the small image
    matImage = pixelize(matImage, scale);
    
    return matImage;
}*/

+ (UIImage*) pixelizeWithOpenCV: (UIImage*) inputImage scale:(int)scale {
    
    // 3ms!
    cv::Mat matImage = [inputImage CVMat3];
    
    // to 8 bit gray?
    cvtColor( matImage, matImage, CV_BGR2GRAY );
    //equalizeHist( matImage, matImage );
    matImage = pixelize(matImage, scale);
    
    UIImage* result =  [UIImage imageWithCVMat:matImage];
    return result;
}

+ (UIImage*) showCirclesWithOpenCV: (UIImage*) inputImage {
    cv::Mat matImage = [inputImage CVMat3];
    detectCircles(matImage);
    UIImage* result =  [UIImage imageWithCVMat:matImage];
    return result;
}

std::vector<uchar> matToArray(cv::Mat mat)
{
    std::vector<uchar> array;
    if (mat.isContinuous()) {
        array.assign(mat.datastart, mat.dataend);
    } else {
        for (int i = 0; i < mat.rows; ++i) {
            array.insert(array.end(), mat.ptr<uchar>(i), mat.ptr<uchar>(i)+mat.cols);
        }
    }
    return array;
}

// find and show them (this blurs the input image)
void detectCircles(cv::Mat matImage)
{
    // smooth it, otherwise a lot of false circles may be detected
    GaussianBlur( matImage, matImage, cv::Size(9, 9), 2, 2 );
    
    cv::vector<cv::Vec3f> circles;
    // gradient works, the others crash?
    //CV_HOUGH_STANDARD =0,
    //CV_HOUGH_PROBABILISTIC =1,
    //CV_HOUGH_MULTI_SCALE =2,
    //CV_HOUGH_GRADIENT =3
    HoughCircles(matImage, circles, CV_HOUGH_GRADIENT, 2, matImage.rows/4, 200, 100);
    for( size_t i = 0; i < circles.size(); i++ )
    {
        cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
        int radius = cvRound(circles[i][2]);
        // draw the circle center
        circle( matImage, center, 3, cv::Scalar(0,255,0), -1, 8, 0 );
        // draw the circle outline
        circle( matImage, center, radius, cv::Scalar(0,0,255), 3, 8, 0 );
    }
}

cv::Mat pixelize(cv::Mat src, int scale){
    cv::Size2i ds(src.cols/scale, src.rows/scale);
    
    /*
    INTER_NEAREST=CV_INTER_NN, //!< nearest neighbor interpolation
    INTER_AREA=CV_INTER_AREA, //!< area-based (or super) interpolation
    INTER_LINEAR=CV_INTER_LINEAR, //!< bilinear interpolation
    INTER_CUBIC=CV_INTER_CUBIC, //!< bicubic interpolation
    INTER_LANCZOS4=CV_INTER_LANCZOS4, //!< Lanczos interpolation over 8x8 neighborhood
    INTER_MAX=7,
     */
    resize(src, src, ds, 1, 1, cv::INTER_AREA); // 2.8ms for processSampleBuffer total with this, smooth
//    resize(src, src, ds, 1, 1, cv::INTER_NEAREST);  // < 0.1ms but pixels are jittery
//    resize(src, src, ds, 1, 1, cv::INTER_LINEAR);  // <0.1ms but also jittery
//    resize(src, src, ds, 1, 1, cv::INTER_MAX);  // not found?
//    resize(src, src, ds, 1, 1, cv::INTER_CUBIC);  //  0.1ms? but... better?
//    resize(src, src, ds, 1, 1, cv::INTER_LANCZOS4);  // 0.3ms... ok but still jittery compared to area
    
    return src;
}

@end
