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
    @ObservedObject private var voiceInput = VoiceInputManager.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    #if os(iOS)
    @State private var showCustomKeyboard: Bool = false
    @State private var keyboardCollapsedAt: Date = .distantPast
    #endif

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
                                ForEach(Array(gameEngine.terminalLines.enumerated()), id: \.element.id) { index, line in
                                    if gameEngine.textTapEnabled {
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                gameEngine.textLongPressHandler?(index)
                                            }
                                    } else if gameEngine.swipeLeftHandler != nil {
                                        // Card mode — tap anywhere on card advances to next
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                gameEngine.swipeLeftHandler?()
                                            }
                                    } else {
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                    }
                                }
                                // Animated GIF (e.g. main menu dragon)
                                if gameEngine.showDragonGif {
                                    HStack {
                                        Spacer()
                                        AnimatedGIFView(gifName: "dragon_animation")
                                            .frame(width: 280 * scale, height: 186 * scale)
                                            .offset(x: -6 * scale) // Centre the dragon's head, not the image
                                        Spacer()
                                    }
                                }
                                // Inline image (e.g. main menu portrait)
                                if let imageName = gameEngine.menuImageName {
                                    HStack {
                                        Spacer()
                                        Image(imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 220, maxHeight: 220)
                                            .cornerRadius(8)
                                            .opacity(0.85)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .scrollDisabled(gameEngine.suppressAutoScroll)
                        .onChange(of: gameEngine.terminalLines.count) { _ in
                            guard !gameEngine.suppressAutoScroll else { return }
                            scrollToBottom(scrollProxy)
                            // Delayed re-scrolls for long pages where LazyVStack layout lags
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                guard !gameEngine.suppressAutoScroll else { return }
                                scrollToBottom(scrollProxy)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                guard !gameEngine.suppressAutoScroll else { return }
                                scrollToBottom(scrollProxy)
                            }
                        }
                        .onChange(of: isInputFocused) { focused in
                            if focused {
                                #if os(iOS)
                                // Intercept focus: show custom keyboard instead of system keyboard
                                if gameEngine.useCustomKeyboard && Date().timeIntervalSince(keyboardCollapsedAt) > 0.5 {
                                    isInputFocused = false
                                    showCustomKeyboard = true
                                }
                                #endif
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
                    .gesture(
                        DragGesture(minimumDistance: 30, coordinateSpace: .local)
                            .onEnded { value in
                                let horizontal = value.translation.width
                                let vertical = value.translation.height
                                guard abs(horizontal) > abs(vertical) * 0.7 else { return }
                                if horizontal < 0 {
                                    if let handler = gameEngine.swipeLeftHandler {
                                        handler()
                                    } else if let close = gameEngine.closeHandler {
                                        close()
                                    } else if gameEngine.gameState == .victory || gameEngine.gameState == .gameOver {
                                        gameEngine.emergencyExit()
                                    }
                                } else {
                                    gameEngine.swipeRightHandler?()
                                }
                            }
                    )
                    .onLongPressGesture(minimumDuration: 999, pressing: { pressing in
                        gameEngine.isHoldingScreen = pressing
                    }, perform: {})

                    // Direction pad + menu buttons
                    if !gameEngine.directionExits.isEmpty || !gameEngine.currentMenuOptions.isEmpty {
                        VStack(spacing: 12) {
                            // Direction D-pad (when exploring)
                            if !gameEngine.directionExits.isEmpty {
                                DirectionPadView(exits: gameEngine.directionExits, secured: gameEngine.securedExits, scale: scale,
                                    onSelect: { direction in
                                        gameEngine.handleDirectionChoice(direction)
                                    },
                                    onLongPress: gameEngine.directionLongPressHandler,
                                    centerLabel: gameEngine.dpadCenterLabel,
                                    onCenterTap: gameEngine.dpadCenterHandler,
                                    onCenterLongPress: gameEngine.dpadCenterLongPressHandler,
                                    longPressDuration: gameEngine.longPressDuration,
                                    torchOff: !gameEngine.torchLit,
                                    npcLabel: gameEngine.dpadNPCLabel,
                                    onNPCTap: gameEngine.dpadNPCHandler
                                )
                            }

                            // Action buttons
                            if !gameEngine.currentMenuOptions.isEmpty {
                                MenuButtonsView(options: gameEngine.currentMenuOptions, scale: scale,
                                    shortcutPositions: currentShortcutPositions,
                                    onSelect: { choice in
                                        // During explicit text input (chat, name entry), first button submits
                                        if gameEngine.awaitingTextInput && choice == 1 && !inputText.isEmpty {
                                            submitInput()
                                        } else {
                                            gameEngine.handleMenuChoice(choice)
                                        }
                                    },
                                    onLongPress: { choice in
                                        gameEngine.handleMenuLongPress(choice)
                                    },
                                    pressedIndex: gameEngine.pressedMenuIndex,
                                    longPressDuration: gameEngine.longPressDuration
                                )
                            }

                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.95))
                        .gesture(
                            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                                .onEnded { value in
                                    let horizontal = value.translation.width
                                    let vertical = value.translation.height
                                    guard abs(horizontal) > abs(vertical) * 0.7 else { return }
                                    if horizontal < 0 {
                                        if let handler = gameEngine.swipeLeftHandler {
                                            handler()
                                        } else if let close = gameEngine.closeHandler {
                                            close()
                                        }
                                    } else {
                                        gameEngine.swipeRightHandler?()
                                    }
                                }
                        )
                    }

                    // Standard input bar — always visible
                    // LHS: > prompt (+ text field when input active)
                    // RHS: card nav, speaker, mic, close
                    HStack(spacing: 8) {
                        // > prompt
                        Text(">")
                            .font(.system(size: 14 * scale, design: .monospaced))
                            .foregroundColor(gameEngine.chatInputMode ? Color.orange : terminalGreen)

                        // Text field — always available for typing commands
                        TextField("", text: $inputText)
                            .font(.system(size: 14 * scale, design: .monospaced))
                            .foregroundColor(gameEngine.chatInputMode ? Color.orange : terminalGreen)
                            .textFieldStyle(PlainTextFieldStyle())
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                            .focused($isInputFocused)
                            #if os(iOS)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button(action: {
                                        isInputFocused = false
                                    }) {
                                        Image(systemName: "keyboard.chevron.compact.down")
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            #endif
                            .onSubmit {
                                submitInput()
                            }

                        Spacer()

                        // Card navigation — arrows or swipe mode
                        if let posLabel = gameEngine.cardPositionLabel {
                            if gameEngine.useArrowNavigation {
                                HStack(spacing: 2) {
                                    Button(action: { gameEngine.swipeRightHandler?() }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 14 * scale * gameEngine.iconScale))
                                            .foregroundColor(gameEngine.swipeRightHandler != nil
                                                ? Color(red: 0.0, green: 0.6, blue: 0.25)
                                                : Color(red: 0.2, green: 0.2, blue: 0.2))
                                    }
                                    .disabled(gameEngine.swipeRightHandler == nil)
                                    Text(posLabel)
                                        .font(.system(size: 11 * scale, design: .monospaced))
                                        .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.2))
                                    Button(action: { gameEngine.swipeLeftHandler?() }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14 * scale * gameEngine.iconScale))
                                            .foregroundColor(gameEngine.swipeLeftHandler != nil
                                                ? Color(red: 0.0, green: 0.6, blue: 0.25)
                                                : Color(red: 0.2, green: 0.2, blue: 0.2))
                                    }
                                    .disabled(gameEngine.swipeLeftHandler == nil)
                                    if gameEngine.swipeRandomHandler != nil {
                                        Button(action: { gameEngine.swipeRandomHandler?() }) {
                                            Image(systemName: "dice")
                                                .font(.system(size: 14 * scale * gameEngine.iconScale))
                                                .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                                        }
                                    }
                                }
                            } else {
                                // Swipe mode — just show position + dice
                                HStack(spacing: 4) {
                                    Text(posLabel)
                                        .font(.system(size: 11 * scale, design: .monospaced))
                                        .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.2))
                                    if gameEngine.swipeRandomHandler != nil {
                                        Button(action: { gameEngine.swipeRandomHandler?() }) {
                                            Image(systemName: "dice")
                                                .font(.system(size: 14 * scale * gameEngine.iconScale))
                                                .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                                        }
                                    }
                                }
                            }
                        }

                        // Reroll dice (non-chat)
                        if !gameEngine.chatInputMode {
                            if gameEngine.rerollHandler != nil {
                                Button(action: { gameEngine.rerollHandler?() }) {
                                    Image(systemName: "dice")
                                        .font(.system(size: 20 * scale * gameEngine.iconScale))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        // Undo/redo icons (edit screens)
                        if gameEngine.undoHandler != nil {
                            Button(action: { gameEngine.undoHandler?() }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 18 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.35))
                            }
                        }
                        if gameEngine.redoHandler != nil {
                            Button(action: { gameEngine.redoHandler?() }) {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.system(size: 18 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.35))
                            }
                        }

                        #if os(iOS)
                        // Read aloud icon — tap to toggle, long-press to pause this page
                        if gameEngine.voiceMenuEnabled {
                            Button(action: {
                                gameEngine.readScreenAloud()
                            }) {
                                Image(systemName: gameEngine.speakerModeOn
                                    ? (gameEngine.speakerPaused ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    : "speaker.wave.2")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(gameEngine.speakerModeOn ? Color(red: 0.0, green: 0.8, blue: 0.4) : Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                    gameEngine.pauseSpeaker()
                                }
                            )
                        }

                        // Microphone icon
                        if gameEngine.voiceMenuEnabled {
                            Button(action: {
                                if voiceInput.isListening {
                                    voiceInput.stopListening()
                                } else {
                                    let isTextInput = gameEngine.awaitingTextInput
                                    let onComplete: (String) -> Void = isTextInput ? { text in
                                        inputText = ""
                                        gameEngine.handleTextInput(text)
                                    } : { text in
                                        inputText = ""
                                        gameEngine.handleVoiceMenuChoice(text)
                                    }
                                    let onTranscript: (String) -> Void = { text in
                                        inputText = text
                                    }
                                    if voiceInput.isAuthorised {
                                        voiceInput.startListening(onTranscript: onTranscript, onComplete: onComplete)
                                    } else {
                                        voiceInput.requestAuthorisation { granted in
                                            if granted {
                                                voiceInput.startListening(onTranscript: onTranscript, onComplete: onComplete)
                                            }
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: voiceInput.isListening ? "mic.fill" : "mic")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(voiceInput.isListening ? .red : Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        }
                        #endif

                        // Close button — closeHandler, chat exit, continue, or forced on combat/victory/gameOver
                        if gameEngine.chatInputMode {
                            Button(action: { gameEngine.handleChatExit() }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        } else if gameEngine.closeHandler != nil {
                            Button(action: {
                                gameEngine.closeHandler?()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        } else if gameEngine.awaitingContinue {
                            Button(action: {
                                gameEngine.handleContinue()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        } else if gameEngine.gameState == .victory || gameEngine.gameState == .gameOver || gameEngine.gameState == .combat {
                            // Fallback: always show X on combat/victory/defeat screens
                            Button(action: {
                                gameEngine.emergencyExit()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.95))
                    .onTapGesture {
                        #if os(iOS)
                        if gameEngine.useCustomKeyboard && Date().timeIntervalSince(keyboardCollapsedAt) > 0.5 {
                            isInputFocused = false
                            showCustomKeyboard = true
                        }
                        #endif
                    }

                    // Custom in-app keyboard
                    #if os(iOS)
                    if showCustomKeyboard {
                        GameKeyboardView(
                            text: $inputText,
                            onSubmit: { submitInput() },
                            onCollapse: { showCustomKeyboard = false; keyboardCollapsedAt = Date() },
                            scale: scale
                        )
                        .transition(.move(edge: .bottom))
                    }
                    #endif
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
        if text.isEmpty {
            // Empty return — press the default button, or move in a random direction
            if let defaultIdx = gameEngine.currentMenuOptions.firstIndex(where: { $0.isDefault }) {
                gameEngine.handleMenuChoice(defaultIdx + 1)
            } else if !gameEngine.directionExits.isEmpty {
                // Pick a random enabled direction
                let enabled = gameEngine.directionExits.filter { $0.value }.map { $0.key }
                if let dir = enabled.randomElement() {
                    gameEngine.print("> heading \(dir.rawValue)...", color: .dimGreen)
                    gameEngine.handleDirectionChoice(dir)
                }
            } else if gameEngine.awaitingContinue {
                gameEngine.handleContinue()
            } else if gameEngine.gameState == .victory || gameEngine.gameState == .gameOver {
                // Fallback: return key always exits victory/defeat
                gameEngine.emergencyExit()
            }
            return
        }
        inputText = ""
        if gameEngine.awaitingTextInput {
            // Explicit text input mode (chat, name entry, etc.)
            gameEngine.handleTextInput(text)
            // In chat mode, keep the keyboard open after submitting
            if gameEngine.chatInputMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    #if os(iOS)
                    if gameEngine.useCustomKeyboard && Date().timeIntervalSince(keyboardCollapsedAt) > 0.5 {
                        showCustomKeyboard = true
                    } else if !gameEngine.useCustomKeyboard {
                        isInputFocused = true
                    }
                    #else
                    isInputFocused = true
                    #endif
                }
            }
        } else if gameEngine.gameState == .combat && !gameEngine.currentMenuOptions.isEmpty {
            // Combat — text input goes to chat
            isInputFocused = false
            gameEngine.showPartyChat(initialMessage: text)
        } else if !gameEngine.currentMenuOptions.isEmpty {
            // Menu screen — match text to buttons with press animation
            isInputFocused = false
            gameEngine.handleVoiceMenuChoice(text)
        } else if gameEngine.awaitingContinue {
            // Continue screen — any text acts as continue
            isInputFocused = false
            gameEngine.handleContinue()
        }
    }
}

struct TerminalLineView: View {
    let line: TerminalLine
    let scale: CGFloat

    private var scaledSize: CGFloat { line.fontSize * scale }

    var body: some View {
        if line.isCentered {
            HStack {
                Spacer()
                Text(attributedString)
                    .font(.system(size: scaledSize, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else {
            Text(attributedString)
                .font(.system(size: scaledSize, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
        }
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
    /// 1-based index of a button to show as "pressed" (e.g. from voice input)
    var pressedIndex: Int? = nil
    /// Long-press duration in seconds (configurable in Gameplay settings)
    var longPressDuration: Double = 0.5

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let highlightGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let terminalCyan = Color(red: 0.3, green: 0.9, blue: 0.9)
    let terminalDarkCyan = Color(red: 0.1, green: 0.4, blue: 0.4)
    let highlightCyan = Color(red: 0.2, green: 0.6, blue: 0.6)
    let terminalAmber = Color(red: 0.95, green: 0.7, blue: 0.2)
    let terminalDarkAmber = Color(red: 0.4, green: 0.3, blue: 0.1)
    let highlightAmber = Color(red: 0.6, green: 0.45, blue: 0.15)
    let terminalDimGreen = Color(red: 0.0, green: 0.6, blue: 0.25)
    let terminalDarkDimGreen = Color(red: 0.0, green: 0.25, blue: 0.1)
    let highlightDimGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let terminalRed = Color(red: 0.9, green: 0.3, blue: 0.3)
    let terminalDarkRed = Color(red: 0.35, green: 0.12, blue: 0.12)
    let highlightRedTint = Color(red: 0.55, green: 0.2, blue: 0.2)

    let disabledGreen = Color(red: 0.1, green: 0.25, blue: 0.1)
    let alertAmber = Color(red: 0.95, green: 0.7, blue: 0.1)
    let alertDarkAmber = Color(red: 0.5, green: 0.35, blue: 0.05)

    private var isCompact: Bool { options.count > 6 }
    private var buttonMinHeight: CGFloat { isCompact ? max(36, 32 * scale) : max(44, 38 * scale) }
    private var buttonVerticalPadding: CGFloat { isCompact ? 4 : 8 }

    @State private var alertPulse = false

    /// Whether to insert a spacer before the last button to push it to the right column.
    /// Only danger buttons get pushed right; navigation (Help, Save) stay bottom-left.
    private var needsTrailingSpacer: Bool {
        guard options.count > 1, options.count % 2 == 1 else { return false }
        let last = options.last!
        return last.tint == .danger
    }

    var body: some View {
        let spacerIndex = needsTrailingSpacer ? options.count - 1 : -1

        LazyVGrid(columns: gridColumns, spacing: isCompact ? 4 : 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                if index == spacerIndex {
                    // Empty cell to push last button to right column
                    Color.clear
                        .frame(minHeight: buttonMinHeight)
                }
                Button(action: {
                    if !option.isDisabled {
                        onSelect(index + 1)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("\(index + 1).")
                            .font(.system(size: 11 * scale, design: .monospaced))
                            .foregroundColor(buttonNumberColor(option))

                        styledOptionText(option, index: index)
                            .font(.system(size: 13 * scale, design: .monospaced))
                            .fontWeight(option.isDefault || option.isAlert ? .semibold : .regular)
                            .foregroundColor(buttonTextColor(option))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, buttonVerticalPadding)
                    .frame(minHeight: buttonMinHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(buttonStrokeColor(option), lineWidth: option.isDefault || option.isAlert ? 2 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(buttonFillColor(option))
                            )
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(pressedIndex == index + 1 ? 0.92 : 1.0)
                .brightness(pressedIndex == index + 1 ? 0.3 : 0.0)
                .animation(.easeInOut(duration: 0.15), value: pressedIndex)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: longPressDuration)
                        .onEnded { _ in
                            if let longPress = onLongPress {
                                longPress(index + 1)
                            }
                        }
                )
            }
        }
        .onAppear {
            if options.contains(where: { $0.isAlert }) {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    alertPulse = true
                }
            }
        }
    }

    private func baseColor(_ option: MenuOption) -> Color {
        switch option.tint {
        case .cyan: return terminalCyan
        case .amber: return terminalAmber
        case .navigation: return terminalDimGreen
        case .danger: return terminalRed
        case .normal: return terminalGreen
        }
    }
    private func baseDarkColor(_ option: MenuOption) -> Color {
        switch option.tint {
        case .cyan: return terminalDarkCyan
        case .amber: return terminalDarkAmber
        case .navigation: return terminalDarkDimGreen
        case .danger: return terminalDarkRed
        case .normal: return terminalDarkGreen
        }
    }
    private func baseHighlight(_ option: MenuOption) -> Color {
        switch option.tint {
        case .cyan: return highlightCyan
        case .amber: return highlightAmber
        case .navigation: return highlightDimGreen
        case .danger: return highlightRedTint
        case .normal: return highlightGreen
        }
    }

    private func buttonNumberColor(_ option: MenuOption) -> Color {
        if option.isDisabled { return Color.green.opacity(0.2) }
        if option.isAlert { return alertPulse ? alertAmber : alertDarkAmber }
        let base = baseColor(option)
        return option.isDefault ? base : base.opacity(0.6)
    }

    private func buttonTextColor(_ option: MenuOption) -> Color {
        if option.isDisabled { return Color.green.opacity(0.2) }
        if option.isAlert { return alertPulse ? Color.white : alertAmber }
        return baseColor(option)
    }

    private func buttonStrokeColor(_ option: MenuOption) -> Color {
        if option.isDisabled { return Color.green.opacity(0.1) }
        if option.isAlert { return alertPulse ? alertAmber : alertDarkAmber }
        let base = baseColor(option)
        return option.isDefault ? base : base.opacity(0.4)
    }

    private func buttonFillColor(_ option: MenuOption) -> Color {
        if option.isDisabled { return disabledGreen.opacity(0.2) }
        if option.isAlert { return alertPulse ? alertAmber.opacity(0.3) : alertDarkAmber.opacity(0.15) }
        return option.isDefault ? baseHighlight(option).opacity(0.3) : baseDarkColor(option).opacity(0.15)
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
        if options.count <= 1 {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
}

// MARK: - Direction Pad

struct DirectionPadView: View {
    let exits: [Direction: Bool]
    var secured: Set<Direction> = []
    let scale: CGFloat
    let onSelect: (Direction) -> Void
    var onLongPress: ((Direction) -> Void)? = nil
    var centerLabel: String? = nil
    var onCenterTap: (() -> Void)? = nil
    var onCenterLongPress: (() -> Void)? = nil
    var longPressDuration: Double = 0.5
    var torchOff: Bool = false
    var npcLabel: String? = nil
    var onNPCTap: (() -> Void)? = nil

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let disabledGreen = Color(red: 0.1, green: 0.25, blue: 0.1)
    let centerBlue = Color(red: 0.2, green: 0.5, blue: 0.8)
    let uncertainGrey = Color(red: 0.35, green: 0.35, blue: 0.35)
    let securedAmber = Color(red: 0.8, green: 0.6, blue: 0.1)

    private let npcCyan = Color(red: 0.2, green: 0.7, blue: 0.9)

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
                            .frame(width: max(80, 80 * scale), height: max(44, 34 * scale))
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
                        LongPressGesture(minimumDuration: longPressDuration)
                            .onEnded { _ in
                                onCenterLongPress?()
                            }
                    )
                }
                dirButton(.east)
            }
            // South + NPC button (SE corner)
            HStack(spacing: 4) {
                // Spacer to align South under Center (West-width gap on left)
                Color.clear.frame(width: max(80, 80 * scale), height: 1)
                dirButton(.south)
                if let _ = npcLabel, let action = onNPCTap {
                    Button(action: action) {
                        Image(systemName: "scroll")
                            .font(.system(size: 16 * scale))
                            .foregroundColor(npcCyan)
                            .frame(width: max(80, 80 * scale), height: max(44, 34 * scale))
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(npcCyan.opacity(0.6), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(npcCyan.opacity(0.15))
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: max(80, 80 * scale), height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func dirButton(_ dir: Direction) -> some View {
        let hasExit = (exits[dir] ?? false) || secured.contains(dir)
        let enabled = exits[dir] ?? false
        let isSecured = secured.contains(dir)
        // When torch is off, all directions shown as uncertain grey — tappable but unknown
        let isDark = torchOff

        let textColor: Color = isDark ? uncertainGrey
            : isSecured ? securedAmber.opacity(0.5)
            : enabled ? terminalGreen
            : Color.red.opacity(0.3)

        let strokeColor: Color = isDark ? uncertainGrey.opacity(0.4)
            : isSecured ? securedAmber.opacity(0.4)
            : enabled ? terminalGreen.opacity(0.6)
            : Color.red.opacity(0.15)

        let fillColor: Color = isDark ? uncertainGrey.opacity(0.1)
            : isSecured ? securedAmber.opacity(0.1)
            : enabled ? terminalDarkGreen.opacity(0.2)
            : disabledGreen.opacity(0.15)

        Button(action: {
            if isDark || enabled { onSelect(dir) }
        }) {
            ZStack {
                Text(isDark ? "\(dir.rawValue)?" : dir.rawValue)
                    .font(.system(size: 11 * scale, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                    .frame(width: max(80, 80 * scale), height: max(44, 34 * scale))
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(strokeColor, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(fillColor)
                            )
                    )
                if isSecured && !isDark {
                    Text("🔒")
                        .font(.system(size: 10 * scale))
                        .offset(x: 25 * scale, y: -10 * scale)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: longPressDuration)
                .onEnded { _ in
                    if isDark || hasExit { onLongPress?(dir) }
                }
        )
    }
}

// MARK: - Preview

// MARK: - Animated GIF View

#if os(iOS)
struct AnimatedGIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        guard let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return container
        }

        let frameCount = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
            }
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any],
               let delay = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double {
                totalDuration += delay
            } else {
                totalDuration += 0.1
            }
        }

        let imageView = UIImageView()
        imageView.animationImages = images
        imageView.animationDuration = totalDuration
        imageView.animationRepeatCount = 0 // loop forever
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.startAnimating()

        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#else
struct AnimatedGIFView: NSViewRepresentable {
    let gifName: String

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        guard let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return container
        }
        let imageView = NSImageView()
        imageView.animates = true
        imageView.image = NSImage(data: data)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView()
            .environmentObject(GameEngine())
    }
}
