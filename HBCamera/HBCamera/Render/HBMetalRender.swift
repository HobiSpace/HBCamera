//
//  HBMetalRender.swift
//  FaceCamera
//
//  Created by Hobi on 2019/3/20.
//  Copyright © 2019 Hobi. All rights reserved.
//

import UIKit
import MetalKit

enum FilterType: String {
    case Original = "original_kernel_function"
    case Gray = "gray_kernel_function"
    case BlackAndWhite = "black_white_kernel_function"
    case Movie = "movie_kernel_function"
}

struct Vertex {
    var position: float4
    var texturePos: float2
}

class HBMetalRender: NSObject {
    var textureCache: CVMetalTextureCache!
    
    
    /// 顶点坐标
    var vertexBuffer: MTLBuffer?
    /// 顶点索引
    var indexBuffer: MTLBuffer?
    
    /// 输入源纹理
    var sourceTexture: MTLTexture?
    /// 处理后纹理
    var destinTexture: MTLTexture?
    
    var displayView: MTKView?
    var commandQueue: MTLCommandQueue?
    
    var renderPipeLineState: MTLRenderPipelineState?
    var computePipeLineState: MTLComputePipelineState?
    
    override init() {
        super.init()
    }
    
    func configDisplayView(view: MTKView) {
        view.device = MTLCreateSystemDefaultDevice()
        guard let device = view.device else {
            // 不支持设备
            return
        }
        
        // 创建renderpipelinestate
        let renderPipeLineStateDes = MTLRenderPipelineDescriptor.init()
        let library = device.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertexShader")
        let fragmentFunc = library?.makeFunction(name: "fragmentShader")
        renderPipeLineStateDes.vertexFunction = vertexFunc
        renderPipeLineStateDes.fragmentFunction = fragmentFunc
        renderPipeLineStateDes.colorAttachments[0].pixelFormat = view.colorPixelFormat
        guard let tmpRenderPipeLineState = try? device.makeRenderPipelineState(descriptor: renderPipeLineStateDes) else {
            return
        }
        renderPipeLineState = tmpRenderPipeLineState
        
        // 创建顶点
        let vertexArray: [Vertex] = [
            // 左下角
            Vertex.init(position: float4.init(-1, -1, 0.0, 1.0), texturePos: float2.init(0, 0)),
            // 左上角
            Vertex.init(position: float4.init(-1,  1, 0.0, 1.0), texturePos: float2.init(0, 1)),
            // 右上角
            Vertex.init(position: float4.init(1,  1, 0.0, 1.0), texturePos: float2.init(1, 1)),
            // 右下角
            Vertex.init(position: float4.init(1, -1, 0.0, 1.0), texturePos: float2.init(1, 0))
        ]
        
        let indexArray: [UInt16] = [
            0, 1, 2,
            2, 3, 0,
            ]
        
        vertexBuffer = device.makeBuffer(bytes: vertexArray, length: MemoryLayout<Vertex>.stride * vertexArray.count, options: .storageModeShared)
        
        indexBuffer = device.makeBuffer(bytes: indexArray, length: MemoryLayout<UInt16>.stride * indexArray.count, options: .storageModeShared)
        
        view.delegate = self
        view.framebufferOnly = false
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        commandQueue = device.makeCommandQueue()
        displayView = view
    }
    
    func render(pixelBuffer: CVPixelBuffer) {
        guard let displayView = displayView else {
            // 没有渲染目标
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var textureRef: CVMetalTexture?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &textureRef)
        
        if result == kCVReturnSuccess, let textureRef = textureRef {
            displayView.drawableSize = CGSize(width: width, height: height)
            sourceTexture = CVMetalTextureGetTexture(textureRef)
            // 渲染目标创建
            if destinTexture == nil, let device = displayView.device, let sourceTexture = sourceTexture {
                let textureDes = MTLTextureDescriptor.init()
                textureDes.pixelFormat = sourceTexture.pixelFormat
                textureDes.width = sourceTexture.width
                textureDes.height = sourceTexture.height
                textureDes.usage = [.shaderWrite, .shaderRead]
                destinTexture = device.makeTexture(descriptor: textureDes)
            }
        }
        
        // 释放
        textureRef = nil
    }
    
    func filter(_ type: FilterType) {
        guard let device = displayView?.device, let library = device.makeDefaultLibrary() else {
            return
        }
        
        let computeFunc = library.makeFunction(name: type.rawValue)
        guard let computeFunction = computeFunc else {
            return
        }
        computePipeLineState = try? device.makeComputePipelineState(function: computeFunction)
    }
}

extension HBMetalRender: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let sourceTexture = sourceTexture, let destinTexture = destinTexture, let drawable = view.currentDrawable, let commandBuffer = commandQueue?.makeCommandBuffer() else {
            return
        }
        
        
        // Kernel
        if let computePipeLineState = computePipeLineState, let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            
            computeEncoder.setComputePipelineState(computePipeLineState)
            computeEncoder.setTexture(sourceTexture, index: 0)
            computeEncoder.setTexture(destinTexture, index: 1)
            
            
            
            // GPU最大并发处理量
            let w = computePipeLineState.threadExecutionWidth
            
            let h = computePipeLineState.maxTotalThreadsPerThreadgroup / w
            
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            
            let threadgroupsPerGrid = MTLSize(width: (sourceTexture.width + w - 1) / w,
                                              height: (sourceTexture.height + h - 1) / h,
                                              depth: 1)
            
            computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            
            computeEncoder.endEncoding()
        }
        
        
        
        // Fragment
        guard let renderPassDes = view.currentRenderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDes), let renderPipeLineState = renderPipeLineState, let indexBuffer = indexBuffer else {
            return
        }
        
        renderEncoder.setViewport(MTLViewport.init(originX: 0, originY: 0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: -1, zfar: 1))
        renderEncoder.setRenderPipelineState(renderPipeLineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(destinTexture, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        commandBuffer.addCompletedHandler { (buffer) in
//            let endTime = CFAbsoluteTimeGetCurrent()
//            let cost = endTime - startTime
//            print("hobi cost \(cost)")
        }
        
        commandBuffer.commit()
        
    }
}
