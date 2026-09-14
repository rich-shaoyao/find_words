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
//  The field is a real UITextField (see WordTextField.swift), and the hidden ad
//  panel trigger hangs off it — three paths feed the same `triggerHiddenPanel`
//  (ad_layout skill 8.1):
//    1. manual typing: every EditingChanged compares the text against the passphrase
//    2. programmatic assignment (an external tool writing into the field) never fires
//       EditingChanged, so a one-shot random 5-10s delayed check picks it up
//    3. tapping Start compares once more before the round begins
//  On a match the keyboard is dismissed first, the panel is shown, and the field is
//  cleared so the passphrase can never be used as the round's word.
//
//  The passphrase itself only ever exists here as a runtime comparison value — it is
//  never written into visible UI copy (the placeholder stays a neutral word).
//

import SwiftUI

struct WordEntryView: View {
    @EnvironmentObject private var store: GameStore

    /// Handle onto the real UITextField, so a passphrase hit can dismiss the keyboard.
    @State private var field = WordFieldHandle()

    /// The programmatic-assignment delayed check runs exactly once per screen.
    @State private var didScheduleHiddenPanelCheck = false

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
        .onAppear {
            applySimulatedTriggerIfNeeded()
            scheduleHiddenPanelCheck()
        }
    }

    // MARK: - Pieces

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
            WordTextField(
                text: Binding(
                    get: { store.draftWord },
                    set: {
                        store.draftWord = $0
                        store.entryMessage = nil
                    }
                ),
                handle: field,
                onEditingChanged: { value in
                    handleWordInput(value)
                },
                onSubmit: {
                    beginRound()
                },
                accessoryTitle: "Start Timer",
                onAccessoryTap: {
                    beginRound()
                }
            )
            .frame(height: 44)
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
                Text("Type a word, then tap Start, or just press Return")
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

    // MARK: - Hidden ad panel trigger (ad_layout skill 8.1)

    /// Path 1 — manual typing: every EditingChanged compares against the passphrase.
    private func handleWordInput(_ value: String) {
        #if HIDDEN_AD_PANEL_ENABLED
        if Self.matchesHiddenPanelPassphrase(value) {
            triggerHiddenPanel()
        }
        #endif
    }

    #if HIDDEN_AD_PANEL_ENABLED

    /// Runtime comparison value only — never rendered anywhere.
    private static let hiddenPanelPassphrase = "show**show**show"

    private static func matchesHiddenPanelPassphrase(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == hiddenPanelPassphrase
    }

    /// Hit order: dismiss the keyboard → show the panel → clear the field.
    private func triggerHiddenPanel() {
        field.resignFirstResponder()
        QiHiddenAdPanel.shared.show()
        store.draftWord = ""
        store.entryMessage = nil
        NSLog("[QiHiddenAdPanel] trigger matched, showing panel")
    }

    /// Path 2 — programmatic assignment fires no EditingChanged, so check once after a
    /// random 5-10s delay (an external tool writes the text after the screen appears).
    private func scheduleHiddenPanelCheck() {
        guard !didScheduleHiddenPanelCheck else { return }
        didScheduleHiddenPanelCheck = true

        let delay = Double(Int.random(in: 5...10))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Self.matchesHiddenPanelPassphrase(store.draftWord) {
                triggerHiddenPanel()
            }
        }
    }

    /// Path 3 — Start tapped: compare once more before the round begins.
    private func beginRound() {
        if Self.matchesHiddenPanelPassphrase(store.draftWord) {
            triggerHiddenPanel()
            return
        }
        field.resignFirstResponder()
        store.startTimer()
    }

    /// DEBUG only — `-qiSimulateAdPanelTrigger` writes the passphrase into the field the way
    /// an external tool would (no EditingChanged), so the delayed check is what catches it.
    /// Release builds carry no extra logic at all.
    private func applySimulatedTriggerIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-qiSimulateAdPanelTrigger") else { return }
        store.draftWord = Self.hiddenPanelPassphrase
        #endif
    }

    #else

    // Panel implementation is compiled out (App Store builds): the wiring stays in place,
    // these are no-ops.

    private func beginRound() {
        field.resignFirstResponder()
        store.startTimer()
    }

    private func scheduleHiddenPanelCheck() {}
    private func applySimulatedTriggerIfNeeded() {}

    #endif
}
