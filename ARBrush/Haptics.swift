//
//  Haptics.swift
//
//  Created by William Perkins on 9/28/17.


import Foundation
import AudioToolbox

/**
 Some haptic feedback that works on iPhone 6 and up
 see: http://www.mikitamanko.com/blog/2017/01/29/haptic-feedback-with-uifeedbackgenerator/
 */
struct Haptics {

    static func weakBoom() {
        AudioServicesPlaySystemSound(1519) // Actuate `Peek` feedback (weak boom)
    }

    static func strongBoom() {
        AudioServicesPlaySystemSound(1520) // Actuate `Pop` feedback (strong boom)
    }

    static func threeWeakBooms() {
        AudioServicesPlaySystemSound(1521) // Actuate `Nope` feedback (series of three weak booms)
    }
}
