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

@property (nonatomic, strong) id<MTLComputePipelineState> arComputePipelineState;

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
    
    if (error) {
        return;
    }
    
    HBVertex vertextArray[4] = {
        {{-1.0, -1.0, 0.0, 1.0}, {0, 0}},
        {{-1.0, 1.0, 0.0, 1.0}, {0, 1}},
        {{1.0, 1.0, 0.0, 1.0}, {1, 1}},
        {{1.0, -1.0, 0.0, 1.0}, {1, 0}}
    };
    
    UInt16 indexArray[6] = {
        0, 1, 2,
        2, 3, 0,
    };
    
    self.cameraVertexBuffer = [device newBufferWithBytes:vertextArray length:sizeof(vertextArray) options:MTLResourceStorageModeShared];
    
    self.cameraVertexIndexBuffer = [device newBufferWithBytes:indexArray length:sizeof(indexArray) options:MTLResourceStorageModeShared];
    
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
        textureDes.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

        if (self.filterTexture == nil) {
            self.filterTexture = [self.displayView.device newTextureWithDescriptor:textureDes];
        }

        if (self.maskTexture == nil) {
            self.maskTexture = [self.displayView.device newTextureWithDescriptor:textureDes];
        }
    }
    
    CVBufferRelease(texutreRef);
}

- (void)bindFaceInfo:(HBFaceInfo)faceInfo {
    
    if (self.displayView == nil) {
        return;
    }
    
    self.faceDetectVertexBuffer = [self.displayView.device newBufferWithBytes:&faceInfo length:sizeof(HBFaceInfo) options:MTLStorageModeShared];
}

- (void)addFilter {
    
    if (self.displayView == nil) {
        return;
    }
    
    id<MTLLibrary> library = [self.displayView.device newDefaultLibrary];
    id<MTLFunction> filterFunc = [library newFunctionWithName:@"gray_kernel_function"];
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
    
    // ar
    if (self.arComputePipelineState) {
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        [computeEncoder setComputePipelineState:self.arComputePipelineState];
        [computeEncoder setTexture:self.arTexture atIndex:0];
        [computeEncoder setTexture:self.maskTexture atIndex:1];
        [computeEncoder setBuffer:self.faceDetectVertexBuffer offset:0 atIndex:2];
        NSUInteger width = self.filterComputePipelineState.threadExecutionWidth;
        NSUInteger height = self.filterComputePipelineState.maxTotalThreadsPerThreadgroup / width;
        MTLSize threadsPerThreadGroup = MTLSizeMake(width, height, 1);
        MTLSize threadGroupPerGrid = MTLSizeMake((self.cameraSourceTexture.width + width - 1) / width, (self.cameraSourceTexture.height + height -1) / height, 1);
        [computeEncoder dispatchThreadgroups:threadGroupPerGrid threadsPerThreadgroup:threadsPerThreadGroup];
        [computeEncoder endEncoding];
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
