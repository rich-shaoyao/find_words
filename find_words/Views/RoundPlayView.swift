//
//  RoundPlayView.swift
//  find_words
//
//  The clock is running: the host sees the word and taps Correct or Skip.
//

import SwiftUI

struct RoundPlayView: View {
    @EnvironmentObject private var store: GameStore
    @State private var confirmQuit = false

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
        .overlay { flashOverlay }
        .sensoryFeedback(.impact(weight: .heavy), trigger: secondsLeft) { oldValue, newValue in
            newValue <= 5 && newValue >= 1 && newValue < oldValue
        }
        .alert("End this game?", isPresented: $confirmQuit) {
            Button("End Game", role: .destructive) { endGameWithRewardedAd() }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text(quitMessage)
        }
    }

    /// 渠道验证包专用（Debug）：结束前尽力展示一次激励视频 —— 就绪则播完再结束，
    /// 未就绪则后台重拉并直接结束，不阻塞玩家。
    /// 上架包（Release 不定义 HIDDEN_AD_PANEL_ENABLED）整段不编译，点 End Game 直接结束。
    private func endGameWithRewardedAd() {
        #if HIDDEN_AD_PANEL_ENABLED
        guard QiAdManager.shared.isAdReady(of: .rewarded) else {
            QiAdManager.shared.preloadAds()
            store.finishEarly()
            return
        }
        QiAdManager.shared.showAd(of: .rewarded) { _ in
            store.finishEarly()
        }
        #else
        store.finishEarly()
        #endif
    }

    private var quitMessage: String {
        let played = store.wordsPlayed
        guard played > 0 else { return "You haven't finished any words yet." }
        return "You've played \(played) of \(store.totalWords) words, with \(store.correctCount) correct."
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(spacing: 8) {
            RoundIconButton(systemName: "xmark") { confirmQuit = true }
            Spacer(minLength: 0)
            RoundPill(text: "Word \(store.roundNumber) of \(store.totalWords)")
            Spacer(minLength: 0)
            ScorePill(count: store.correctCount)
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
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 36, style: .continuous)
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                store.markSkipped()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.forward")
                    Text("Skip")
                }
            }
            .buttonStyle(PartyButtonStyle(kind: .warning, compact: true))

            Button {
                store.markCorrect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                    Text("Correct")
                }
            }
            .buttonStyle(PartyButtonStyle(kind: .success, compact: true))
        }
        .disabled(store.flash != nil)
    }

    /// Full-screen green / orange confirmation for the tap that just happened.
    @ViewBuilder
    private var flashOverlay: some View {
        if let flash = store.flash {
            ZStack {
                (flash == .correct ? PartyTheme.lime : PartyTheme.tangerine)
                    .opacity(0.94)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Image(systemName: flash == .correct
                          ? "checkmark.circle.fill"
                          : "arrow.uturn.forward.circle.fill")
                        .font(.system(size: 78, weight: .bold))
                    Text(flash == .correct ? "Correct!" : "Skipped")
                        .font(PartyTheme.display(34))
                }
                .foregroundStyle(.white)
            }
            .transition(.opacity)
        }
    }
}
