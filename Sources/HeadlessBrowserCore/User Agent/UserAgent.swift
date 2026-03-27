//
//  UserAgent.swift
//  SwiftHeadlessWebKit
//
//  Created by Sungwook Baek on 2/7/26.
//

import Foundation

public enum UserAgent: String, CaseIterable, Sendable {

    // macOS Safari
    case safariMac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
    case safariMacOld = "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_6_8) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15"

    // macOS Chrome
    case chromeMac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
    case chromeMacOld = "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"

    // iPhone Safari
    case safariIPhone = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    case safariIPhoneOld = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"

    // iPad Safari
    case safariIPad = "Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    /// Random realistic user agent (recommended)
    static func random() -> String {
        return allCases.randomElement()!.rawValue
    }

    /// Desktop-only rotation
    static func desktopOnly() -> String {
        return [
            safariMac,
            safariMacOld,
            chromeMac,
            chromeMacOld
        ].randomElement()!.rawValue
    }

    /// Mobile-only rotation
    static func mobileOnly() -> String {
        return [
            safariIPhone,
            safariIPhoneOld,
            safariIPad
        ].randomElement()!.rawValue
    }
}
