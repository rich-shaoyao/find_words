//
//  RootView.swift
//  find_words
//
//  Owns the game state and shows exactly one screen for the current phase.
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = GameStore()

    var body: some View {
        ZStack {
            PartyBackground()

            switch store.phase {
            case .home:      HomeView()
            case .howToPlay: HowToPlayView()
            case .wordEntry: WordEntryView()
            case .playing:   RoundPlayView()
            case .timedOut:  TimedOutView()
            case .summary:   SummaryView()
            }
        }
        .environmentObject(store)
        .animation(.easeInOut(duration: 0.28), value: store.phase)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
