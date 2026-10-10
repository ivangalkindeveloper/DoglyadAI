import SwiftUI

public struct DColor {
    public let primaryDefault: Color
    public let primaryDefaultStrong: Color
    public let primaryDefaultWeak: Color
    public let primaryBackgroundStrong: Color

    public let grayscaleHeader: Color
    public let grayscaleHeaderWeak: Color
    public let grayscaleBody: Color
    public let grayscaleLabel: Color
    public let grayscalePlacehold: Color
    public let grayscaleLine: Color
    public let grayscaleInput: Color
    public let grayscaleBackgroundWeak: Color
    public let grayscaleBackground: Color

    public let secondaryDefault: Color
    public let secondaryDefaultStrong: Color
    public let secondaryDefaultWeak: Color
    public let secondaryBackgroundStrong: Color
    public let secondaryBackground: Color

    public let successDefault: Color
    public let successDefaultStrong: Color
    public let successDefaultWeak: Color
    public let successBackgroundStrong: Color
    public let successBackground: Color

    public let warningDefault: Color
    public let warningDefaultStrong: Color
    public let warningDefaultWeak: Color
    public let warningBackgroundStrong: Color
    public let warningBackground: Color

    public let dangerDefault: Color
    public let dangerDefaultStrong: Color
    public let dangerDefaultWeak: Color
    public let dangerBackgroundStrong: Color
    public let dangerBackground: Color

    public let gradientPrimary: LinearGradient
    public let gradientPrimaryWeak: LinearGradient
    public let gradientSecondary: LinearGradient
    public let gradientAccent: LinearGradient
}

public extension DColor {
    static let light = DColor(
        primaryDefault: Color(
            hex: 0x610BEF,
        ),
        primaryDefaultStrong: Color(
            hex: 0x4700AB,
        ),
        primaryDefaultWeak: Color(
            hex: 0xA996FF,
        ),
        primaryBackgroundStrong: Color(
            hex: 0xBFBEFC,
        ),

        grayscaleHeader: Color(
            hex: 0x14142B,
        ),
        grayscaleHeaderWeak: Color(
            hex: 0x262338,
        ),
        grayscaleBody: Color(
            hex: 0x4E4B66,
        ),
        grayscaleLabel: Color(
            hex: 0x6E7191,
        ),
        grayscalePlacehold: Color(
            hex: 0xA0A3BD,
        ),
        grayscaleLine: Color(
            hex: 0xD9DBE9,
        ),
        grayscaleInput: Color(
            hex: 0xEFF0F6,
        ),
        grayscaleBackgroundWeak: Color(
            hex: 0xF7F7FC,
        ),
        grayscaleBackground: Color(
            hex: 0xFCFCFC,
        ),

        secondaryDefault: Color(
            hex: 0x005BD4,
        ),
        secondaryDefaultStrong: Color(
            hex: 0x0041AC,
        ),
        secondaryDefaultWeak: Color(
            hex: 0x50C8FC,
        ),
        secondaryBackgroundStrong: Color(
            hex: 0x8DE9FF,
        ),
        secondaryBackground: Color(
            hex: 0xE3FEFF,
        ),

        successDefault: Color(
            hex: 0x008A00,
        ),
        successDefaultStrong: Color(
            hex: 0x067306,
        ),
        successDefaultWeak: Color(
            hex: 0xA6F787,
        ),
        successBackgroundStrong: Color(
            hex: 0xCBFFAE,
        ),
        successBackground: Color(
            hex: 0xEAF9DE,
        ),

        warningDefault: Color(
            hex: 0xEAAC30,
        ),
        warningDefaultStrong: Color(
            hex: 0x946300,
        ),
        warningDefaultWeak: Color(
            hex: 0xFFDF9A,
        ),
        warningBackgroundStrong: Color(
            hex: 0xFFE6B0,
        ),
        warningBackground: Color(
            hex: 0xFFF8E9,
        ),

        dangerDefault: Color(
            hex: 0xCA024F,
        ),
        dangerDefaultStrong: Color(
            hex: 0x9E0038,
        ),
        dangerDefaultWeak: Color(
            hex: 0xFF75CB,
        ),
        dangerBackgroundStrong: Color(
            hex: 0xFFABE8,
        ),
        dangerBackground: Color(
            hex: 0xFFECFC,
        ),

        gradientPrimary: LinearGradient(
            colors: [
                Color(
                    hex: 0x7433FF,
                ),
                Color(
                    hex: 0xFFA3FD,
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        ),
        gradientPrimaryWeak: LinearGradient(
            colors: [
                Color(
                    hex: 0x7433FF,
                ),
                Color(
                    hex: 0xDE5EFC,
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        ),
        gradientSecondary: LinearGradient(
            colors: [
                Color(
                    hex: 0x624AF2,
                ),
                Color(
                    hex: 0x50DDC3,
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        ),
        gradientAccent: LinearGradient(
            colors: [
                Color(
                    hex: 0xEB0055,
                ),
                Color(
                    hex: 0xFFFA80,
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        ),
    )
}
