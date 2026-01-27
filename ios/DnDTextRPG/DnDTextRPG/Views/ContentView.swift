//
//  ContentView.swift
//  DnDTextRPG
//
//  Main content view that manages splash screen and game
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var showingSplash = true
    @State private var splashOpacity = 1.0

    let terminalBackground = Color.black

    var body: some View {
        ZStack {
            // Main terminal view (always present)
            TerminalView()
                .opacity(showingSplash ? 0 : 1)

            // Splash screen overlay
            if showingSplash {
                SplashView(onDismiss: dismissSplash)
                    .opacity(splashOpacity)
                    .transition(.opacity)
            }
        }
        .background(terminalBackground)
        .statusBar(hidden: true)
    }

    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.5)) {
            splashOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingSplash = false
        }
    }
}

struct SplashView: View {
    let onDismiss: () -> Void
    @State private var animationPhase = 0

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalBackground = Color.black

    var body: some View {
        ZStack {
            terminalBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Dragon ASCII art
                Text(dragonArt)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(terminalGreen)
                    .multilineTextAlignment(.center)
                    .opacity(animationPhase >= 1 ? 1 : 0)

                // Title
                VStack(spacing: 4) {
                    Text("DUNGEONS")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(terminalGreen)

                    Text("& DRAGONS")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(terminalGreen.opacity(0.8))

                    Text("5th Edition")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(terminalGreen.opacity(0.6))
                }
                .opacity(animationPhase >= 2 ? 1 : 0)

                Spacer()

                // Subtitle
                Text("TEXT-BASED ADVENTURE")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(terminalGreen.opacity(0.7))
                    .opacity(animationPhase >= 3 ? 1 : 0)

                // Tap to continue
                Text("[ Tap to Begin ]")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(terminalGreen)
                    .opacity(animationPhase >= 4 ? (blinkOpacity) : 0)
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .onTapGesture {
            if animationPhase >= 4 {
                onDismiss()
            }
        }
        .onAppear {
            runAnimation()
        }
    }

    @State private var blinkOpacity = 1.0

    private func runAnimation() {
        // Animate in phases
        withAnimation(.easeIn(duration: 0.5)) {
            animationPhase = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                animationPhase = 2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                animationPhase = 3
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                animationPhase = 4
            }
            // Start blinking
            startBlinking()
        }
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                blinkOpacity = blinkOpacity == 1.0 ? 0.3 : 1.0
            }
        }
    }

    private var dragonArt: String {
        """
____
/    \\
_.---.._    /  ##  \\
_.-'`       `'-./   ##   |
_.-'    \\.    .    /         |
.-'  ####   \\\\  //  ./   ####   |
.'    ######   \\\\//  /   ######  /
/    ########\\   \\/  /  ######## /
;    ##########`-----'  ########.'
|   ##########    \\/   ########/
|   ########       \\  ########;
|  ########    /\\   \\########;
\\  ######    .'  \\   \\######/
 \\  ####   .'     \\   \\####/
  \\  ##  .'        \\   \\##/
   `.__.'           `.__.'
"""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GameEngine())
    }
}
