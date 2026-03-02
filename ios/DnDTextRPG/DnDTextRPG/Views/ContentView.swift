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
        #if os(iOS)
        .statusBar(hidden: true)
        #endif
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
    @State private var isWinking = false
    @State private var isSnorting = false
    @State private var isBothEyesBlink = false
    @State private var eyeSpinFrame: Int = -1  // -1 = no spin, 0-7 = spin frames
    @State private var isToeTapping = false

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalBackground = Color.black

    var body: some View {
        ZStack {
            terminalBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Dragon ASCII art
                Text(currentDragonArt)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(terminalGreen)
                    .multilineTextAlignment(.leading)
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

                // Branding
                VStack(spacing: 4) {
                    Text("A Timbaloo app for you to enjoy")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(terminalGreen.opacity(0.5))

                    Text("Version 2.0 — 2026")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(terminalGreen.opacity(0.4))
                }
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

        // Spin dragon eyes when first appearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            startEyeSpin()
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
        // Start dragon wink after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            startDragonAnimations()
        }
    }

    // Spin characters: clockwise |, /, -, \  and counter-clockwise |, \, -, /
    private let spinCW: [String]  = ["|", "/", "-", "\\", "|", "/", "-", "\\"]
    private let spinCCW: [String] = ["|", "\\", "-", "/", "|", "\\", "-", "/"]

    private func startEyeSpin() {
        eyeSpinFrame = 0
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            eyeSpinFrame += 1
            if eyeSpinFrame >= spinCW.count {
                timer.invalidate()
                eyeSpinFrame = -1
            }
        }
    }

    private func startDragonAnimations() {
        // Wink every 4-6 seconds
        Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            isWinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isWinking = false
            }
        }
        // Snort every 8-10 seconds (offset from wink)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
                isSnorting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isSnorting = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isSnorting = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSnorting = false
                        }
                    }
                }
            }
        }
        // Toe tapping + eye spin every 3-4 seconds (with slight variation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                // Toe tap
                isToeTapping = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isToeTapping = false
                }
                // Eye spin shortly after (slight offset for variety)
                let spinDelay = Double.random(in: 0.0...0.4)
                DispatchQueue.main.asyncAfter(deadline: .now() + spinDelay) {
                    startEyeSpin()
                }
            }
        }
    }

    private var currentDragonArt: String {
        var art = dragonArtBase
        if eyeSpinFrame >= 0 && eyeSpinFrame < spinCW.count {
            let left = spinCW[eyeSpinFrame]
            let right = spinCCW[eyeSpinFrame]
            art = art.replacingOccurrences(of: "(@::@)", with: "(\(left)::\(right))")
        } else if isBothEyesBlink {
            art = art.replacingOccurrences(of: "(@::@)", with: "(-::-)")
        } else if isWinking {
            art = art.replacingOccurrences(of: "(@::@)", with: "(-::@)")
        }
        if isSnorting {
            art = art.replacingOccurrences(of: "(oo)", with: "(OO)")
        }
        if isToeTapping {
            // Lift left foot, tap right foot
            art = art.replacingOccurrences(of: "(vvv(VVV)(VVV)vvv)", with: "(vvv(VVV)(^^^)vvv)")
        }
        return art
    }

    private var dragonArtBase: String {
        """
                  ___====-_  _-====___
            _--^^^#####//      \\\\#####^^^--_
         _-^##########// (    ) \\\\##########^-_
        -############//  |\\^^/|  \\\\############-
      _/############//   (@::@)   \\\\############\\_
     /#############((     \\\\//     ))#############\\
    -###############\\\\    (oo)    //###############-
   -#################\\\\  / VV \\  //#################-
  -###################\\\\/      \\//###################-
 _#/|##########/\\######(   /\\   )######/\\##########|\\#_
 |/ |#/\\#/\\#/\\/  \\#/\\##\\  |  |  /##/\\#/  \\/\\#/\\#/\\#| \\|
 `  |/  V  V  `   V  \\#\\| |  | |/#/  V   '  V  V  \\|  '
    `   `  `      `   / | |  | | \\   '      '  '   '
                       (  | |  | |  )
                      __\\ | |  | | /__
                     (vvv(VVV)(VVV)vvv)
"""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GameEngine())
    }
}
