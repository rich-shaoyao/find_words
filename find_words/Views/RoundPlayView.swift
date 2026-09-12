//
//  RoundPlayView.swift
//  find_words
//
//  The heart of the game: the Describer sees the word while the clock runs.
//

import SwiftUI
import UIKit

/// Tiny wrapper so screens can buzz without pulling UIKit into the call sites.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

struct RoundPlayView: View {
    @EnvironmentObject private var store: GameStore

    private var secondsLeft: Int {
        max(0, Int(store.timeRemaining.rounded(.up)))
    }

    var body: some View {
        VStack(spacing: 16) {
            topBar

            TimerBar(remaining: store.timeRemaining, total: Double(store.roundDuration))

            wordCard

            Text("Describe it out loud — never say the word!")
                .font(PartyTheme.strong(15))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            actionButtons
        }
        .padding(PartyTheme.screenPadding)
        .sensoryFeedback(.impact(weight: .heavy), trigger: secondsLeft) { oldValue, newValue in
            newValue <= 5 && newValue >= 1 && newValue < oldValue
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(spacing: 10) {
            RoundPill(text: "Round \(store.roundNumber) of \(store.totalRounds)")

            Spacer(minLength: 6)

            if let describer = store.describer {
                HStack(spacing: 7) {
                    AvatarCircle(name: describer.displayName, tint: describer.tint, diameter: 30)
                    Text(describer.displayName)
                        .font(PartyTheme.strong(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
    }

    private var wordCard: some View {
        Text(store.word)
            .font(PartyTheme.display(62))
            .foregroundStyle(PartyTheme.ink)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.16)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.impact(.rigid)
                store.skipRound()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.forward")
                    Text("Skip")
                }
            }
            .buttonStyle(PartyButtonStyle(kind: .warning, compact: true))

            Button {
                Haptics.notify(.success)
                store.markGuessed()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                    Text("Got It!")
                }
            }
            .buttonStyle(PartyButtonStyle(kind: .success, compact: true))
        }
    }
}
