//
//  HBDlibFaceDetect.h
//  HBCamera
//
//  Created by Hobi on 2019/3/21.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBDlibFaceDetect : NSObject
//之所以 return 的数组 看起来比较啰嗦 但是是为了让你们看清，也可以不这么写
- (NSArray <NSArray <NSValue *> *>*)detecitonOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects;
@end

NS_ASSUME_NONNULL_END
