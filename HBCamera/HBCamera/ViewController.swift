//
//  ViewController.swift
//  HBCamera
//
//  Created by hebi on 2019/3/21.
//  Copyright © 2019 Hobi. All rights reserved.
//

import UIKit
import AVFoundation
import MetalKit

class ViewController: UIViewController {
    
    var camera: HBCamera = {
        let tmpCamera = HBCamera.init()
        return tmpCamera
    }()
    
    var metalRender: HBMetalRender = {
        let tmpRender = HBMetalRender.init()
        return tmpRender
    }()
    
    var mtkView: MTKView!
    
    var detect = HBDlibFaceDetect.init()
    
    var visionDetect = HBVisionDetect.init()
    
    var currentMetaObject: [AVMetadataFaceObject] = [AVMetadataFaceObject]()
    
    var frameBufferCache: [CVPixelBuffer] = [CVPixelBuffer].init()
    
    var detectProcessQueue: DispatchQueue = DispatchQueue.init(label: "com.face")
    
    var displayLink: CADisplayLink!
    var isProcessing: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = MTKView.init(frame: self.view.bounds)
        self.view.insertSubview(mtkView, at: 0)
        
        metalRender.configDisplayView(view: mtkView)
        metalRender.filter(.Gray)
        
        camera.delegate = self
        camera.startCapture()
        
        displayLink = CADisplayLink.init(target: self, selector: #selector(updateMetal))
        displayLink.preferredFramesPerSecond = 30
//        displayLink.add(to: RunLoop.current, forMode: .common)
    }
    
    @objc func updateMetal() {
        guard let firstPixel = frameBufferCache.first else {
            return
        }
        metalRender.render(pixelBuffer: firstPixel)
        let moreIndex = frameBufferCache.count - 5
        if moreIndex > 0 {
            frameBufferCache.removeSubrange(0 ... moreIndex)
        }
    }
}

extension ViewController: HBCameraDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        currentMetaObject = metadataObjects as! [AVMetadataFaceObject]
    }
    
    func dlibDetect(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
//        let startTime = CFAbsoluteTimeGetCurrent()
        var bounds = [NSValue]()
        for faceObject in currentMetaObject {
            if let face = output.transformedMetadataObject(for: faceObject, connection: connection) {
                bounds.append(NSValue.init(cgRect: face.bounds))
            }
        }
        
        let faceArray = detect.deteciton(on: sampleBuffer, inRects: bounds)
        
//        let endTime = CFAbsoluteTimeGetCurrent()
//        debugPrint("代码执行时长：%f 毫秒", (endTime - startTime)*1000)
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard isProcessing == false else {
            return
        }
        
        isProcessing = true
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
//        metalRender.render(pixelBuffer: pixelBuffer)
//        let copyBuffer = pixelBuffer.copy()
        
//        frameBufferCache.append(pixelBuffer)
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        detectProcessQueue.async {
            
//            self.dlibDetect(output, didOutput: sampleBuffer, from: connection)
//            self.isProcessing = false
//            DispatchQueue.global().async {
//                self.metalRender.render(pixelBuffer: pixelBuffer)
//                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
//            }
            
            
            self.visionDetect.detect(pixelBuffer, completion: { (request, error) in
                // 处理人脸数据
                self.isProcessing = false
                DispatchQueue.global().async {
                    self.metalRender.render(pixelBuffer: pixelBuffer)
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                }
            })
        }
        
        
        
//        visionDetect.detect(pixelBuffer) { [weak self] (request, error) in
//            self?.metalRender.render(pixelBuffer: pixelBuffer)
//            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
//            self?.isProcessing = false
//        }
        
        
        
//        metalRender.render(pixelBuffer: pixelBuffer)
//        CVPixelBufferLockBaseAddress(pixelBuffer, [])
//
//        let startTime = CFAbsoluteTimeGetCurrent()
//
//        vision.detect(pixelBuffer) { [weak self] (request, error) in
//            let endTime = CFAbsoluteTimeGetCurrent()
//            debugPrint("代码执行时长：%f 毫秒", (endTime - startTime)*1000)
//            self?.metalRender.render(pixelBuffer: pixelBuffer)
//            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
//        }
        
        
        
        
        
        
    }
}


