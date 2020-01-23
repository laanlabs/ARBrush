//
//  ShaderTypes.h
//  ARBrush
//
//  Created by cc on 1/21/20.


#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Structure shared between shader and C code to ensure the layout of shared uniform data accessed in
//    Metal shaders matches the layout of uniform data set in C code

typedef struct {
    // Camera Uniforms
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    
    // Lighting Properties
    vector_float3 ambientLightColor;
    vector_float3 directionalLightDirection;
    vector_float3 directionalLightColor;
    
    float materialShininess;
} SharedUniforms;



typedef struct Vertex {
    vector_float4 position;
    vector_float4 color;
    vector_float4 normal;
} Vertex;


#endif /* ShaderTypes_h */
