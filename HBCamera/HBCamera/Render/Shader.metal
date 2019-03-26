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

vertex VertexOut ar_vertex_shader(const device HBVertex* vertexArray [[buffer(0)]],
                               unsigned int vid [[vertex_id]]){
    VertexOut verOut;
    verOut.position = vertexArray[vid].position;
    verOut.texturePos = vertexArray[vid].texturePosition;
    return verOut;
}

fragment half4 ar_fragment_shader(
                               VertexOut input [[ stage_in ]],
                                 texture2d<half, access::sample> imageTexture [[texture(0)]]
                               )
{
    half4 colorSample = imageTexture.sample(textureSampler, input.texturePos); // 得到纹理对应位
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

kernel void lut_filter_function(texture2d<half, access::read> sourceTexture [[texture(0)]],
                                texture2d<half, access::sample> lutTexture [[texture(1)]],
                                texture2d<half, access::write> outputTexture [[texture(2)]],
                                uint2 gid [[thread_position_in_grid]]
                                )
{
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }

    // 读取输入颜色
    half4 sourceColor = sourceTexture.read(gid);
    // 第一步 找 b 的位置
    half b = sourceColor.b;
    float bPos = b * 63;

    // 第二部 根据bPos 确认 方格
    int tbPosMin = floor(bPos);
    int tbPosMax = ceil(bPos);
    // rg方格位置
    int2 colorQua1 = int2(tbPosMin % 8, tbPosMin / 8);
    int2 colorQua2 = int2(tbPosMax % 8, tbPosMax / 8);

    // 63待商榷
    float2 texturePos1 = float2((colorQua1.x * 64 + sourceColor.r * 63) / 512, (colorQua1.y * 64 + sourceColor.y * 63) / 512);
    float2 texturePos2 = float2((colorQua2.x * 64 + sourceColor.r * 63) / 512, (colorQua2.y * 64 + sourceColor.y * 63) / 512);

    half4 newColor1 = lutTexture.sample(textureSampler, texturePos1);
    half4 newColor2 = lutTexture.sample(textureSampler, texturePos2);
    half4 newColor = mix(newColor1, newColor2, fract(bPos));

    outputTexture.write(newColor, gid);
}

//constant float SquareSize = 63.0 / 512.0;
//constant float stepSize = 0.0; //0.5 / 512.0;
//kernel void samplingShader(texture2d<float> normalTexture [[ texture(0) ]],
//                           texture2d<float> lookupTableTexture [[ texture(1) ]],
//                           texture2d<half, access::write> outputTexture [[texture(2)]],
//                           uint2 gid [[thread_position_in_grid]])
//{
//    float4 textureColor = normalTexture.read(gid); //正常的纹理颜色
//    
//    float blueColor = textureColor.b * 63.0; // 蓝色部分[0, 63] 共64种
//    
//    float2 quad1; // 第一个正方形的位置, 假如blueColor=22.5，则y=22/8=2，x=22-8*2=6，即是第2行，第6个正方形；（因为y是纵坐标）
//    quad1.y = floor(floor(blueColor) * 0.125);
//    quad1.x = floor(blueColor) - (quad1.y * 8.0);
//    
//    float2 quad2; // 第二个正方形的位置，同上。注意x、y坐标的计算，还有这里用int值也可以，但是为了效率使用float
//    quad2.y = floor(ceil(blueColor) * 0.125);
//    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
//    
//    float2 texPos1; // 计算颜色(r,b,g)在第一个正方形中对应位置
//    /*
//     quad1是正方形的坐标，每个正方形占纹理大小的1/8，即是0.125，所以quad1.x * 0.125是算出正方形的左下角x坐标
//     stepSize这里设置为0，可以忽略；
//     SquareSize是63/512，一个正方形小格子在整个图片的纹理宽度
//     */
//    
//    texPos1.x = (quad1.x * 0.125) + stepSize + (SquareSize * textureColor.r);
//    texPos1.y = (quad1.y * 0.125) + stepSize + (SquareSize * textureColor.g);
//    
//    float2 texPos2; // 同上
//    texPos2.x = (quad2.x * 0.125) + stepSize + (SquareSize * textureColor.r);
//    texPos2.y = (quad2.y * 0.125) + stepSize + (SquareSize * textureColor.g);
//    
//    float4 newColor1 = lookupTableTexture.sample(textureSampler, texPos1); // 正方形1的颜色值
//    float4 newColor2 = lookupTableTexture.sample(textureSampler, texPos2); // 正方形2的颜色值
//    
//    float4 newColor = mix(newColor1, newColor2, fract(blueColor)); // 根据小数点的部分进行mix
////    float4 writeColor = (newColor.rgb, textureColor.w);
//    half4 writeColor = half4(newColor.r, newColor.g, newColor.b, textureColor.w);
//    outputTexture.write(writeColor, gid); //不修改alpha值
//}
