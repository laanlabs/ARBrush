
#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"


using namespace metal;


struct VertexOut {
    float4 position [[position]];
    float3 fragmentPosition;
    float4 color;
    float2 texCoord;
    half3  eyePosition;
    float3 normal;
    float vid;
};


vertex VertexOut basic_vertex(
                              const device Vertex* vertex_array [[ buffer(0) ]],
                              constant SharedUniforms &uniforms [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]] )
{

    float4x4 mv_Matrix = uniforms.viewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    
    Vertex in = vertex_array[vid];
    
    // + VertexIn.normal * (0.8+sin(uniforms.light.time*3 + vid * 0.05 )) * 0.001;
    
    float3 pos = in.position.xyz;
    
    VertexOut out;
    
    out.position = proj_Matrix * mv_Matrix * float4(pos, 1);
    
    out.position.z = out.position.z / out.position.w;
    out.position.z = 1.0 - out.position.z;
    out.position.z = out.position.z * out.position.w;
    
    
    out.eyePosition = half3((mv_Matrix * float4(pos, 1)).xyz);
    
    out.fragmentPosition = out.position.xyz;
    out.color.rgb = in.color.rgb;
    
    
    out.normal = (mv_Matrix * float4(in.normal.xyz, 0.0)).xyz;
    out.vid = vid;
    
    return out;
    
}


//constant SharedUniforms &sharedUniforms [[ buffer(kBufferIndexSharedUniforms) ]]

fragment float4 basic_fragment(VertexOut in [[stage_in]],
                               constant SharedUniforms &uniforms [[ buffer(1) ]]
                               ) {
    
    
    float3 normal = float3(in.normal);
    
    // Calculate the contribution of the directional light as a sum of diffuse and specular terms
    float3 directionalContribution = float3(0);
    {
        // Light falls off based on how closely aligned the surface normal is to the light direction
        float nDotL = saturate(dot(normal, -uniforms.directionalLightDirection));
        
        // The diffuse term is then the product of the light color, the surface material
        // reflectance, and the falloff
        float3 diffuseTerm = uniforms.directionalLightColor * nDotL;
        
        // Apply specular lighting...
        
        // 1) Calculate the halfway vector between the light direction and the direction they eye is looking
        float3 halfwayVector = normalize(-uniforms.directionalLightDirection - float3(in.eyePosition));
        
        // 2) Calculate the reflection angle between our reflection vector and the eye's direction
        float reflectionAngle = saturate(dot(normal, halfwayVector));
        
        // 3) Calculate the specular intensity by multiplying our reflection angle with our object's
        //    shininess
        float specularIntensity = saturate(powr(reflectionAngle, uniforms.materialShininess));
        
        // 4) Obtain the specular term by multiplying the intensity by our light's color
        float3 specularTerm = uniforms.directionalLightColor * specularIntensity;
        
        // Calculate total contribution from this light is the sum of the diffuse and specular values
        directionalContribution = diffuseTerm + specularTerm;
    }
    
    // The ambient contribution, which is an approximation for global, indirect lighting, is
    // the product of the ambient light intensity multiplied by the material's reflectance
    float3 ambientContribution = uniforms.ambientLightColor;
    
    // Now that we have the contributions our light sources in the scene, we sum them together
    // to get the fragment's lighting value
    float3 lightContributions = ambientContribution + directionalContribution;
    
    // We compute the final color by multiplying the sample from our color maps by the fragment's
    // lighting value
    
    // Hack: if the color is negative, use the normal as the color
    if ( in.color.x < -0.5 ) {
        in.color.rgb = normal.rgb;
    }
    
    float3 color = in.color.rgb * lightContributions;
    
    // We use the color we just computed and the alpha channel of our
    // colorMap for this fragment's alpha value
    return float4(color, in.color.w);
    
    
    //return norm * (ambientColor + diffuseColor + specularColor);
    
    
}
