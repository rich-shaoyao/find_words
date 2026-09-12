//
//  PartyComponents.swift
//  find_words
//
//  Shared party-styled building blocks used across every screen.
//

import SwiftUI
import UIKit

// MARK: - Haptics

/// Tiny wrapper so screens (and the store) can buzz without importing UIKit everywhere.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Background

struct PartyBackground: View {
    var body: some View {
        ZStack {
            PartyTheme.canvas

            // Soft colour blooms. Built from RadialGradient instead of
            // Circle().blur(radius:): visually equivalent, but it avoids the
            // large-radius gaussian blur that is costly to rasterise on the
            // simulator software path (and costs battery on device).
            bloom(Color.white.opacity(0.42), center: .init(x: 0.16, y: 0.06), radius: 340)
            bloom(PartyTheme.lemon.opacity(0.46), center: .init(x: 0.94, y: 0.86), radius: 360)
            bloom(PartyTheme.teal.opacity(0.38), center: .init(x: 0.04, y: 0.92), radius: 300)
        }
        .ignoresSafeArea()
    }

    private func bloom(_ color: Color, center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(
            colors: [color, color.opacity(0)],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }
}

// MARK: - Buttons

struct PartyButtonStyle: ButtonStyle {

    enum Kind {
        case primary   // white pill, dark text — the main call to action
        case success   // green gradient
        case warning   // orange gradient
        case soft      // translucent — secondary actions
    }

    var kind: Kind = .primary
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PartyTheme.strong(compact ? 17 : 21))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 14 : 19)
            .padding(.horizontal, 18)
            .background(fill, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(kind == .soft ? 0.55 : 0.0), lineWidth: 2)
            )
            .shadow(
                color: .black.opacity(kind == .soft ? 0.10 : 0.22),
                radius: configuration.isPressed ? 4 : 14,
                y: configuration.isPressed ? 2 : 8
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return PartyTheme.ink
        case .success, .warning, .soft: return .white
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary: return AnyShapeStyle(Color.white)
        case .success: return AnyShapeStyle(PartyTheme.happy)
        case .warning: return AnyShapeStyle(PartyTheme.warn)
        case .soft:    return AnyShapeStyle(Color.white.opacity(0.18))
        }
    }
}

/// Small circular icon button used for back / close controls.
struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// One option in a segmented row, e.g. "30s" / "Custom".
struct ChoiceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PartyTheme.strong(14))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(isSelected ? PartyTheme.ink : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, 4)
                .background(
                    isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.16)),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pills

/// Rounded translucent label, e.g. "WORD 2 OF 10".
struct RoundPill: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(PartyTheme.strong(13))
        .foregroundStyle(.white)
        .textCase(.uppercase)
        .kerning(0.8)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2), in: Capsule())
    }
}

/// "✓ 3 correct" counter shown while playing.
struct ScorePill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text("\(count)")
                .monospacedDigit()
        }
        .font(PartyTheme.strong(14))
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(PartyTheme.lime.opacity(0.55), in: Capsule())
    }
}

// MARK: - Timer

struct TimerBar: View {
    let remaining: Double
    let total: Double

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(max(0, min(1, remaining / total)))
    }

    private var secondsLeft: Int {
        max(0, Int(remaining.rounded(.up)))
    }

    private var isUrgent: Bool { secondsLeft <= 10 }

    private var barColor: Color {
        if secondsLeft <= 10 { return PartyTheme.coral }
        if secondsLeft <= 20 { return PartyTheme.lemon }
        return PartyTheme.lime
    }

    private var label: String {
        let minutes = secondsLeft / 60
        let seconds = secondsLeft % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(PartyTheme.display(40))
                    .foregroundStyle(isUrgent ? PartyTheme.lemon : .white)
                    .monospacedDigit()
                Spacer()
                if isUrgent {
                    Text("Hurry!")
                        .font(PartyTheme.strong(17))
                        .foregroundStyle(PartyTheme.lemon)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22))
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 14)
        }
        .animation(.linear(duration: 0.15), value: fraction)
    }
}
