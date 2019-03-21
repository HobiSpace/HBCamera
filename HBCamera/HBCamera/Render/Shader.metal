//
//  Shader.metal
//  CameraDemo
//
//  Created by Hobi on 2018/9/20.
//  Copyright © 2018年 Hobi. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef struct
{
    float4 position;
    float2 texturePos;
} VertexIn;


typedef struct
{
    float4 position [[position]];
    float2 texturePos;
}VertexOut;



vertex VertexOut vertexShader(const device VertexIn* vertexArray [[buffer(0)]],
                                unsigned int vid  [[vertex_id]]){
    
    VertexOut verOut;
    verOut.position = vertexArray[vid].position;
    verOut.texturePos = vertexArray[vid].texturePos;
    return verOut;
    
}


fragment half4 fragmentShader(
                                VertexOut input [[ stage_in ]],
                                texture2d<half> colorTexture [[ texture(0) ]]
                                )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    half4 colorSample = colorTexture.sample(textureSampler, input.texturePos); // 得到纹理对应位置的颜色
//    half  gray;
//    gray = dot(colorSample.rgb, half3(0.2126, 0.7152, 0.0722));
//    return half4(gray, gray, gray, colorSample.a);

    return colorSample;
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
