//
//  HBCamera.swift
//  FaceCamera
//
//  Created by Hobi on 2019/3/20.
//  Copyright © 2019 Hobi. All rights reserved.
//

import UIKit
import AVFoundation

protocol HBCameraDelegate: NSObjectProtocol {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection)
}

class HBCamera: NSObject {
    
    var captureSession: AVCaptureSession
    var captureFrontDevice: AVCaptureDevice?
    var captureBackDevice: AVCaptureDevice?
    var captureVideoDataOutput: AVCaptureVideoDataOutput
    var captureMetaDataOutput: AVCaptureMetadataOutput
    
    var frameProcessQueue: DispatchQueue
    var metaProcessQueue: DispatchQueue
    
    weak var delegate: HBCameraDelegate?
    
    override init() {
        
        captureSession = {
            let session = AVCaptureSession.init()
            return session
        }()
        
        captureVideoDataOutput = {
            let dataOutput = AVCaptureVideoDataOutput.init()
            dataOutput.alwaysDiscardsLateVideoFrames = false
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
            return dataOutput
        }()
        
        captureMetaDataOutput = {
            let metaDataOutput = AVCaptureMetadataOutput.init()
            return metaDataOutput
        }()
        
        frameProcessQueue = {
            let queue: DispatchQueue = DispatchQueue.init(label: "com.camera.hobi.data")
            return queue
        }()
        
        metaProcessQueue = {
            let queue: DispatchQueue = DispatchQueue.init(label: "com.camera.hobi.meta")
            return queue
        }()
        
        super.init()
        
        captureFrontDevice = cameraDeviceWithPosition(.front)
        captureBackDevice = cameraDeviceWithPosition(.back)
    }
}

extension HBCamera {
    func startCapture() {
        guard let device = captureFrontDevice, let deviceInput = try? AVCaptureDeviceInput.init(device: device), captureSession.canAddInput(deviceInput), captureSession.canAddOutput(captureVideoDataOutput) else {
            return
        }
        
        captureSession.addInput(deviceInput)
        
        if captureSession.canAddOutput(captureVideoDataOutput) {
            captureSession.addOutput(captureVideoDataOutput)
            captureVideoDataOutput.setSampleBufferDelegate(self, queue: frameProcessQueue)
        }
        
        if captureSession.canAddOutput(captureMetaDataOutput) {
            captureSession.addOutput(captureMetaDataOutput)
            captureMetaDataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
            captureMetaDataOutput.setMetadataObjectsDelegate(self, queue: metaProcessQueue)
        }
        
        let connection = captureVideoDataOutput.connection(with: .video)
        connection?.videoOrientation = .portraitUpsideDown
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        captureSession.startRunning()
    }
}

extension HBCamera {
    private func cameraDeviceWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        let devicesSession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position)
        
        for device in devicesSession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
}

extension HBCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.captureOutput(output, didOutput: sampleBuffer, from: connection)
    }
}

extension HBCamera: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        delegate?.metadataOutput(output, didOutput: metadataObjects, from: connection)
    }
}
