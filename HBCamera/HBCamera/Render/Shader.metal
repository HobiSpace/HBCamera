//
//  Shader.metal
//  CameraDemo
//
//  Created by Hobi on 2018/9/20.
//  Copyright © 2018年 Hobi. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "Vertext.h"

using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 texturePos;
} VertexOut;

vertex VertexOut vertex_shader(const device HBVertex* vertexArray [[buffer(0)]],
                              unsigned int vid [[vertex_id]]){
    VertexOut verOut;
    verOut.position = vertexArray[vid].position;
    verOut.texturePos = vertexArray[vid].texturePosition;
    return verOut;
}

constexpr sampler textureSampler (mag_filter::linear,
                                  min_filter::linear); // sampler是采样器
fragment half4 fragment_shader(
                              VertexOut input [[ stage_in ]],
                              texture2d<half> colorTexture [[ texture(0) ]],
                              texture2d<half> maskTexture [[ texture(1) ]]
                              )
{
    half4 colorSample = colorTexture.sample(textureSampler, input.texturePos); // 得到纹理对应位
    half4 maskSample = maskTexture.sample(textureSampler, input.texturePos);
    if (maskSample.a > 0) {
        return maskSample;
    } else {
        return colorSample;
    }
}

// Rec. 709 luma values for grayscale image conversion

kernel void original_kernel_function(texture2d<half, access::read> inTexture [[texture(0)]],
                                     texture2d<half, access::write> outTexture [[texture(1)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    outTexture.write(inColor, gid);
}

// Rec. 709 luma values for grayscale image conversion
constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);

kernel void gray_kernel_function(texture2d<half, access::read> inTexture [[texture(0)]],
                                 texture2d<half, access::write> outTexture [[texture(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    half  gray     = dot(inColor.rgb, kRec709Luma);
    outTexture.write(half4(gray, gray, gray, inColor.a), gid);
}


kernel void black_white_kernel_function(texture2d<half, access::read> inTexture [[texture(0)]],
                                        texture2d<half, access::write> outTexture [[texture(1)]],
                                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    int count = (inColor.r * 255 + inColor.g * 255 + inColor.b * 255) / 3.;
    if (count >= 100) {
        outTexture.write(half4(255, 255, 255, inColor.a), gid);
    } else {
        outTexture.write(half4(0, 0, 0, inColor.a), gid);
    }
}


kernel void movie_kernel_function(texture2d<half, access::read> inTexture [[texture(0)]],
                                  texture2d<half, access::write> outTexture [[texture(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    outTexture.write(half4(1 - inColor.r, 1 - inColor.g, 1 - inColor.b, inColor.a), gid);
}


// Material
kernel void material_kernel_function(texture2d<half, access::sample> imageTexture [[texture(0)]],
                                     texture2d<half, access::write> outTexture [[texture(1)]],
                                     const device HBFaceInfo *faceInfo [[buffer(2)]],
                                     uint2 gid [[thread_position_in_grid]]) {
//    float leftEyeX, leftEyeY, rightEyeX, rightEyeY;
//    for (int i = 36; i < 42; i++) {
//        leftEyeX = leftEyeX + faceInfo->pointArray[i].x;
//        leftEyeY = leftEyeY + faceInfo->pointArray[i].y;
//    }
//    leftEyeX = leftEyeX / 6;
//    leftEyeY = leftEyeY / 6;
//
//    for (int i = 42; i < 48; i++) {
//        rightEyeX = rightEyeX + faceInfo->pointArray[i].x;
//        rightEyeY = rightEyeY + faceInfo->pointArray[i].y;
//    }
//    rightEyeX = rightEyeX / 6;
//    rightEyeY = rightEyeY / 6;
//    float width = imageTexture.width;
//    float height = imageTexture.height;
    
//    int width = outTexture.get_width();
//    int height = outTexture.get_height();
//
//    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
//        return;
//    }
//
//    float minXRange = 0.25 * width;
//    float maxXRange = 0.75 * width;
//
//    float minYRange = 0.25 * height;
//    float maxYRange = 0.75 * height;
    
//    half4 inColor  = inTexture.read(gid);
//    constexpr sampler textureSampler (mag_filter::linear,
//                                      min_filter::linear); // sampler是采样器
//    // 判断是素材纹理还是滤镜纹理
//    if (gid.x >= minXRange && gid.x <= maxXRange && gid.y >= minYRange && gid.y <= maxYRange) {
//        float x = (gid.x - minXRange) / (0.5 * width);
//        float y = (gid.y - minYRange) / (0.5 * height);
//
//        half4 outColor = imageTexture.sample(textureSampler, float2(x, y));
//        outTexture.write(outColor, gid);
//    } else {
//        half4 outColor = half4(0, 0, 0, 0);
//        outTexture.write(outColor, gid);
//    }
}
