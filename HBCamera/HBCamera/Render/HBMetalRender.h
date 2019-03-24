//
//  HBMetalRender.h
//  HBCamera
//
//  Created by hebi on 2019/3/23.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <CoreMedia/CoreMedia.h>
#import "Vertext.h"
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBMetalRender : NSObject
- (void)setupDisplayView:(MTKView *)displayView;
- (void)render:(CVPixelBufferRef)pixelBuffer;
- (void)addFilter;
- (void)bindFaceInfo:(HBFaceInfo)faceInfo;
@end

NS_ASSUME_NONNULL_END
