//
//  CVPixelBuffer+Extension.swift
//  HBCamera
//
//  Created by Hobi on 2019/3/21.
//  Copyright © 2019 Hobi. All rights reserved.
//

import Foundation

extension CVPixelBuffer {
    /// Deep copy a CVPixelBuffer:
    ///   http://stackoverflow.com/questions/38335365/pulling-data-from-a-cmsamplebuffer-in-order-to-create-a-deep-copy
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")
        
        var _copy: CVPixelBuffer?
        
        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            CVBufferGetAttachments(self, .shouldPropagate),
            &_copy)
        
        guard let copy = _copy else { fatalError() }
        
        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        defer
        {
            CVPixelBufferUnlockBaseAddress(copy, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        
        for plane in 0 ..< CVPixelBufferGetPlaneCount(self)
        {
            let dest        = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
            let source      = CVPixelBufferGetBaseAddressOfPlane(self, plane)
            let height      = CVPixelBufferGetHeightOfPlane(self, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
            
            memcpy(dest, source, height * bytesPerRow)
        }
        
        return copy
    }
}
