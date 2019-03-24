//
//  Vertext.h
//  HBCamera
//
//  Created by hebi on 2019/3/23.
//  Copyright © 2019 Hobi. All rights reserved.
//



#ifndef Vertext_h
#define Vertext_h

#include <simd/simd.h>

struct HBVertex {
    vector_float4 position;
    vector_float2 texturePosition;
};

struct HBFaceInfo {
    vector_float2 pointArray[68];
};


#endif /* Vertext_h */
