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
    
    var renderControl: HBRenderControl = {
        let tmpControl = HBRenderControl.init()
        return tmpControl
    }()
    
    var mtkView: MTKView!
    
    var currentMetaObject: [AVMetadataFaceObject] = [AVMetadataFaceObject]()
    var faceBounds: [NSValue] = [NSValue]()
    
    var isProcessing: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = MTKView.init(frame: self.view.bounds)
        self.view.insertSubview(mtkView, at: 0)
        
        renderControl.configDisplay(mtkView)
        renderControl.addFilter()
        
        camera.delegate = self
        camera.startCapture()
        
    }
    
}

extension ViewController: HBCameraDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        currentMetaObject = metadataObjects as! [AVMetadataFaceObject]
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard isProcessing == false else {
            return
        }
        
        isProcessing = true
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [CVPixelBufferLockFlags.readOnly])
        faceBounds.removeAll()
        for faceObject in currentMetaObject {
            if let face = output.transformedMetadataObject(for: faceObject, connection: connection) {
                faceBounds.append(NSValue.init(cgRect: face.bounds))
            }
        }
        renderControl.renderPixelBuffer(pixelBuffer, openFaceDetect: true, inRects: faceBounds, didDetectFace: {
            self.isProcessing = false
        }, didRender: {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [CVPixelBufferLockFlags.readOnly])
        }) {
            
        }
    }
}


