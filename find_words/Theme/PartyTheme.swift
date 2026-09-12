//
//  PartyTheme.swift
//  find_words
//
//  The single source of truth for the game's bright party look:
//  colours, gradients, type scale and shared metrics.
//

import SwiftUI

enum PartyTheme {

    // MARK: - Core palette

    static let grape     = Color(red: 0.49, green: 0.23, blue: 0.93)
    static let bubble    = Color(red: 0.93, green: 0.28, blue: 0.60)
    static let tangerine = Color(red: 0.98, green: 0.57, blue: 0.24)
    static let lime      = Color(red: 0.16, green: 0.82, blue: 0.44)
    static let sky       = Color(red: 0.20, green: 0.68, blue: 1.00)
    static let lemon     = Color(red: 1.00, green: 0.84, blue: 0.24)
    static let coral     = Color(red: 1.00, green: 0.36, blue: 0.36)
    static let teal      = Color(red: 0.09, green: 0.79, blue: 0.77)
    static let ink       = Color(red: 0.13, green: 0.07, blue: 0.24)

    /// Bright, high-contrast tints handed out to players round-robin.
    static let playerColors: [Color] = [grape, tangerine, sky, bubble, lime, lemon, coral, teal]

    static func playerColor(for index: Int) -> Color {
        let count = playerColors.count
        return playerColors[((index % count) + count) % count]
    }

    // MARK: - Gradients

    /// Full-screen party canvas.
    static let canvas = LinearGradient(
        colors: [grape, bubble, tangerine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let happy = LinearGradient(
        colors: [lime, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warn = LinearGradient(
        colors: [tangerine, coral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Type

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func strong(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    // MARK: - Metrics

    static let cardRadius: CGFloat = 32
    static let buttonRadius: CGFloat = 26
    static let screenPadding: CGFloat = 22
}
