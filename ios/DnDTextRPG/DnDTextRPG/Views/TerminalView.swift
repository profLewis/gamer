//
//  TerminalView.swift
//  DnDTextRPG
//
//  Terminal-style text interface with green text on black background
//

import SwiftUI

// MARK: - Keyboard Shortcut Helpers (macOS only)

#if os(macOS)
/// Computes unique single-letter keyboard shortcuts for menu options.
/// Excludes direction keys when the d-pad is active.
func computeMenuShortcuts(for options: [MenuOption], excluding: Set<Swift.Character> = []) -> [(optionIndex: Int, character: Swift.Character, positionInText: Int)] {
    var usedChars = excluding
    var result: [(optionIndex: Int, character: Swift.Character, positionInText: Int)] = []
    for (index, option) in options.enumerated() {
        if option.isDisabled { continue }
        for (charIdx, char) in option.text.enumerated() {
            let lower = Swift.Character(char.lowercased())
            if lower.isLetter && !usedChars.contains(lower) {
                usedChars.insert(lower)
                result.append((optionIndex: index, character: lower, positionInText: charIdx))
                break
            }
        }
    }
    return result
}
#endif

struct TerminalView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    #if os(macOS)
    @FocusState private var isMainViewFocused: Bool
    #endif

    // Terminal colors
    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let terminalBackground = Color.black

    private var scale: CGFloat { gameEngine.fontScale }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Terminal output area
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(gameEngine.terminalLines) { line in
                                    TerminalLineView(line: line, scale: scale)
                                        .id(line.id)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .onChange(of: gameEngine.terminalLines.count) { _ in
                            scrollToBottom(scrollProxy)
                        }
                        .onChange(of: isInputFocused) { focused in
                            if focused {
                                // Re-scroll after keyboard appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    scrollToBottom(scrollProxy)
                                }
                            }
                        }
                        .onChange(of: gameEngine.awaitingTextInput) { awaiting in
                            if awaiting {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    scrollToBottom(scrollProxy)
                                }
                            }
                        }
                        .onChange(of: gameEngine.currentMenuOptions.count) { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollToBottom(scrollProxy)
                            }
                        }
                    }
                    .background(terminalBackground)
                    .onLongPressGesture(minimumDuration: 999, pressing: { pressing in
                        gameEngine.isHoldingScreen = pressing
                    }, perform: {})

                    // Direction pad + menu buttons
                    if !gameEngine.directionExits.isEmpty || !gameEngine.currentMenuOptions.isEmpty {
                        VStack(spacing: 6) {
                            // Direction D-pad (when exploring)
                            if !gameEngine.directionExits.isEmpty {
                                DirectionPadView(exits: gameEngine.directionExits, scale: scale,
                                    onSelect: { direction in
                                        gameEngine.handleDirectionChoice(direction)
                                    },
                                    centerLabel: gameEngine.dpadCenterLabel,
                                    onCenterTap: gameEngine.dpadCenterHandler,
                                    onCenterLongPress: gameEngine.dpadCenterLongPressHandler
                                )
                            }

                            // Action buttons
                            if !gameEngine.currentMenuOptions.isEmpty {
                                MenuButtonsView(options: gameEngine.currentMenuOptions, scale: scale,
                                    shortcutPositions: currentShortcutPositions,
                                    onSelect: { choice in
                                        gameEngine.handleMenuChoice(choice)
                                    },
                                    onLongPress: { choice in
                                        gameEngine.handleMenuLongPress(choice)
                                    }
                                )
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
                                .font(.system(size: 14 * scale, design: .monospaced))
                                .foregroundColor(terminalGreen)

                            TextField("", text: $inputText)
                                .font(.system(size: 14 * scale, design: .monospaced))
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
                                    .font(.system(size: 14 * scale))
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
                                .font(.system(size: 14 * scale, design: .monospaced))
                                .foregroundColor(terminalGreen)
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                        .background(terminalBackground)
                    }
                }
                .background(terminalBackground)

                // Tap-anywhere overlay for continue
                if gameEngine.awaitingContinue {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            gameEngine.handleContinue()
                        }
                }
            }
        }
        .onAppear {
            gameEngine.startGame()
            #if os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isMainViewFocused = true
            }
            #endif
        }
        #if os(macOS)
        .focusable()
        .focused($isMainViewFocused)
        .onKeyPress(phases: .down) { press in
            return handleMacKeyPress(press)
        }
        .onChange(of: gameEngine.awaitingTextInput) { awaiting in
            if !awaiting {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isMainViewFocused = true
                }
            }
        }
        .onChange(of: gameEngine.awaitingContinue) { awaiting in
            if awaiting {
                isMainViewFocused = true
            }
        }
        .onChange(of: gameEngine.currentMenuOptions.count) { _ in
            if !gameEngine.awaitingTextInput {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isMainViewFocused = true
                }
            }
        }
        .onChange(of: gameEngine.directionExits.count) { _ in
            if !gameEngine.awaitingTextInput {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isMainViewFocused = true
                }
            }
        }
        #endif
    }

    // MARK: - Shortcut Positions (for button underlines)

    private var currentShortcutPositions: [Int: Int] {
        #if os(macOS)
        let hasDirections = !gameEngine.directionExits.isEmpty
        let excluded: Set<Swift.Character> = hasDirections ?
            ["n", "s", "e", "w", "h", "j", "k", "l"] : []
        let shortcuts = computeMenuShortcuts(for: gameEngine.currentMenuOptions, excluding: excluded)
        var dict: [Int: Int] = [:]
        for s in shortcuts {
            dict[s.optionIndex] = s.positionInText
        }
        return dict
        #else
        return [:]
        #endif
    }

    // MARK: - macOS Keyboard Handling

    #if os(macOS)
    private func handleMacKeyPress(_ press: KeyPress) -> KeyPress.Result {
        // Don't intercept when text input is active
        if gameEngine.awaitingTextInput {
            return .ignored
        }

        // Continue: any key triggers continue
        if gameEngine.awaitingContinue {
            gameEngine.handleContinue()
            return .handled
        }

        let hasDirections = !gameEngine.directionExits.isEmpty
        let hasMenu = !gameEngine.currentMenuOptions.isEmpty

        // Arrow keys for directions
        if hasDirections {
            switch press.key {
            case .upArrow:
                if gameEngine.directionExits[.north] == true {
                    gameEngine.handleDirectionChoice(.north)
                    return .handled
                }
            case .downArrow:
                if gameEngine.directionExits[.south] == true {
                    gameEngine.handleDirectionChoice(.south)
                    return .handled
                }
            case .leftArrow:
                if gameEngine.directionExits[.west] == true {
                    gameEngine.handleDirectionChoice(.west)
                    return .handled
                }
            case .rightArrow:
                if gameEngine.directionExits[.east] == true {
                    gameEngine.handleDirectionChoice(.east)
                    return .handled
                }
            default:
                break
            }
        }

        let chars = press.characters.lowercased()

        // NSEW / HJKL for directions (vim: h=west, j=south, k=north, l=east)
        if hasDirections {
            let dirMap: [String: Direction] = [
                "n": .north, "k": .north,
                "s": .south, "j": .south,
                "w": .west,  "h": .west,
                "e": .east,  "l": .east
            ]
            if let dir = dirMap[chars], gameEngine.directionExits[dir] == true {
                gameEngine.handleDirectionChoice(dir)
                return .handled
            }
        }

        // Number keys for menu options
        if hasMenu {
            if let num = Int(chars), num >= 1, num <= gameEngine.currentMenuOptions.count {
                if !gameEngine.currentMenuOptions[num - 1].isDisabled {
                    gameEngine.handleMenuChoice(num)
                    return .handled
                }
            }
        }

        // Letter shortcuts for menu options
        if hasMenu {
            let excluded: Set<Swift.Character> = hasDirections ?
                ["n", "s", "e", "w", "h", "j", "k", "l"] : []
            let shortcuts = computeMenuShortcuts(for: gameEngine.currentMenuOptions, excluding: excluded)
            if let match = shortcuts.first(where: { String($0.character) == chars }) {
                if !gameEngine.currentMenuOptions[match.optionIndex].isDisabled {
                    gameEngine.handleMenuChoice(match.optionIndex + 1)
                    return .handled
                }
            }
        }

        // Enter/Return for d-pad center button or default menu option
        if press.key == .return {
            if let handler = gameEngine.dpadCenterHandler {
                handler()
                return .handled
            }
            if hasMenu, let defaultIdx = gameEngine.currentMenuOptions.firstIndex(where: { $0.isDefault && !$0.isDisabled }) {
                gameEngine.handleMenuChoice(defaultIdx + 1)
                return .handled
            }
        }

        return .ignored
    }
    #endif

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastLine = gameEngine.terminalLines.last {
            withAnimation {
                proxy.scrollTo(lastLine.id, anchor: .bottom)
            }
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
    let scale: CGFloat

    private var scaledSize: CGFloat { line.fontSize * scale }

    var body: some View {
        Text(attributedString)
            .font(.system(size: scaledSize, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedString: AttributedString {
        var result = AttributedString(line.text)
        result.foregroundColor = line.color.swiftUIColor
        if line.isBold {
            result.font = .system(size: scaledSize, design: .monospaced).bold()
        }
        return result
    }
}

struct MenuButtonsView: View {
    let options: [MenuOption]
    let scale: CGFloat
    var shortcutPositions: [Int: Int] = [:]  // optionIndex -> char position to underline
    let onSelect: (Int) -> Void
    var onLongPress: ((Int) -> Void)? = nil

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let highlightGreen = Color(red: 0.0, green: 0.6, blue: 0.2)

    let disabledRed = Color(red: 0.4, green: 0.15, blue: 0.15)

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    if !option.isDisabled {
                        onSelect(index + 1)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("\(index + 1).")
                            .font(.system(size: 11 * scale, design: .monospaced))
                            .foregroundColor(option.isDisabled ? Color.red.opacity(0.3) : (option.isDefault ? terminalGreen : terminalGreen.opacity(0.6)))

                        styledOptionText(option, index: index)
                            .font(.system(size: 13 * scale, design: .monospaced))
                            .fontWeight(option.isDefault ? .semibold : .regular)
                            .foregroundColor(option.isDisabled ? Color.red.opacity(0.3) : terminalGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 38 * scale)
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
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            if !option.isDisabled, let longPress = onLongPress {
                                longPress(index + 1)
                            }
                        }
                )
            }
        }
    }

    /// Returns Text view with shortcut letter underlined (macOS only)
    private func styledOptionText(_ option: MenuOption, index: Int) -> Text {
        #if os(macOS)
        if let pos = shortcutPositions[index], pos >= 0, pos < option.text.count {
            var attr = AttributedString(option.text)
            let startIdx = attr.characters.index(attr.startIndex, offsetBy: pos)
            let endIdx = attr.characters.index(after: startIdx)
            attr[startIdx..<endIdx].underlineStyle = .single
            return Text(attr)
        }
        #endif
        return Text(option.text)
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
    let scale: CGFloat
    let onSelect: (Direction) -> Void
    var centerLabel: String? = nil
    var onCenterTap: (() -> Void)? = nil
    var onCenterLongPress: (() -> Void)? = nil

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let disabledRed = Color(red: 0.4, green: 0.15, blue: 0.15)
    let centerBlue = Color(red: 0.2, green: 0.5, blue: 0.8)

    var body: some View {
        VStack(spacing: 4) {
            // North
            dirButton(.north)
            // West + Center + East
            HStack(spacing: 4) {
                dirButton(.west)
                if let label = centerLabel, let action = onCenterTap {
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 11 * scale, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(centerBlue)
                            .frame(width: 80 * scale, height: 34 * scale)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(centerBlue.opacity(0.6), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(centerBlue.opacity(0.15))
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                onCenterLongPress?()
                            }
                    )
                }
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
                .font(.system(size: 11 * scale, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(enabled ? terminalGreen : Color.red.opacity(0.3))
                .frame(width: 80 * scale, height: 34 * scale)
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
