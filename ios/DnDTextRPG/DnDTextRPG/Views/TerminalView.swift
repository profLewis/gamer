//
//  TerminalView.swift
//  DnDTextRPG
//
//  Terminal-style text interface with green text on black background
//

import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    // Terminal colors
    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let terminalBackground = Color.black

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Terminal output area
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(gameEngine.terminalLines) { line in
                                TerminalLineView(line: line)
                                    .id(line.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: gameEngine.terminalLines.count) { _ in
                        if let lastLine = gameEngine.terminalLines.last {
                            withAnimation {
                                scrollProxy.scrollTo(lastLine.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(terminalBackground)

                // Direction pad + menu buttons
                if !gameEngine.directionExits.isEmpty || !gameEngine.currentMenuOptions.isEmpty {
                    VStack(spacing: 6) {
                        // Direction D-pad (when exploring)
                        if !gameEngine.directionExits.isEmpty {
                            DirectionPadView(exits: gameEngine.directionExits) { direction in
                                gameEngine.handleDirectionChoice(direction)
                            }
                        }

                        // Action buttons
                        if !gameEngine.currentMenuOptions.isEmpty {
                            MenuButtonsView(options: gameEngine.currentMenuOptions) { choice in
                                gameEngine.handleMenuChoice(choice)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.95))
                }

                // Input area
                if gameEngine.awaitingTextInput {
                    HStack {
                        Text(">")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(terminalGreen)

                        TextField("", text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(terminalGreen)
                            .textFieldStyle(PlainTextFieldStyle())
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                            .focused($isInputFocused)
                            .onSubmit {
                                submitInput()
                            }

                        Button(action: submitInput) {
                            Image(systemName: "return")
                                .foregroundColor(terminalGreen)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(terminalBackground)
                    .onAppear {
                        isInputFocused = true
                    }
                }

                // Continue button (when waiting for acknowledgment)
                if gameEngine.awaitingContinue {
                    Button(action: {
                        gameEngine.handleContinue()
                    }) {
                        Text("[ Press to Continue ]")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(terminalGreen)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .background(terminalBackground)
                }
            }
            .background(terminalBackground)
        }
        .onAppear {
            gameEngine.startGame()
        }
    }

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        gameEngine.handleTextInput(text)
    }
}

struct TerminalLineView: View {
    let line: TerminalLine

    var body: some View {
        Text(attributedString)
            .font(.system(size: line.fontSize, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedString: AttributedString {
        var result = AttributedString(line.text)
        result.foregroundColor = line.color.swiftUIColor
        if line.isBold {
            result.font = .system(size: line.fontSize, design: .monospaced).bold()
        }
        return result
    }
}

struct MenuButtonsView: View {
    let options: [MenuOption]
    let onSelect: (Int) -> Void

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let highlightGreen = Color(red: 0.0, green: 0.6, blue: 0.2)

    let disabledRed = Color(red: 0.4, green: 0.15, blue: 0.15)

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    if !option.isDisabled {
                        onSelect(index + 1)
                    }
                }) {
                    HStack {
                        Text("\(index + 1).")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(option.isDisabled ? Color.red.opacity(0.3) : (option.isDefault ? terminalGreen : terminalGreen.opacity(0.6)))

                        Text(option.text)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(option.isDefault ? .semibold : .regular)
                            .foregroundColor(option.isDisabled ? Color.red.opacity(0.3) : terminalGreen)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(option.isDisabled ? Color.red.opacity(0.15) : (option.isDefault ? terminalGreen : terminalGreen.opacity(0.4)),
                                    lineWidth: option.isDefault ? 2 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(option.isDisabled ? disabledRed.opacity(0.2) : (option.isDefault ? highlightGreen.opacity(0.3) : terminalDarkGreen.opacity(0.15)))
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var gridColumns: [GridItem] {
        if options.count <= 2 {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
}

// MARK: - Direction Pad

struct DirectionPadView: View {
    let exits: [Direction: Bool]
    let onSelect: (Direction) -> Void

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let disabledRed = Color(red: 0.4, green: 0.15, blue: 0.15)

    var body: some View {
        VStack(spacing: 4) {
            // North
            dirButton(.north)
            // West + East
            HStack(spacing: 4) {
                dirButton(.west)
                dirButton(.east)
            }
            // South
            dirButton(.south)
        }
    }

    @ViewBuilder
    private func dirButton(_ dir: Direction) -> some View {
        let enabled = exits[dir] ?? false
        Button(action: {
            if enabled { onSelect(dir) }
        }) {
            Text(dir.rawValue)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(enabled ? terminalGreen : Color.red.opacity(0.3))
                .frame(width: 80, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(enabled ? terminalGreen.opacity(0.6) : Color.red.opacity(0.15), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(enabled ? terminalDarkGreen.opacity(0.2) : disabledRed.opacity(0.15))
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView()
            .environmentObject(GameEngine())
    }
}
