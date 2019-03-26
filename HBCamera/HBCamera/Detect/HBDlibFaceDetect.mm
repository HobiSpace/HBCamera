//
//  HBDlibFaceDetect.m
//  HBCamera
//
//  Created by Hobi on 2019/3/21.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import "HBDlibFaceDetect.h"
#import <UIKit/UIKit.h>
#import "Vertext.h"

@implementation HBDlibFaceDetect {
    dlib::shape_predictor sp;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //初始化 检测器
        NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
        std::string modelFileNameCString = [modelFileName UTF8String];
        dlib::deserialize(modelFileNameCString) >> sp;
    }
    return self;
}

- (std::vector<dlib::full_object_detection>)detecitonOnPixelBuffer:(CVImageBufferRef)imageBuffer inRects:(NSArray<NSValue *> *)rects {
    dlib::array2d<dlib::bgr_pixel> img;
    dlib::array2d<dlib::bgr_pixel> img_gray;
    // MARK: magic
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    // set_size expects rows, cols format
    img.set_size(height, width);
    
    // copy samplebuffer image data into dlib image format
    img.reset();
    long position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();
        
        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        char b = baseBuffer[bufferLocation];
        char g = baseBuffer[bufferLocation + 1];
        char r = baseBuffer[bufferLocation + 2];
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        dlib::bgr_pixel newpixel(b, g, r);
        pixel = newpixel;
        
        position++;
    }
    
    // unlock buffer again until we need it again
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    // convert the face bounds list to dlib format
    std::vector<dlib::rectangle> convertedRectangles = [self convertCGRectValueArray:rects];
    dlib::assign_image(img_gray, img);
    
    
//    NSMutableArray *facesLandmarks = [NSMutableArray arrayWithCapacity:0];
    std::vector<dlib::full_object_detection> shapeVector;
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
    {
        dlib::rectangle oneFaceRect = convertedRectangles[j];
        
        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);
        shapeVector.push_back(shape);
//        //shape 里面就是我们所需要的68 个点 因为dilb 跟 opencv 冲突 所以我们转换成Foundation 的 Array
//
//        NSMutableArray *landmarks = [NSMutableArray arrayWithCapacity:0];
//        for (int i = 0; i < shape.num_parts(); i++) {
//            dlib::point p = shape.part(i);
//            [landmarks addObject:[NSValue valueWithCGPoint:CGPointMake(p.x(), p.y())]];
//        }
//        [facesLandmarks addObject:landmarks];
        NSLog(@"Hobi Face x:%ld, y:%ld, at %i", shape.part(17).x(), shape.part(17).y(), 17);
        NSLog(@"Hobi Face x:%ld, y:%ld, at %i", shape.part(26).x(), shape.part(26).y(), 26);
        NSLog(@"Hobi Face x:%ld, y:%ld, at %i", shape.part(12).x(), shape.part(12).y(), 12);
        NSLog(@"Hobi Face x:%ld, y:%ld, at %i", shape.part(4).x(), shape.part(4).y(), 4);
    }
    
    
    
    return shapeVector;
}

- (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
    std::vector<dlib::rectangle> myConvertedRects;
    for (NSValue *rectValue in rects) {
        CGRect rect = [rectValue CGRectValue];
        long left = rect.origin.x;
        long top = rect.origin.y;
        long right = left + rect.size.width;
        long bottom = top + rect.size.height;
        dlib::rectangle dlibRect(left, top, right, bottom);
        
        myConvertedRects.push_back(dlibRect);
    }
    return myConvertedRects;
}

@end
