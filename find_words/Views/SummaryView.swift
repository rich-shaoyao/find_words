//
//  SummaryView.swift
//  find_words
//
//  Final score. Only one number matters: how many words were guessed.
//

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            Text("🎯")
                .font(.system(size: 58))

            scoreBlock

            accuracyRing

            VStack(spacing: 4) {
                Text(store.configSummary)
                    .font(PartyTheme.regular(14))
                    .foregroundStyle(.white.opacity(0.85))

                if store.endedEarly {
                    Text("Ended early")
                        .font(PartyTheme.strong(13))
                        .foregroundStyle(PartyTheme.lemon)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button("Play Again") {
                    store.playAgain()
                }
                .buttonStyle(PartyButtonStyle(kind: .primary))

                HStack(spacing: 10) {
                    Button("Settings") {
                        store.backToHome(showingSettings: true)
                    }
                    .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))

                    Button("Home") {
                        store.backToHome()
                    }
                    .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))
                }
            }
        }
        .padding(PartyTheme.screenPadding)
        .onAppear { Haptics.notify(.success) }
    }

    // MARK: - Pieces

    private var scoreBlock: some View {
        VStack(spacing: 2) {
            Text("\(store.correctCount)")
                .font(PartyTheme.display(88))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("CORRECT")
                .font(PartyTheme.strong(15))
                .foregroundStyle(.white.opacity(0.85))
                .kerning(3.5)
        }
    }

    private var accuracyRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0.001, store.accuracy))
                .stroke(
                    PartyTheme.lime,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int((store.accuracy * 100).rounded()))%")
                    .font(PartyTheme.display(26))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("ACCURACY")
                    .font(PartyTheme.strong(10))
                    .foregroundStyle(.white.opacity(0.75))
                    .kerning(1.6)
            }
        }
        .frame(width: 128, height: 128)
        .animation(.snappy, value: store.accuracy)
    }
}
