//
//  ContentView.swift
//  DnDTextRPGWatch
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dungeons & Dragons")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.green)
                Text("Text-Based Adventure")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))

                Divider()

                Text("PARTY STATUS")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                Text("Open the game on your iPhone to explore the dungeon. A live party glance is coming soon.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    ContentView()
}
