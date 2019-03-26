//
//  HBMetalRender.m
//  HBCamera
//
//  Created by hebi on 2019/3/23.
//  Copyright © 2019 Hobi. All rights reserved.
//

#import "HBMetalRender.h"


@interface HBMetalRender()<MTKViewDelegate>

/**
 相机metal纹理缓存
 */
@property (nonatomic, assign) CVMetalTextureCacheRef cameraTextureCache;

@property (nonatomic, strong) id<MTLBuffer> cameraVertexBuffer;

@property (nonatomic, strong) id<MTLBuffer> cameraVertexIndexBuffer;

@property (nonatomic, strong) id<MTLBuffer> faceDetectVertexBuffer;

@property (nonatomic, strong) id<MTLTexture> cameraSourceTexture;

@property (nonatomic, strong) id<MTLTexture> filterTexture;

@property (nonatomic, strong) id<MTLTexture> maskTexture;

@property (nonatomic, strong) id<MTLTexture> arTexture;

@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipelineState;

@property (nonatomic, strong) id<MTLComputePipelineState> filterComputePipelineState;

@property (nonatomic, strong) id<MTLRenderPipelineState> arRenderPipelineState;

@property (nonatomic, strong) MTLRenderPassDescriptor *arRenderPassDes;

@property (nonatomic, weak) MTKView *displayView;

@end

@implementation HBMetalRender

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)setupDisplayView:(MTKView *)displayView {
    
    if (displayView == nil) {
        return;
    }
    
    displayView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    displayView.device = MTLCreateSystemDefaultDevice();
    id<MTLDevice> device = displayView.device;
    if (device == nil) {
        return;
    }
    
    MTLRenderPipelineDescriptor *renderPipelineDes = [[MTLRenderPipelineDescriptor alloc] init];
    id<MTLLibrary> library = [device newDefaultLibrary];
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_shader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_shader"];
    renderPipelineDes.vertexFunction = vertexFunc;
    renderPipelineDes.fragmentFunction = fragmentFunc;
    // 了解一下，这什么意思
    renderPipelineDes.colorAttachments[0].pixelFormat = displayView.colorPixelFormat;
    
    NSError *error;
    self.renderPipelineState = [device newRenderPipelineStateWithDescriptor:renderPipelineDes error:&error];

    
    MTLRenderPipelineDescriptor *arRenderPipelineDes = [[MTLRenderPipelineDescriptor alloc] init];
    id<MTLFunction> arVertexFunc = [library newFunctionWithName:@"ar_vertex_shader"];
    id<MTLFunction> arFragmentFunc = [library newFunctionWithName:@"ar_fragment_shader"];
    arRenderPipelineDes.vertexFunction = arVertexFunc;
    arRenderPipelineDes.fragmentFunction = arFragmentFunc;
    // 了解一下，这什么意思
    arRenderPipelineDes.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm_sRGB;

    NSError *arError;
    self.arRenderPipelineState = [device newRenderPipelineStateWithDescriptor:arRenderPipelineDes error:&arError];
    
    if (arError) {
        return;
    }
    
    HBVertex vertextArray[4] = {
        // 左下角
        {{-1.0, -1.0, 0.0, 1.0}, {0, 1}},
        // 左上角
        {{-1.0, 1.0, 0.0, 1.0}, {0, 0}},
        // 右上角
        {{1.0, 1.0, 0.0, 1.0}, {1, 0}},
        // 右下角
        {{1.0, -1.0, 0.0, 1.0}, {1, 1}}
    };
    
    UInt16 indexArray[6] = {
        0, 1, 2,
        2, 3, 0,
    };
    
    self.cameraVertexBuffer = [device newBufferWithBytes:vertextArray length:sizeof(vertextArray) options:MTLResourceStorageModeShared];
    
    self.cameraVertexIndexBuffer = [device newBufferWithBytes:indexArray length:sizeof(indexArray) options:MTLResourceStorageModeShared];
    
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
    UIImage *testImage = [UIImage imageNamed:@"ear_00000"];
    self.arTexture = [loader newTextureWithCGImage:testImage.CGImage options:nil error:nil];
    
    displayView.delegate = self;
    displayView.framebufferOnly = NO;
    
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &_cameraTextureCache);
    
    self.commandQueue = [device newCommandQueue];
    self.displayView = displayView;
}

- (void)render:(CVPixelBufferRef)pixelBuffer {
    
    if (self.displayView == nil) {
        return;
    }
    
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CVMetalTextureRef texutreRef;
    CVReturn result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.cameraTextureCache, pixelBuffer, nil, MTLPixelFormatBGRA8Unorm, width, height, 0, &texutreRef);
    
    
    if (result != kCVReturnSuccess || texutreRef == nil) {
        return;
    }
    
    self.displayView.drawableSize = CGSizeMake(width, height);
    self.cameraSourceTexture = CVMetalTextureGetTexture(texutreRef);

    if (self.filterTexture == nil || self.maskTexture == nil) {
        MTLTextureDescriptor *textureDes = [[MTLTextureDescriptor alloc] init];
        textureDes.pixelFormat = self.cameraSourceTexture.pixelFormat;
        textureDes.width = self.cameraSourceTexture.width;
        textureDes.height = self.cameraSourceTexture.height;
        textureDes.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

        if (self.filterTexture == nil) {
            self.filterTexture = [self.displayView.device newTextureWithDescriptor:textureDes];
        }

        if (self.maskTexture == nil) {
            MTLTextureDescriptor *textureDes = [[MTLTextureDescriptor alloc] init];
            textureDes.pixelFormat = MTLPixelFormatRGBA8Unorm_sRGB;
            textureDes.width = self.cameraSourceTexture.width;
            textureDes.height = self.cameraSourceTexture.height;
            textureDes.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
            self.maskTexture = [self.displayView.device newTextureWithDescriptor:textureDes];
        }
    }
    
    CVBufferRelease(texutreRef);
}

- (vector_float2)transToGLPoint:(vector_float2)iOSPoint {
    // 转换frame坐标 到 gl顶点坐标 和 纹理坐标
    CGFloat width = 720;
    CGFloat height = 1280;
    
    float x = (iOSPoint.x - width / 2) / (width / 2);
    float y = (height / 2 - iOSPoint.y) / (height / 2);
    
    return vector2(x, y);
}

- (void)bindFaceInfo:(HBFaceInfo)faceInfo {
    
    if (self.displayView == nil) {
        return;
    }
    
    // 左上角
    vector_float2 p1 = faceInfo.pointArray[17];
    // 右上角
    vector_float2 p2 = faceInfo.pointArray[26];
    // 右下角
    vector_float2 p3 = faceInfo.pointArray[12];
    // 左下角
    vector_float2 p4 = faceInfo.pointArray[4];
    
    vector_float2 glp1 = [self transToGLPoint:p1];
    vector_float2 glp2 = [self transToGLPoint:p2];
    vector_float2 glp3 = [self transToGLPoint:p3];
    vector_float2 glp4 = [self transToGLPoint:p4];
    
    HBVertex vertextArray[4] = {
        {{glp4.x, glp4.y, 0.0, 1.0}, {0, 1}},
        {{glp1.x, glp1.y, 0.0, 1.0}, {0, 0}},
        {{glp2.x, glp2.y, 0.0, 1.0}, {1, 0}},
        {{glp3.x, glp3.y, 0.0, 1.0}, {1, 1}}
    };
    
//    HBVertex vertextArray[4] = {
//        {{-0.5, -0.5, 0.0, 1.0}, {0, 0}},
//        {{-0.5, 0.5, 0.0, 1.0}, {0, 1}},
//        {{0.5, 0.5, 0.0, 1.0}, {1, 1}},
//        {{0.5, -0.5, 0.0, 1.0}, {1, 0}}
//    };

    self.faceDetectVertexBuffer = [self.displayView.device newBufferWithBytes:vertextArray length:sizeof(vertextArray) options:MTLStorageModeShared];
}

- (void)addFilter:(FilterType)type {
    NSString *funcName;
    switch (type) {
        case FilterType_None: {
            funcName = @"original_kernel_function";
        } break;
        case FilterType_Black: {
            funcName = @"black_white_kernel_function";
        } break;
        case FilterType_Gray: {
            funcName = @"gray_kernel_function";
        } break;
        case FilterType_Movie: {
            funcName = @"movie_kernel_function";
        } break;
        default:
            
            break;
    }
    
    if (self.displayView == nil) {
        return;
    }
    
    id<MTLLibrary> library = [self.displayView.device newDefaultLibrary];
    id<MTLFunction> filterFunc = [library newFunctionWithName:funcName];
    if (filterFunc == nil) {
        return;
    }
    
    NSError *error;
    self.filterComputePipelineState = [self.displayView.device newComputePipelineStateWithFunction:filterFunc error:&error];
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView *)view {
    if (self.cameraSourceTexture == nil || self.filterTexture == nil) {
        return;
    }
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLCommandBuffer> offCommandBuffer = [self.commandQueue commandBuffer];
    
    if (commandBuffer == nil) {
        return;
    }
    
    // filter
    if (self.filterComputePipelineState) {
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        [computeEncoder setComputePipelineState:self.filterComputePipelineState];
        [computeEncoder setTexture:self.cameraSourceTexture atIndex:0];
        [computeEncoder setTexture:self.filterTexture atIndex:1];
        NSUInteger width = self.filterComputePipelineState.threadExecutionWidth;
        NSUInteger height = self.filterComputePipelineState.maxTotalThreadsPerThreadgroup / width;
        MTLSize threadsPerThreadGroup = MTLSizeMake(width, height, 1);
        MTLSize threadGroupPerGrid = MTLSizeMake((self.cameraSourceTexture.width + width - 1) / width, (self.cameraSourceTexture.height + height -1) / height, 1);
        [computeEncoder dispatchThreadgroups:threadGroupPerGrid threadsPerThreadgroup:threadsPerThreadGroup];
        [computeEncoder endEncoding];
    }
    
//    // ar
//    if (self.arRenderPipelineState) {
//        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
//        [computeEncoder setComputePipelineState:self.arComputePipelineState];
//        [computeEncoder setTexture:self.arTexture atIndex:0];
//        [computeEncoder setTexture:self.maskTexture atIndex:1];
//        [computeEncoder setBuffer:self.faceDetectVertexBuffer offset:0 atIndex:2];
//        NSUInteger width = self.filterComputePipelineState.threadExecutionWidth;
//        NSUInteger height = self.filterComputePipelineState.maxTotalThreadsPerThreadgroup / width;
//        MTLSize threadsPerThreadGroup = MTLSizeMake(width, height, 1);
//        MTLSize threadGroupPerGrid = MTLSizeMake((self.cameraSourceTexture.width + width - 1) / width, (self.cameraSourceTexture.height + height -1) / height, 1);
//        [computeEncoder dispatchThreadgroups:threadGroupPerGrid threadsPerThreadgroup:threadsPerThreadGroup];
//        [computeEncoder endEncoding];
//    }
    
    
    // ar
    if (self.arRenderPipelineState) {
        if (self.arRenderPassDes == nil) {
            MTLRenderPassDescriptor *passDes = [[MTLRenderPassDescriptor alloc] init];
            passDes.colorAttachments[0].texture = self.maskTexture;
            passDes.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 0);
            passDes.colorAttachments[0].loadAction = MTLLoadActionClear;
            self.arRenderPassDes = passDes;
        }
        
        id<MTLRenderCommandEncoder> renderEncoder = [offCommandBuffer renderCommandEncoderWithDescriptor:self.arRenderPassDes];
        [renderEncoder setViewport:{0, 0, view.drawableSize.width, view.drawableSize.height, -1, 1}];
        [renderEncoder setRenderPipelineState:self.arRenderPipelineState];
        [renderEncoder setVertexBuffer:self.faceDetectVertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:self.arTexture atIndex:0];
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:self.cameraVertexIndexBuffer indexBufferOffset:0];
        [renderEncoder endEncoding];
        [offCommandBuffer commit];
        [offCommandBuffer waitUntilCompleted];
    }

    // render
    if (view.currentRenderPassDescriptor && self.renderPipelineState) {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:view.currentRenderPassDescriptor];
        [renderEncoder setViewport:{0, 0, view.drawableSize.width, view.drawableSize.height, -1, 1}];
        [renderEncoder setRenderPipelineState:self.renderPipelineState];
        [renderEncoder setVertexBuffer:self.cameraVertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:self.filterTexture atIndex:0];
        [renderEncoder setFragmentTexture:self.maskTexture atIndex:1];
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:self.cameraVertexIndexBuffer indexBufferOffset:0];
        [renderEncoder endEncoding];
    }
    
   
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        
    }];
    [commandBuffer commit];
    
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}

@end
