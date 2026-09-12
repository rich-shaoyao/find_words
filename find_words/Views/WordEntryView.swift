//
//  WordEntryView.swift
//  find_words
//
//  The app's home screen. The host types a word here and starts the clock — not
//  by typing, but by an explicit Start, so the countdown never begins while they
//  are still on the keyboard.
//
//  The field is deliberately NOT focused on appear: bringing the keyboard up by
//  itself competed with the tap targets on the same screen.
//
//  Start is offered three ways on purpose. With the software keyboard up, taps
//  on the page underneath can be swallowed entirely (seen on the simulator,
//  where the keyboard renders invisibly but still eats taps). The keyboard bar
//  item and the Return key both sit in the keyboard layer, so they keep working
//  when the page-level button cannot be reached.
//

import SwiftUI

struct WordEntryView: View {
    @EnvironmentObject private var store: GameStore
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
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

            privacyCard

            wordField

            startButton

            surpriseButton

            Spacer(minLength: 0)

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
        .padding(PartyTheme.screenPadding)
    }

    // MARK: - Pieces

    private func beginRound() {
        isFieldFocused = false
        store.startTimer()
    }

    private var privacyCard: some View {
        HStack(spacing: 8) {
            Text("👀")
                .font(.system(size: 20))
            Text("Don't let anyone else see this screen")
                .font(PartyTheme.strong(13))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.white.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
    }

    private var wordField: some View {
        VStack(spacing: 6) {
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
            .onSubmit { beginRound() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        beginRound()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Start Timer")
                        }
                        .font(PartyTheme.strong(17))
                    }
                    .foregroundStyle(PartyTheme.grape)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
            beginRound()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(store.canStartRound ? "Start Timer" : "Start with Random Word")
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
}
