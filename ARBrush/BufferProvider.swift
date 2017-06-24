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

import UIKit
import Metal
import simd

class BufferProvider: NSObject {
  // 1
  let inflightBuffersCount: Int
  // 2
  fileprivate var uniformsBuffers: [MTLBuffer]
  // 3
  fileprivate var avaliableBufferIndex: Int = 0
  var avaliableResourcesSemaphore:DispatchSemaphore
  
  init(device:MTLDevice, inflightBuffersCount: Int) {
    
    let sizeOfUniformsBuffer = MemoryLayout<Float>.size * (2 * float4x4.numberOfElements()) + Light.size()
    
    avaliableResourcesSemaphore = DispatchSemaphore(value: inflightBuffersCount)
    
    self.inflightBuffersCount = inflightBuffersCount
    uniformsBuffers = [MTLBuffer]()
    
    for _ in 0...inflightBuffersCount-1{
      let uniformsBuffer = device.makeBuffer(length: sizeOfUniformsBuffer, options: [])
        uniformsBuffers.append(uniformsBuffer!)
    }
  }
  
  deinit {
    for _ in 0...self.inflightBuffersCount{
      self.avaliableResourcesSemaphore.signal()
    }
  }
  
  func nextUniformsBuffer(_ projectionMatrix: float4x4, modelViewMatrix: float4x4, light: Light) -> MTLBuffer {
    
    let buffer = uniformsBuffers[avaliableBufferIndex]
    let bufferPointer = buffer.contents()
    
    // 1
    var projectionMatrix = projectionMatrix
    var modelViewMatrix = modelViewMatrix
    
    // 2
    memcpy(bufferPointer, &modelViewMatrix, MemoryLayout<Float>.size*float4x4.numberOfElements())
    memcpy(bufferPointer + MemoryLayout<Float>.size*float4x4.numberOfElements(), &projectionMatrix, MemoryLayout<Float>.size*float4x4.numberOfElements())
    memcpy(bufferPointer + 2*MemoryLayout<Float>.size*float4x4.numberOfElements(), light.raw(), Light.size())
    
    avaliableBufferIndex += 1
    if avaliableBufferIndex == inflightBuffersCount{
      avaliableBufferIndex = 0
    } 
    
    return buffer
  }
}
