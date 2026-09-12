//
//  HowToPlayView.swift
//  find_words
//

import SwiftUI

struct HowToPlayView: View {
    @EnvironmentObject private var store: GameStore

    private struct Step: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(emoji: "✍️",
             title: "1. Set the word",
             detail: "One player secretly types a word. Nobody else looks at the screen."),
        Step(emoji: "📱",
             title: "2. Pass the phone",
             detail: "Hand it to the Describer — the only player allowed to see the word."),
        Step(emoji: "🗣️",
             title: "3. Describe it",
             detail: "Explain the word out loud. Never say the word itself, or any part of it."),
        Step(emoji: "🙋",
             title: "4. Guess it",
             detail: "Everyone else shouts guesses. Whoever gets it right scores a point."),
        Step(emoji: "🔁",
             title: "5. Rotate & repeat",
             detail: "Every player describes once. Highest score when the last round ends wins.")
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                RoundIconButton(systemName: "chevron.left") {
                    store.phase = .home
                }
                Spacer()
                RoundPill(text: "How to Play")
                Spacer()
                Color.clear.frame(width: 42, height: 42)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Text(step.emoji)
                                .font(.system(size: 32))
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(PartyTheme.strong(19))
                                    .foregroundStyle(.white)
                                Text(step.detail)
                                    .font(PartyTheme.regular(15))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(
                            Color.white.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                    }

                    Text("Tip: you need at least \(GameRules.minimumPlayers) players — one to set the word, one to describe it, and one to guess.")
                        .font(PartyTheme.regular(14))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .padding(.bottom, 8)
            }

            Button("Got It") {
                store.phase = .home
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
        }
        .padding(PartyTheme.screenPadding)
    }
}
