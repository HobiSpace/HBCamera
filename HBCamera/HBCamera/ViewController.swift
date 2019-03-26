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
    
    var swipeGes: UISwipeGestureRecognizer?
    
    @objc func swipeNext(sender: UISwipeGestureRecognizer) {
        renderControl.switchNextFilter()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = MTKView.init(frame: self.view.bounds)
        self.view.insertSubview(mtkView, at: 0)
        
        swipeGes = UISwipeGestureRecognizer.init(target: self, action: #selector(swipeNext))
        swipeGes?.direction = [UISwipeGestureRecognizer.Direction.left, UISwipeGestureRecognizer.Direction.right]
        mtkView.addGestureRecognizer(swipeGes!)
        
        renderControl.configDisplay(mtkView)
        renderControl.switchNextFilter()
        
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


