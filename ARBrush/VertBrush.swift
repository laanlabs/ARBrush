//
//  VertBrush.swift
//  ARBrush
//


import Foundation
import SceneKit
import ARKit

let vertsPerPoint = 8
let maxPoints = 20000



class VertBrush {
    
    // MARK: Metal
    
    var vertexBuffer: MTLBuffer! = nil
    var indexBuffer: MTLBuffer! = nil
    
    var pipelineState: MTLRenderPipelineState! = nil
    var depthState: MTLDepthStencilState!
    
    var previousSplitLine = false
    
    var points = [SCNVector3]()
    
    
    var lastVertUpdateIdx = 0
    var lastIndexUpdateIdx = 0
    
    var prevPerpVec = SCNVector3Zero
    
    
    var currentVertIndex : Int = 0
    var currentIndexIndex : Int = 0
    
    func addVert( _ v : Vertex ) {
        
        let bufferContents = vertexBuffer.contents()
        let buffer = bufferContents.assumingMemoryBound(to: Vertex.self)
        buffer[currentVertIndex] = v
        currentVertIndex += 1
        
    }
    
    func addIndex( _ i : UInt32 ) {
        
        let bufferContents = indexBuffer.contents()
        let buffer = bufferContents.assumingMemoryBound(to: UInt32.self)
        buffer[currentIndexIndex] = i
        currentIndexIndex += 1
        
    }
    
    func addPoint( _ point : SCNVector3 ,
                   radius : Float = 0.01,
                   color : SCNVector3,
                   splitLine : Bool = false ) {
        
        if ( points.count >= maxPoints ) {
            print("Max points reached")
            return
        }
        
        points.append(point)
        
        if ( points.count == 1  ) {
            return
        }
        
        if ( splitLine ) {
            previousSplitLine = true
            return
        }
        
        
        //let green = 0.5 + 0.5*sin( 0.1 * Float(points.count) )
        
        func toVert(_ pp:SCNVector3, _ nn:SCNVector3 ) -> Vertex {
            
            return Vertex(position: vector_float4.init(pp.x, pp.y, pp.z, 1.0),
                            //color: vector_float4.init(1.0, green, 0.0, 1.0),
                            color: vector_float4.init(color.x, color.y, color.z, 1.0),
                            normal: vector_float4.init(nn.x, nn.y, nn.z, 1.0))
            
        }
        
        let pidx = points.count - 1
        
        let p1 = points[pidx]
        let p2 = points[pidx-1]
        
        let v1 = p1 - p2
        
        var v2 = SCNVector3Zero
        
        if ( SCNVector3EqualToVector3(prevPerpVec, SCNVector3Zero) ) {
            v2 = v1.cross(vector: SCNVector3(1.0, 1.0, 1.0)).normalized() * radius
        } else {
            v2 = SCNVector3ProjectPlane(vector: prevPerpVec, planeNormal: v1.normalized() ).normalized() * radius
        }
        
        prevPerpVec = v2
        
        // add p2 verts only if this is 2nd point
        if ( points.count == 2 || previousSplitLine ) {
            previousSplitLine = false
            
            for i in 0..<vertsPerPoint {
                
                let angle = (Float(i) / Float(vertsPerPoint)) * Float.pi * 2.0
                let v3 = SCNVector3Rotate(vector:v2, around:v1, radians:angle)
                //vertices.append(toVert(p2 + v3, v3.normalized()))
                addVert(toVert(p2 + v3, v3.normalized()))
                
            }
        }
        
        //let idx_start : UInt32 = UInt32(vertices.count)
        let idx_start : UInt32 = UInt32(currentVertIndex)
        
        // add current point's verts
        for i in 0..<vertsPerPoint {
            let angle = (Float(i) / Float(vertsPerPoint)) * Float.pi * 2.0
            let v3 = SCNVector3Rotate(vector:v2, around:v1, radians:angle)
            //vertices.append(toVert(p1 + v3, v3.normalized()))
            addVert(toVert(p1 + v3, v3.normalized()))
        }
        
        // add triangles
        
        let N : UInt32 = UInt32(vertsPerPoint)
        
        for i in 0..<vertsPerPoint {
            
            let idx : UInt32 = idx_start + UInt32(i)
            
            if ( i == vertsPerPoint-1 ) {
                
                addIndex( idx )
                addIndex( idx - N )
                addIndex( idx_start - N)
                addIndex( idx )
                addIndex( idx_start - N )
                addIndex( idx_start )
                
                
                
            } else {
                
                addIndex( idx )
                addIndex( idx - N )
                addIndex( idx - N + 1 )
                addIndex( idx )
                addIndex( idx - N + 1 )
                addIndex( idx + 1 )
                
            }
        }
        
        
    }
    
    
    func clear() {
        
        objc_sync_enter(self)
        
        currentVertIndex = 0
        currentIndexIndex = 0
        
        objc_sync_exit(self)
    }
    
    // Metal
    var uniforms : SharedUniforms = SharedUniforms()
    
    func updateSharedUniforms(frame: ARFrame) {
        
        // Set up lighting for the scene using the ambient intensity if provided
        var ambientIntensity: Float = 1.0
        
        if let lightEstimate = frame.lightEstimate {
            ambientIntensity = Float(lightEstimate.ambientIntensity) / 1000.0
        }
        
        let ambientLightColor: vector_float3 = vector3(0.5, 0.5, 0.5)
        uniforms.ambientLightColor = ambientLightColor * ambientIntensity
        
        var directionalLightDirection : vector_float3 = vector3(0.0, 0.0, -1.0)
        directionalLightDirection = simd_normalize(directionalLightDirection)
        uniforms.directionalLightDirection = directionalLightDirection
        
        let directionalLightColor: vector_float3 = vector3(0.6, 0.6, 0.6)
        uniforms.directionalLightColor = directionalLightColor * ambientIntensity
        
        uniforms.materialShininess = 40
        
    }
    
    
    func render(_ commandQueue: MTLCommandQueue,
                _ renderEncoder: MTLRenderCommandEncoder,
                 parentModelViewMatrix: float4x4,
                 projectionMatrix: float4x4) {
        
        
        if ( currentIndexIndex == 0 ) {return}
        
        objc_sync_enter(self)
        
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        uniforms.viewMatrix = parentModelViewMatrix
        uniforms.projectionMatrix = projectionMatrix
        
        // Here we pass the SharedUniforms using setVertexBytes because it's simpler
        // than triple buffering. Note there is a 4kb limit on how many bytes.
        // https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515846-setvertexbytes
        
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<SharedUniforms>.stride, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<SharedUniforms>.stride, index: 1)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: currentIndexIndex,
                                            indexType: MTLIndexType.uint32,
                                            indexBuffer: indexBuffer,
                                            indexBufferOffset: 0)
            
        
        objc_sync_exit(self)
        
        
    }
    
    func setupPipeline(device : MTLDevice, renderDestination : ARSCNView ) {
        
        let defaultLibrary = device.makeDefaultLibrary()
        let fragmentProgram = defaultLibrary!.makeFunction(name: "basic_fragment")
        let vertexProgram = defaultLibrary!.makeFunction(name: "basic_vertex")
        
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        
        
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthPixelFormat
        
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.add;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.add;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.one;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.one;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha;
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .greater
        depthStateDescriptor.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        let vertDataSize = vertsPerPoint * maxPoints * MemoryLayout<Vertex>.stride
        let indexDataSize = 3 * vertsPerPoint * maxPoints * MemoryLayout<Float>.stride
                
        vertexBuffer = device.makeBuffer(length: vertDataSize, options: .storageModeShared)
        indexBuffer = device.makeBuffer(length: indexDataSize, options: .storageModeShared)
        
        
    }
    
    
}
