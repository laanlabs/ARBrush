/**
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <metal_stdlib>
using namespace metal;

// 1
struct VertexIn {
  packed_float3 position;
  packed_float4 color;
  packed_float2 texCoord;
  packed_float3 normal;
};

struct VertexOut {
  float4 position [[position]];
  float3 fragmentPosition;
  float4 color;
  float2 texCoord;
  float3 normal;
    float vid;
};

struct Light {
  packed_float3 color;      // 0 - 2
  float ambientIntensity;          // 3
  packed_float3 direction;  // 4 - 6
  float diffuseIntensity;   // 7
  float shininess;          // 8
  float specularIntensity;  // 9
    float time;
  
  /*
   _______________________
   |0 1 2 3|4 5 6 7|8 9    |
   -----------------------
   |       |       |       |
   | chunk0| chunk1| chunk2|
   */
};

struct Uniforms{
  float4x4 modelMatrix;
  float4x4 projectionMatrix;
  Light light;
};

vertex VertexOut basic_vertex(
                              const device VertexIn* vertex_array [[ buffer(0) ]],
                              const device Uniforms&  uniforms    [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {
  
  float4x4 mv_Matrix = uniforms.modelMatrix;
  float4x4 proj_Matrix = uniforms.projectionMatrix;
  
  VertexIn VertexIn = vertex_array[vid];
    
    //float3 newPos = VertexIn.position + VertexIn.normal * sin(uniforms.light.time*3 + VertexIn.position[1] * 100.0 ) * 0.001;
    //float3 newPos = VertexIn.position + VertexIn.normal * (0.8+sin(uniforms.light.time*3 + vid * 0.1 )) * 0.002;
    float3 newPos = VertexIn.position + VertexIn.normal * (0.8+sin(uniforms.light.time*3 + vid * 0.05 )) * 0.001;
    
  VertexOut VertexOut;
  VertexOut.position = proj_Matrix * mv_Matrix * float4(newPos,1);
  VertexOut.fragmentPosition = (mv_Matrix * float4(VertexIn.position,1)).xyz;
  VertexOut.color = VertexIn.color;
  // 2
  VertexOut.texCoord = VertexIn.texCoord;
  VertexOut.normal = (mv_Matrix * float4(VertexIn.normal, 0.0)).xyz;
    VertexOut.vid = vid;
    
  return VertexOut;
}


// 3
fragment float4 basic_fragment(VertexOut interpolated [[stage_in]],
                               const device Uniforms&  uniforms    [[ buffer(1) ]]
                               ) {
    
    // Ambient
    Light light = uniforms.light;
    float4 ambientColor = float4(light.color * light.ambientIntensity, 1);
    
    //Diffuse
    float diffuseFactor = max(0.0,dot(interpolated.normal, light.direction)); // 1
    float4 diffuseColor = float4(light.color * light.diffuseIntensity * diffuseFactor ,1.0); // 2
    
    //Specular
    float3 eye = normalize(interpolated.fragmentPosition); //1
    float3 reflection = reflect(light.direction, interpolated.normal); // 2
    float specularFactor = pow(max(0.0, dot(reflection, eye)), light.shininess); //3
    float4 specularColor = float4(light.color * light.specularIntensity * specularFactor ,1.0);//4
    
    float4 norm = float4(interpolated.normal, 1.0);
    
    //norm.r += 0.4 * sin( interpolated.vid * 0.1 );
    
    // 5
    //float4 color = float4(1.0,0.5,0.1,1.0); //tex2D.sample(sampler2D, interpolated.texCoord);
    //return color * (ambientColor + diffuseColor + specularColor);
    return norm * (ambientColor + diffuseColor + specularColor);
    //return color;
}


//// 3
//fragment float4 basic_fragment(VertexOut interpolated [[stage_in]],
//                               const device Uniforms&  uniforms    [[ buffer(1) ]],
//                               texture2d<float>  tex2D     [[ texture(0) ]],
//                               sampler           sampler2D [[ sampler(0) ]]) {
//
//  // Ambient
//  Light light = uniforms.light;
//  float4 ambientColor = float4(light.color * light.ambientIntensity, 1);
//
//  //Diffuse
//  float diffuseFactor = max(0.0,dot(interpolated.normal, light.direction)); // 1
//  float4 diffuseColor = float4(light.color * light.diffuseIntensity * diffuseFactor ,1.0); // 2
//
//  //Specular
//  float3 eye = normalize(interpolated.fragmentPosition); //1
//  float3 reflection = reflect(light.direction, interpolated.normal); // 2
//  float specularFactor = pow(max(0.0, dot(reflection, eye)), light.shininess); //3
//  float4 specularColor = float4(light.color * light.specularIntensity * specularFactor ,1.0);//4
//
//  // 5
//  float4 color = tex2D.sample(sampler2D, interpolated.texCoord);
//  return color * (ambientColor + diffuseColor + specularColor);
//}

