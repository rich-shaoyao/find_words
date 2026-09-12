//
//  WordEntryView.swift
//  find_words
//
//  The app's home screen. The host types a word here and taps Start Timer,
//  which is what starts the clock — not typing — so the countdown never begins
//  while they are still on the keyboard. The primary button sits directly under
//  the text field, well clear of where the keyboard covers the lower screen.
//

import SwiftUI

struct WordEntryView: View {
    @EnvironmentObject private var store: GameStore
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            titleBar
            privacyCard
            wordField
            startButton
            surpriseButton
            Spacer(minLength: 0)
            footer
        }
        .padding(PartyTheme.screenPadding)
        .task {
            // Give the first layout a beat to settle before grabbing focus:
            // asking for it during that pass can stall the whole render.
            try? await Task.sleep(nanoseconds: 400_000_000)
            isFieldFocused = true
        }
    }

    // MARK: - Pieces

    private var titleBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("FIND WORDS")
                    .font(PartyTheme.display(26))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                ScorePill(count: store.correctCount)
            }

            HStack(spacing: 8) {
                RoundPill(text: "Word \(store.roundNumber) of \(store.totalWords)")
                Spacer(minLength: 0)
            }
        }
    }

    private var privacyCard: some View {
        HStack(spacing: 10) {
            Text("👀")
                .font(.system(size: 24))
            Text("Don't let anyone else see this screen")
                .font(PartyTheme.strong(14))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.white.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
    }

    private var wordField: some View {
        VStack(spacing: 8) {
            TextField("Your word", text: Binding(
                get: { store.draftWord },
                set: {
                    store.draftWord = $0
                    store.entryMessage = nil
                }
            ))
            .font(PartyTheme.display(34))
            .foregroundStyle(PartyTheme.ink)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isFieldFocused)
            .onSubmit { store.startTimer() }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: PartyTheme.cardRadius, style: .continuous)
            )

            if let message = store.entryMessage {
                Text(message)
                    .font(PartyTheme.strong(14))
                    .foregroundStyle(PartyTheme.lemon)
            } else {
                Text("e.g. Volcano · Mermaid · Jetpack")
                    .font(PartyTheme.regular(13))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    private var startButton: some View {
        Button {
            isFieldFocused = false
            store.startTimer()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Start Timer")
            }
        }
        .buttonStyle(PartyButtonStyle(kind: .primary, compact: true))
    }

    private var surpriseButton: some View {
        Button {
            store.fillRandomWord()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dice.fill")
                Text("Surprise me")
            }
        }
        .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(store.configSummary)
                .font(PartyTheme.regular(13))
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 10) {
                Button("Settings") {
                    store.phase = .settings
                }
                .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))

                Button("How to Play") {
                    store.phase = .howToPlay
                }
                .buttonStyle(PartyButtonStyle(kind: .soft, compact: true))
            }
        }
    }
}
