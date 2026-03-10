//
//  GameKeyboardView.swift
//  DnDTextRPG
//
//  Custom in-app keyboard — styled like the standard iOS keyboard
//  Adapts layout to device language (QWERTY, QWERTZ, AZERTY, etc.)
//

import SwiftUI

#if os(iOS)

struct GameKeyboardView: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var onCollapse: () -> Void
    var scale: CGFloat = 1.0

    @State private var isShifted = false
    @State private var isCapsLock = false
    @State private var showSymbols = false
    @State private var showSymbols2 = false

    // MARK: - Language-adaptive layouts

    private var letterRows: [[String]] {
        let lang = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        switch lang {
        case "fr":
            return [
                ["a","z","e","r","t","y","u","i","o","p"],
                ["q","s","d","f","g","h","j","k","l","m"],
                ["w","x","c","v","b","n"],
            ]
        case "de":
            return [
                ["q","w","e","r","t","z","u","i","o","p","ü"],
                ["a","s","d","f","g","h","j","k","l","ö","ä"],
                ["y","x","c","v","b","n","m"],
            ]
        case "es":
            return [
                ["q","w","e","r","t","y","u","i","o","p"],
                ["a","s","d","f","g","h","j","k","l","ñ"],
                ["z","x","c","v","b","n","m"],
            ]
        default:
            return [
                ["q","w","e","r","t","y","u","i","o","p"],
                ["a","s","d","f","g","h","j","k","l"],
                ["z","x","c","v","b","n","m"],
            ]
        }
    }

    private let symbolRows1: [[String]] = [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["-","/",":",";","(",")","$","&","@","\""],
        [".",",","?","!","'"],
    ]

    private let symbolRows2: [[String]] = [
        ["[","]","{","}","#","%","^","*","+","="],
        ["_","\\","|","~","<",">","€","£","¥","•"],
        [".",",","?","!","'"],
    ]

    private var activeRows: [[String]] {
        if showSymbols {
            return showSymbols2 ? symbolRows2 : symbolRows1
        } else {
            return letterRows
        }
    }

    // Colours matching iOS dark keyboard
    private let keyBg = Color(white: 0.25)
    private let keyFg = Color.white
    private let specialKeyBg = Color(white: 0.17)
    private let kbBg = Color(red: 0.07, green: 0.07, blue: 0.08)

    // Key sizing — match standard iOS proportions
    private var keyHeight: CGFloat { 42 * scale }
    private var hSpacing: CGFloat { 6 * scale }
    private var vSpacing: CGFloat { 10 * scale }

    var body: some View {
        VStack(spacing: vSpacing) {
            // Row 1: top character row
            HStack(spacing: hSpacing) {
                ForEach(activeRows[0], id: \.self) { key in
                    charKey(key)
                }
            }

            // Row 2: middle row — slightly inset like real keyboard
            HStack(spacing: hSpacing) {
                if !showSymbols && activeRows[1].count < 10 {
                    Spacer().frame(width: 8 * scale)
                }
                ForEach(activeRows[1], id: \.self) { key in
                    charKey(key)
                }
                if !showSymbols && activeRows[1].count < 10 {
                    Spacer().frame(width: 8 * scale)
                }
            }

            // Row 3: bottom character row with shift + backspace
            HStack(spacing: hSpacing) {
                if showSymbols {
                    // Toggle between symbol pages
                    specialKey(showSymbols2 ? "123" : "#+=", width: 42 * scale) {
                        showSymbols2.toggle()
                    }
                } else {
                    // Shift key
                    Button(action: {
                        if isShifted && !isCapsLock {
                            // Second tap → caps lock
                            isCapsLock = true
                        } else if isCapsLock {
                            isCapsLock = false
                            isShifted = false
                        } else {
                            isShifted = true
                        }
                    }) {
                        Image(systemName: isCapsLock ? "capslock.fill" : (isShifted ? "shift.fill" : "shift"))
                            .font(.system(size: 16 * scale))
                            .foregroundColor(keyFg)
                            .frame(width: 42 * scale, height: keyHeight)
                            .background((isShifted || isCapsLock) ? keyFg.opacity(0.3) : specialKeyBg)
                            .cornerRadius(5)
                            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(activeRows[2], id: \.self) { key in
                    charKey(key)
                }

                // Backspace
                Button(action: {
                    if !text.isEmpty { text.removeLast() }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 16 * scale))
                        .foregroundColor(keyFg)
                        .frame(width: 42 * scale, height: keyHeight)
                        .background(specialKeyBg)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in text = "" }
                )
            }

            // Row 4: bottom row
            HStack(spacing: hSpacing) {
                // 123/ABC toggle
                specialKey(showSymbols ? "ABC" : "123", width: 50 * scale) {
                    showSymbols.toggle()
                    showSymbols2 = false
                    isShifted = false
                    isCapsLock = false
                }

                // Space bar
                Button(action: { text += " " }) {
                    Text("space")
                        .font(.system(size: 16 * scale))
                        .foregroundColor(keyFg)
                        .frame(height: keyHeight)
                        .frame(maxWidth: .infinity)
                        .background(keyBg)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                }
                .buttonStyle(.plain)

                // Collapse
                Button(action: { onCollapse() }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16 * scale))
                        .foregroundColor(keyFg)
                        .frame(width: 40 * scale, height: keyHeight)
                        .background(specialKeyBg)
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                }
                .buttonStyle(.plain)

                // Return
                Button(action: { onSubmit() }) {
                    Image(systemName: "return")
                        .font(.system(size: 16 * scale, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50 * scale, height: keyHeight)
                        .background(Color(red: 0.0, green: 0.4, blue: 0.15))
                        .cornerRadius(5)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 3)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(kbBg)
    }

    // MARK: - Character Key

    @ViewBuilder
    private func charKey(_ key: String) -> some View {
        let display: String = {
            if showSymbols { return key }
            return (isShifted || isCapsLock) ? key.uppercased() : key
        }()
        Button(action: {
            let char = (isShifted || isCapsLock) && !showSymbols ? key.uppercased() : key
            text += char
            if isShifted && !isCapsLock && !showSymbols { isShifted = false }
        }) {
            Text(display)
                .font(.system(size: 22 * scale, weight: .light))
                .foregroundColor(keyFg)
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
                .background(keyBg)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Special Key

    @ViewBuilder
    private func specialKey(_ label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15 * scale))
                .foregroundColor(keyFg)
                .frame(width: width, height: keyHeight)
                .background(specialKeyBg)
                .cornerRadius(5)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#endif
