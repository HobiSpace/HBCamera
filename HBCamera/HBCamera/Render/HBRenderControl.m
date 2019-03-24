//
//  HBRenderControl.m
//  HBCamera
//
//  Created by hebi on 2019/3/23.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import "HBRenderControl.h"
#import "HBDlibFaceDetect.h"
#import "HBMetalRender.h"
@interface HBRenderControl()
@property (nonatomic, strong) HBMetalRender *metalRender;
@property (nonatomic, strong) HBDlibFaceDetect *faceDetect;
@property (nonatomic, strong) dispatch_queue_t faceDetectQueue;
@end

@implementation HBRenderControl

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

#pragma mark - Public
- (void)addFilter {
    [self.metalRender addFilter];
}

- (void)configDisplayView:(MTKView *)displayView {
    [self.metalRender setupDisplayView:displayView];
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer openFaceDetect:(BOOL)open inRects:(NSArray<NSValue *> *)rects didDetectFace:(HBRenderControlDidDetectFaceCompletion)faceCallBack didRender:(HBRenderControlDidRenderPixelCompletion)renderCallBack completion:(HBRenderControlDidFinishCompletion)completion {
    if (open) {
        dispatch_async(self.faceDetectQueue, ^{
            std::vector<dlib::full_object_detection> faceInfo = [self.faceDetect detecitonOnPixelBuffer:pixelBuffer inRects:rects];
            // 人脸点转换
            //shape 里面就是我们所需要的68 个点 因为dilb 跟 opencv 冲突 所以我们转换成Foundation 的 Array
            HBFaceInfo metalFaceInfoPoint = HBFaceInfo();
            for (std::vector<dlib::full_object_detection>::iterator it = faceInfo.begin(); it != faceInfo.end(); ++it) {
                dlib::full_object_detection shape = *it;
//                HBFaceInfo faceInfo = HBFaceInfo();
                for (int i = 0; i < shape.num_parts(); i++) {
                    dlib::point p = shape.part(i);
                    metalFaceInfoPoint.pointArray[i] = simd_make_float2(p.x(), p.y());
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (faceCallBack) {
                    faceCallBack();
                }
                [self.metalRender bindFaceInfo:metalFaceInfoPoint];
                [self.metalRender render:pixelBuffer];
                if (renderCallBack) {
                    renderCallBack();
                }
                
                if (completion) {
                    completion();
                }
            });
        });
    }
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer openFaceDetect:(BOOL)open inRects:(NSArray<NSValue *> *)rects {
    [self.metalRender render:pixelBuffer];
}

#pragma mark - Setter And Getter
- (HBMetalRender *)metalRender {
    if (_metalRender == nil) {
        _metalRender = [[HBMetalRender alloc] init];
    }
    return _metalRender;
}

- (HBDlibFaceDetect *)faceDetect {
    if (_faceDetect == nil) {
        _faceDetect = [[HBDlibFaceDetect alloc] init];
    }
    return _faceDetect;
}

- (dispatch_queue_t)faceDetectQueue {
    if (_faceDetectQueue == nil) {
        _faceDetectQueue = dispatch_queue_create("com.hobi.face.detect.queue", DISPATCH_QUEUE_SERIAL);
    }
    return _faceDetectQueue;
}


@end

