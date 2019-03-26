//
//  HBRenderControl.h
//  HBCamera
//
//  Created by hebi on 2019/3/23.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^HBRenderControlDidDetectFaceCompletion)(void);
typedef void(^HBRenderControlDidRenderPixelCompletion)(void);
typedef void(^HBRenderControlDidFinishCompletion)(void);
@class MTKView;
@interface HBRenderControl : NSObject
- (void)switchNextFilter;

- (void)configDisplayView:(MTKView *)displayView;

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer openFaceDetect:(BOOL)open inRects:(NSArray<NSValue *> *)rects didDetectFace:(HBRenderControlDidDetectFaceCompletion)faceCallBack didRender:(HBRenderControlDidRenderPixelCompletion)renderCallBack completion:(HBRenderControlDidFinishCompletion)completion;

@end

NS_ASSUME_NONNULL_END
