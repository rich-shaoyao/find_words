//
//  find_wordsApp.swift
//  find_words
//
//  Created by 李少尧 on 2026/9/12.
//

import SwiftUI

@main
struct find_wordsApp: App {

    init() {
        // Start the Google Mobile Ads SDK once, before the first ad request.
        // Info.plist carries the matching GADApplicationIdentifier (test app ID for now).
        QiAdManager.shared.startSDK()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
