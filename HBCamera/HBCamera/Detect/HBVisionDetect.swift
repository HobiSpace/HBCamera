//
//  HBVisionDetect.swift
//  HBCamera
//
//  Created by Hobi on 2019/3/21.
//  Copyright © 2019 Hobi. All rights reserved.
//

import UIKit
import Vision

class HBVisionDetect: NSObject {
    
    var detectProcessQueue: DispatchQueue
    var sequenceHandler: VNSequenceRequestHandler
    
    override init() {
        detectProcessQueue = DispatchQueue.init(label: "com.hobi.detect.queue")
        sequenceHandler = VNSequenceRequestHandler.init()
        super.init()
    }
    
    func detect(_ pixelBuffer: CVPixelBuffer, completion: VNRequestCompletionHandler?) {
        detectProcessQueue.async {
            let detectFaceRequest = VNDetectFaceLandmarksRequest(completionHandler: completion)
            
            do {
                try self.sequenceHandler.perform([detectFaceRequest], on: pixelBuffer)
            } catch {
                
            }
        }
        
    }
}
