//
//  HBDlibFaceDetect.h
//  HBCamera
//
//  Created by Hobi on 2019/3/21.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <dlib/image_processing.h>
#import <dlib/image_io.h>

//NS_ASSUME_NONNULL_BEGIN

@interface HBDlibFaceDetect : NSObject

- (std::vector<dlib::full_object_detection>)detecitonOnPixelBuffer:(CVImageBufferRef)imageBuffer inRects:(NSArray<NSValue *> *)rects;
@end

//NS_ASSUME_NONNULL_END
