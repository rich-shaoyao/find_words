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
             detail: "Type one word. Keep the screen to yourself — nobody else should read it."),
        Step(emoji: "⏱️",
             title: "2. Hit Start Timer",
             detail: "The clock starts the moment you tap. It runs for the whole word."),
        Step(emoji: "🗣️",
             title: "3. Describe it",
             detail: "Explain the word out loud. Say anything except the word itself."),
        Step(emoji: "✅",
             title: "4. Correct or Skip",
             detail: "Tap Correct when someone guesses it. Tap Skip to move on."),
        Step(emoji: "🎯",
             title: "5. Only correct counts",
             detail: "The final score is how many words were guessed. Skipping doesn't score, but it does use up one of your words.")
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
                                .font(.system(size: 30))
                                .frame(width: 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(PartyTheme.strong(18))
                                    .foregroundStyle(.white)
                                Text(step.detail)
                                    .font(PartyTheme.regular(15))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(15)
                        .background(
                            Color.white.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                    }

                    Text("Round length and word count are set on the home screen.")
                        .font(PartyTheme.regular(14))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button("Got It") {
                store.phase = .home
            }
            .buttonStyle(PartyButtonStyle(kind: .primary))
        }
        .padding(PartyTheme.screenPadding)
    }
}
