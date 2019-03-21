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
    
    var currentMetaObject: [AVMetadataFaceObject] = [AVMetadataFaceObject]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = MTKView.init(frame: self.view.bounds)
        self.view.insertSubview(mtkView, at: 0)
        
        metalRender.configDisplayView(view: mtkView)
        metalRender.filter(.Gray)
        
        camera.delegate = self
        camera.startCapture()
        
    }
    
}

extension ViewController: HBCameraDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        currentMetaObject = metadataObjects as! [AVMetadataFaceObject]
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        
        var bounds = [NSValue]()
        for faceObject in currentMetaObject {
            if let face = output.transformedMetadataObject(for: faceObject, connection: connection) {
                bounds.append(NSValue.init(cgRect: face.bounds))
            }
        }

        
        let faceArray = detect.deteciton(on: sampleBuffer, inRects: bounds)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        debugPrint("代码执行时长：%f 毫秒", (endTime - startTime)*1000)
        metalRender.render(pixelBuffer: pixelBuffer)
        //        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        //        let startTime = CFAbsoluteTimeGetCurrent()
        
        //        vision.detect(pixelBuffer) { [weak self] (request, error) in
        //            let endTime = CFAbsoluteTimeGetCurrent()
        //            debugPrint("代码执行时长：%f 毫秒", (endTime - startTime)*1000)
        //            self?.metalRender.render(pixelBuffer: pixelBuffer)
        //            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        //        }
        
    }
}


