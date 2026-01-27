//
//  DnDTextRPGApp.swift
//  DnDTextRPG
//
//  D&D 5e Text-Based RPG for iOS
//

import SwiftUI

@main
struct DnDTextRPGApp: App {
    @StateObject private var gameEngine = GameEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameEngine)
                .preferredColorScheme(.dark)
        }
    }
}
