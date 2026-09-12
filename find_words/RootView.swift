//
//  RootView.swift
//  find_words
//
//  Owns the game state and shows exactly one screen for the current phase.
//  The entry screen doubles as the home screen, so a fresh launch can start
//  a game straight away with whatever settings were last used.
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = GameStore()

    var body: some View {
        ZStack {
            PartyBackground()

            switch store.phase {
            case .wordEntry: WordEntryView()
            case .settings:  SettingsView()
            case .howToPlay: HowToPlayView()
            case .playing:   RoundPlayView()
            case .timedOut:  TimedOutView()
            case .summary:   SummaryView()
            }
        }
        .environmentObject(store)
        .animation(.easeInOut(duration: 0.28), value: store.phase)
        .overlay {
            hiddenAdPanelOverlay
        }
    }

    /// Hidden ad panel (ad_layout skill 8) sits above every screen while it is open.
    /// With the macro off the whole implementation is compiled out, so this is empty.
    @ViewBuilder
    private var hiddenAdPanelOverlay: some View {
        #if HIDDEN_AD_PANEL_ENABLED
        HiddenAdPanelOverlay()
        #endif
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
