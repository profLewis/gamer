//
//  DnDTextRPGApp.swift
//  DnDTextRPG
//
//  D&D 5e Text-Based RPG for iOS
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct DnDTextRPGApp: App {
    @StateObject private var gameEngine = GameEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameEngine)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let window = NSApplication.shared.windows.first {
                            window.toggleFullScreen(nil)
                        }
                    }
                }
                #endif
        }
    }
}
