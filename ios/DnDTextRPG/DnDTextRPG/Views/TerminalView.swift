//
//  TerminalView.swift
//  DnDTextRPG
//
//  Terminal-style text interface with green text on black background
//

import SwiftUI
import UniformTypeIdentifiers

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

// MARK: - Log Importer

/// Thin wrapper around .fileImporter. SwiftUI's file importer on this SDK
/// doesn't expose a way to force the system picker to open on its "Browse"
/// tab instead of "Recents" (no initialDirectory on this fileImporter
/// overload) — that choice belongs to the system UI, not the app.
// .fileExporter/.fileImporter (and FileDocument, see GameEngine.LogFileDocument)
// aren't available on tvOS — no user-facing file system there.
#if !os(tvOS)
struct LogImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onCompletion: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.plainText],
            onCompletion: onCompletion
        )
    }
}
#endif

struct TerminalView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject private var voiceInput = VoiceInputManager.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var textModeAutoSubmitTimer: Timer? = nil
    /// Last time the user manually dragged the terminal scroll view — while
    /// recent, auto-scroll-to-bottom backs off so they can scroll up mid-combat
    /// to reread what happened without being yanked back down.
    @State private var lastManualScrollAt: Date = .distantPast
    private var recentlyScrolledManually: Bool {
        Date().timeIntervalSince(lastManualScrollAt) < 8.0
    }
    /// True whenever the bottom-of-terminal sentinel view is actually on
    /// screen. Unlike the time-based check above, this doesn't expire — a
    /// player who scrolls up mid-combat to reread an earlier round stays
    /// scrolled there for as long as they like, even if a whole slow round
    /// (several monster attacks, each with its own delayed print phases)
    /// plays out in the meantime. Auto-scroll only resumes once they
    /// actually scroll back down to the bottom themselves.
    @State private var isNearBottom: Bool = true
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

    /// Wraps the map panel + scrolling text as an HStack (map | text side by
    /// side) in landscape, or the original VStack (map above text) otherwise
    /// — a generic axis switch so neither child's own content needs to
    /// change between orientations.
    @ViewBuilder
    /// Map above text, always — landscape used to make this an HStack (map
    /// as its own column) as part of a 3-column map|icons|text split, but
    /// that fought the D-pad's own fixed-size buttons for space and left the
    /// map too narrow for its own minimum content width. Landscape now
    /// splits the screen in half instead (see body): this whole map+text
    /// stack occupies the left half exactly as portrait shows it full-width,
    /// while the D-pad/buttons/input occupy the right half.
    private func adaptiveMapTextStack<Content: View>(isLandscape: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
    }

    /// The screen's two main regions — (A) map+text, (B) D-pad/buttons/
    /// input — side by side as an even 50/50 split in landscape, or stacked
    /// full-width as portrait always has.
    private func topLevelStack<Content: View>(isLandscape: Bool, @ViewBuilder content: () -> Content) -> some View {
        Group {
            if isLandscape {
                HStack(alignment: .top, spacing: 0) { content() }
            } else {
                VStack(spacing: 0) { content() }
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack {
                topLevelStack(isLandscape: isLandscape) {
                    adaptiveMapTextStack(isLandscape: isLandscape) {
                    // Pinned map pane — kept separate from the scrolling text
                    // below (see GameEngine.pinnedMapLines/printMap) so it
                    // always stays fully visible, instead of living at the
                    // top of the scrolling text where a screen with several
                    // button rows (shrinking the text area) or an
                    // auto-scroll-to-bottom could chop its top rows off.
                    // In landscape, the map becomes its own left column
                    // instead of a full-width band above the text, offset
                    // down slightly so it starts below where the text
                    // column's first (title) line sits, not flush at the top.
                    Group {
                    if !gameEngine.pinnedMapLines.isEmpty {
                        let mapContent = VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(gameEngine.pinnedMapLines.enumerated()), id: \.element.id) { index, line in
                                // Landscape's panel is half a line taller than
                                // portrait's (see its .frame(height:) below) —
                                // this half-line spacer is what the initial
                                // scroll actually targets there (see
                                // scrollMapPastHeader), so the extra height
                                // shows as breathing room above the grid
                                // instead of just extra blank space at the
                                // bottom.
                                if isLandscape && index == 3 {
                                    Color.clear
                                        .frame(height: (gameEngine.mapFontSize * scale * 1.3 + 2) / 2)
                                        .id("landscapeMapHalfLineSpacer")
                                }
                                TerminalLineView(line: line, scale: scale)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 2)

                        // Always wrapped in a real ScrollView — "Auto" used to
                        // render mapContent bare with no scroll container at
                        // all, so if the surrounding layout ever squeezed it
                        // shorter than the map's actual content (a taller Map
                        // Length, a small landscape column, bigger text
                        // scale...), the overflow was silently CLIPPED with no
                        // way to reach it — not scrolled, just gone. A
                        // ScrollView keeps whatever scroll offset it had
                        // across content updates by default, so moving to a
                        // new room (new pinnedMapLines), or changing Map
                        // Length (which re-renders this same pinnedMapLines),
                        // could otherwise leave the panel scrolled to wherever
                        // it happened to be for the PREVIOUS content — always
                        // re-centre on the first actual grid row whenever
                        // content changes (new room, new Map Length...) —
                        // skipping past the 3-line header (border/"MAP"
                        // title/separator, always first in pinnedMapLines;
                        // see GameEngine.printMap), which starts scrolled out
                        // of view above rather than removed from the content
                        // — reachable by scrolling up, same as the key/
                        // legend that follows the grid is reachable by
                        // scrolling down. The panel's own height below is
                        // calculated to match exactly the grid + "@ here:
                        // ..." line, so anchoring the first grid row at the
                        // top means the map fills the panel precisely (with
                        // @ falling naturally in the middle, same as the
                        // grid itself is always centred on the player).
                        ScrollViewReader { mapProxy in
                            // Landscape's map column can be narrower than
                            // the map's own minimum rendered width (the grid
                            // has a hard floor of ~26 characters wide) — add
                            // horizontal scrolling too so any overflow there
                            // stays reachable rather than silently clipped
                            // off the right edge.
                            ScrollView(isLandscape ? [.vertical, .horizontal] : [.vertical]) {
                                mapContent
                            }
                            .onChange(of: gameEngine.pinnedMapLines.first?.id) { _ in
                                scrollMapPastHeader(mapProxy, isLandscape: isLandscape)
                            }
                            // onChange alone only fires on a subsequent
                            // change — the very first time this panel
                            // appears (e.g. right after starting/loading a
                            // game), pinnedMapLines is already populated
                            // with no "change" event to catch, so the
                            // ScrollView sat at its default position (the
                            // header) instead of skipping past it. A second,
                            // slightly delayed attempt covers the case where
                            // this fires before the ScrollView has actually
                            // laid out its content yet.
                            .onAppear {
                                scrollMapPastHeader(mapProxy, isLandscape: isLandscape)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    scrollMapPastHeader(mapProxy, isLandscape: isLandscape)
                                }
                            }
                        }
                        // Height clipped to just the map's own rows (not the
                        // key/legend that follows in the same content) — see
                        // GameEngine.mapOnlyLineCount. The key is still
                        // there, just scrolled past the visible area by
                        // default. Still wrapped in a real ScrollView above
                        // so it stays reachable rather than clipped if it's
                        // ever taller than the space actually available (a
                        // small landscape column, a long Map
                        // Length, larger text scale...).
                        .frame(height: (CGFloat(gameEngine.mapOnlyLineCount) - (isLandscape ? 0.0 : 0.5)) * (gameEngine.mapFontSize * scale * 1.3 + 2))
                        .background(terminalBackground)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.5) {
                            gameEngine.showExpandedMapOverlay()
                        }

                        // No on-screen resize control here — a drag handle
                        // was fiddly against the nearby scroll gestures, and
                        // even a plain tap-to-cycle button was still visual
                        // clutter sitting on every screen with a map. Sizing
                        // lives entirely in Settings > Gameplay > Map Radius
                        // > Panel Size instead, out of the way until wanted.
                        Rectangle()
                            .fill(terminalDarkGreen.opacity(0.4))
                            .frame(height: 1)
                    }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                                    } else if gameEngine.awaitingContinue {
                                        // "Press to continue" screens (victory/level-up/defeat/etc.) — the
                                        // corner X icon shows closeHandler (abandon) instead of this whenever
                                        // closeHandler is set, which leaves touch users with no visible way
                                        // to advance. Tap-anywhere is the reliable fallback.
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                gameEngine.handleContinue()
                                            }
                                    } else {
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                    }
                                }
                                // Animated GIF (e.g. main menu dragon)
                                if let gifName = gameEngine.dragonGifName {
                                    HStack {
                                        Spacer()
                                        AnimatedGIFView(gifName: gifName)
                                            .frame(width: 280 * scale, height: 186 * scale)
                                            .offset(x: -6 * scale) // Centre the dragon's head, not the image
                                        Spacer()
                                    }
                                    if let caption = gameEngine.currentPoseCaption {
                                        Text(caption)
                                            .font(.system(size: 11 * scale, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                // Inline image (e.g. main menu portrait)
                                if let imageName = gameEngine.menuImageName {
                                    HStack {
                                        Spacer()
                                        Image(imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 340 * scale, maxHeight: 220 * scale)
                                            .cornerRadius(8)
                                            .opacity(0.85)
                                        Spacer()
                                    }
                                    if let caption = gameEngine.currentPoseCaption {
                                        Text(caption)
                                            .font(.system(size: 11 * scale, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                // Invisible sentinel — its visibility tells us whether
                                // the view is actually scrolled to the bottom, so
                                // auto-scroll can follow new content ONLY then, rather
                                // than yanking a deliberately-scrolled-up reader back
                                // down (see isNearBottom).
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottomSentinel")
                                    .onAppear { isNearBottom = true }
                                    .onDisappear { isNearBottom = false }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .opacity(gameEngine.textFlashOpacity)
                            .animation(.easeInOut(duration: 0.12), value: gameEngine.textFlashOpacity)
                        }
                        .scrollDisabled(gameEngine.scrollLocked)
                        #if !os(tvOS)
                        // tvOS has no touch/drag input (remote + focus engine
                        // instead) — this only tracks manual scroll drags to
                        // pause auto-scroll-to-bottom, which doesn't apply there.
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { _ in lastManualScrollAt = Date() }
                        )
                        #endif
                        .onChange(of: gameEngine.terminalLines.count) { _ in
                            // A screen that prints many lines in quick succession (each
                            // appended line bumps this count separately, since prints are
                            // now synchronous) queues up several of these force-scrolls,
                            // including the two delayed re-scrolls below landing up to
                            // 0.5s later.
                            if gameEngine.suppressAutoScroll {
                                // Paginated card-style screens — still time-based (isNearBottom's
                                // bottom-sentinel doesn't map to "stay at the top" the same way).
                                guard !recentlyScrolledManually else { return }
                                scrollToTop(scrollProxy)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    guard gameEngine.suppressAutoScroll, !recentlyScrolledManually else { return }
                                    scrollToTop(scrollProxy)
                                }
                            } else {
                                // Chat/combat-style screens — follow the tail only while the
                                // reader is actually at the bottom (isNearBottom, no timeout).
                                // A deliberate scroll-up to reread an earlier round stays put
                                // no matter how long the round takes to finish.
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
                        }
                        .onChange(of: isInputFocused) { focused in
                            if focused {
                                #if os(iOS)
                                // System keyboard appearing — dismiss custom keyboard to avoid showing both
                                showCustomKeyboard = false
                                #endif
                                // Re-scroll after keyboard appears
                                guard !gameEngine.suppressAutoScroll else { return }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    scrollToBottom(scrollProxy)
                                }
                            }
                        }
                        .onChange(of: gameEngine.awaitingTextInput) { awaiting in
                            if awaiting {
                                guard !gameEngine.suppressAutoScroll else { return }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    scrollToBottom(scrollProxy)
                                }
                            }
                        }
                        .onChange(of: gameEngine.currentMenuOptions.count) { _ in
                            // Combat redraws its menu (new attack options) after nearly
                            // every turn — scrollToBottom's own isNearBottom check means
                            // this only follows the tail while the reader is already
                            // there, so scrolling up mid-combat to reread a report stays
                            // put no matter how many turns pass.
                            guard !gameEngine.suppressAutoScroll else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollToBottom(scrollProxy)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(terminalBackground)
                    #if !os(tvOS)
                    // tvOS has no touch/swipe input (remote + focus engine
                    // instead) — swipe-left/right card navigation doesn't apply.
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .global)
                            .onEnded { value in
                                let horizontal = value.translation.width
                                let vertical = value.translation.height
                                // Accept if mostly horizontal (allow up to ~55° from horizontal)
                                guard abs(horizontal) > abs(vertical) * 0.5 else { return }
                                guard abs(horizontal) > 40 else { return } // Require decent travel distance
                                if horizontal < 0 {
                                    // Swipe left = next card if available, else go back
                                    if let next = gameEngine.swipeLeftHandler {
                                        next()
                                    } else if let close = gameEngine.closeHandler {
                                        close()
                                    } else if !gameEngine.awaitingContinue {
                                        // No swipe handler and no closeHandler — an
                                        // orphaned screen; fall back to the same
                                        // emergency exit the X icon uses.
                                        gameEngine.emergencyExit()
                                    }
                                } else {
                                    // Swipe right = previous card if available, else forward/continue
                                    if let prev = gameEngine.swipeRightHandler {
                                        prev()
                                    } else if gameEngine.currentMenuOptions.count == 1 {
                                        gameEngine.handleMenuChoice(1)
                                    }
                                }
                            }
                    )
                    .onLongPressGesture(minimumDuration: 999, pressing: { pressing in
                        gameEngine.isHoldingScreen = pressing
                        if pressing {
                            isInputFocused = false
                        }
                    }, perform: {})
                    #endif
                    } // end adaptiveMapTextStack — map + text, left half in landscape
                    // maxHeight: .infinity is required in landscape — without
                    // it, this HStack cell only got its ideal/intrinsic
                    // height instead of the full available height, starving
                    // the text ScrollView inside down to a sliver (reading
                    // as "the combat window doesn't scroll" — there was
                    // barely any visible height for it to scroll within).
                    .frame(maxWidth: isLandscape ? .infinity : nil, maxHeight: isLandscape ? .infinity : nil, alignment: .leading)

                    // Button row + input bar + custom keyboard — right half
                    // in landscape (see the HStack/VStack split below), full
                    // width below the map+text in portrait. Landscape puts
                    // the input bar FIRST (above the buttons) — pinned at
                    // the bottom like portrait, the system keyboard (which
                    // covers roughly the bottom half of a landscape screen)
                    // hid the typed text the moment it appeared, since
                    // there's so much less vertical space to work with than
                    // portrait has.
                    VStack(spacing: 0) {
                        if isLandscape {
                            inputBarAndKeyboardBlock
                            dpadAndMenuButtonsBlock
                        } else {
                            dpadAndMenuButtonsBlock
                            inputBarAndKeyboardBlock
                        }
                    }
                    .frame(maxWidth: isLandscape ? .infinity : nil, alignment: .top)
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
            .onAppear { gameEngine.isLandscapeOrientation = isLandscape }
            .onChange(of: isLandscape) { newValue in gameEngine.isLandscapeOrientation = newValue }
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
        .onChange(of: gameEngine.prefillInputText) { newVal in
            if let text = newVal {
                inputText = text
                gameEngine.prefillInputText = nil
            }
        }
        #if !os(tvOS)
        .fileExporter(isPresented: $gameEngine.showLogExporter,
                      document: LogFileDocument(text: gameEngine.pendingLogExportText),
                      contentType: .plainText,
                      defaultFilename: "adventure-log") { result in
            gameEngine.handleLogExportResult(result)
        }
        .modifier(LogImporterModifier(isPresented: $gameEngine.showLogImporter) { result in
            guard case .success(let url) = result else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                gameEngine.importAdventureLog(from: text)
            }
        })
        #endif
        .overlay {
            if gameEngine.mapOverlayVisible {
                fullMapOverlay
            }
        }
    }

    /// Direction D-pad + action button row — one of Region B's two blocks
    /// (see body), reordered relative to inputBarAndKeyboardBlock depending
    /// on orientation.
    @ViewBuilder
    private var dpadAndMenuButtonsBlock: some View {
                    // Direction pad + menu buttons (hidden in Just DM mode, except on
                    // victory/defeat milestone screens — see forceInteractiveControls).
                    if (!gameEngine.isJustDMActive || gameEngine.forceInteractiveControls),
                       !gameEngine.directionExits.isEmpty || !gameEngine.currentMenuOptions.isEmpty {
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
                                    onNPCTap: gameEngine.dpadNPCHandler,
                                    onTeleportTap: gameEngine.dpadTeleportHandler,
                                    torchLabel: gameEngine.dpadTorchLabel,
                                    onTorchTap: gameEngine.dpadTorchHandler,
                                    onSearchTap: gameEngine.dpadSearchHandler,
                                    onListenTap: gameEngine.dpadListenHandler
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
                                    longPressDuration: gameEngine.longPressDuration,
                                    onUndo: gameEngine.undoHandler,
                                    onRedo: gameEngine.redoHandler,
                                    undoTargetIndex: gameEngine.undoTargetButtonIndex,
                                    redoTargetIndex: gameEngine.redoTargetButtonIndex
                                )
                            }

                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.95))
                        #if !os(tvOS)
                        .gesture(
                            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                                .onEnded { value in
                                    let horizontal = value.translation.width
                                    let vertical = value.translation.height
                                    guard abs(horizontal) > abs(vertical) * 0.5 else { return }
                                    guard abs(horizontal) > 40 else { return }
                                    if horizontal < 0 {
                                        if let next = gameEngine.swipeLeftHandler {
                                            next()
                                        } else if let close = gameEngine.closeHandler {
                                            close()
                                        }
                                    } else {
                                        if let prev = gameEngine.swipeRightHandler {
                                            prev()
                                        } else if gameEngine.currentMenuOptions.count == 1 {
                                            gameEngine.handleMenuChoice(1)
                                        }
                                    }
                                }
                        )
                        #endif
                    }
    }

    /// Text input bar + custom in-app keyboard — Region B's other block
    /// (see body and dpadAndMenuButtonsBlock).
    @ViewBuilder
    private var inputBarAndKeyboardBlock: some View {
                    // Standard input bar — always visible
                    HStack(spacing: 4) {
                            // > prompt — always visible
                            Text(">")
                                .font(.system(size: 14 * scale, design: .monospaced))
                                .foregroundColor(gameEngine.chatInputMode ? Color.orange : terminalGreen)

                            // Blinking cursor block — only while genuinely waiting on the
                            // player (menu/D-pad/text/continue prompt on screen) and the
                            // field is empty, so it doesn't sit next to typed text.
                            if gameEngine.blinkingCursorEnabled && inputText.isEmpty && gameEngine.isWaitingForInput && !GameEngine.systemVoiceOverRunning {
                                TimelineView(.periodic(from: .now, by: 0.53)) { context in
                                    let visible = Int(context.date.timeIntervalSinceReferenceDate / 0.53) % 2 == 0
                                    Text("█")
                                        .font(.system(size: 14 * scale, design: .monospaced))
                                        .foregroundColor(gameEngine.chatInputMode ? Color.orange : terminalGreen)
                                        .opacity(visible ? 1 : 0)
                                }
                            }

                            // Text field
                            TextField("", text: $inputText)
                                .font(.system(size: 14 * scale, design: .monospaced))
                                .foregroundColor(gameEngine.chatInputMode ? Color.orange : terminalGreen)
                                .tint(gameEngine.chatInputMode ? Color.orange : terminalGreen)
                                .accentColor(gameEngine.chatInputMode ? Color.orange : terminalGreen)
                                .textFieldStyle(.plain)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                #endif
                                .focused($isInputFocused)
                                .onChange(of: inputText) { newText in
                                    // Text mode auto-submit: if typing stops for 1.5s, submit
                                    textModeAutoSubmitTimer?.invalidate()
                                    textModeAutoSubmitTimer = nil
                                    if gameEngine.isJustDMActive && !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        textModeAutoSubmitTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                                            DispatchQueue.main.async {
                                                submitInput()
                                            }
                                        }
                                    }
                                }
                                .onSubmit {
                                    textModeAutoSubmitTimer?.invalidate()
                                    textModeAutoSubmitTimer = nil
                                    submitInput()
                                }

                            Spacer()

                        if !gameEngine.isJustDMActive || gameEngine.forceInteractiveControls {
                        // Card navigation — <</>>/swipe mode
                        if let posLabel = gameEngine.cardPositionLabel {
                            if gameEngine.useArrowNavigation {
                                HStack(spacing: 2) {
                                    Button(action: { gameEngine.swipeRightHandler?() }) {
                                        Text("<<")
                                            .font(.system(size: 13 * scale, design: .monospaced))
                                            .foregroundColor(gameEngine.swipeRightHandler != nil
                                                ? Color(red: 0.0, green: 0.6, blue: 0.25)
                                                : Color(red: 0.2, green: 0.2, blue: 0.2))
                                    }
                                    .disabled(gameEngine.swipeRightHandler == nil)
                                    Text(posLabel)
                                        .font(.system(size: 13 * scale, design: .monospaced))
                                        .foregroundColor(Color(red: 0.0, green: 0.5, blue: 0.2))
                                    Button(action: { gameEngine.swipeLeftHandler?() }) {
                                        Text(">>")
                                            .font(.system(size: 13 * scale, design: .monospaced))
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
                                        .font(.system(size: 13 * scale, design: .monospaced))
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

                        // Reroll dice (non-chat) — hide when card-nav dice is already showing
                        if !gameEngine.chatInputMode && gameEngine.swipeRandomHandler == nil {
                            if gameEngine.rerollHandler != nil {
                                Button(action: { gameEngine.rerollHandler?() }) {
                                    Image(systemName: "dice")
                                        .font(.system(size: 20 * scale * gameEngine.iconScale))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        // Undo/redo icon buttons + feedback
                        if gameEngine.undoHandler != nil {
                            Button(action: { gameEngine.undoHandler?() }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 18 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.95, green: 0.7, blue: 0.2))
                            }
                        }
                        if let feedback = gameEngine.undoRedoFeedback {
                            Text(feedback)
                                .font(.system(size: 11 * scale, design: .monospaced))
                                .foregroundColor(Color(red: 0.95, green: 0.7, blue: 0.2).opacity(0.7))
                                .lineLimit(1)
                                .allowsHitTesting(false)
                        }
                        if gameEngine.redoHandler != nil {
                            Button(action: { gameEngine.redoHandler?() }) {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.system(size: 18 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.95, green: 0.7, blue: 0.2))
                            }
                        }

                        #if os(iOS)
                        // Dismiss system keyboard button (only when system keyboard is active)
                        if isInputFocused {
                            Button(action: { isInputFocused = false }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 18 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        }

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

                        // Microphone icon (only when no keyboard is showing)
                        if gameEngine.voiceMenuEnabled && !isInputFocused && !showCustomKeyboard {
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
                        } else {
                            // Fallback: closeHandler is nil and nothing is
                            // awaiting a tap-to-continue — an orphaned screen
                            // (e.g. one that cleared the terminal and printed
                            // content but never reached its own showMenu/
                            // closeHandler setup). Always show a way out
                            // rather than leaving stale buttons with no way
                            // back, regardless of which screen this is.
                            Button(action: {
                                gameEngine.emergencyExit()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        }
                        } // end if !isJustDMActive || forceInteractiveControls
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
                            scale: scale,
                            voiceEnabled: gameEngine.voiceMenuEnabled,
                            isListening: voiceInput.isListening,
                            onMicTap: {
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
                            }
                        )
                        .transition(.move(edge: .bottom))
                    }
                    #endif
    }

    /// Easter egg: the whole explored floor, pannable in both directions,
    /// with a Recentre button — shown by long-pressing the pinned map pane.
    private var fullMapOverlay: some View {
        ZStack(alignment: .topTrailing) {
            terminalBackground.opacity(0.98).ignoresSafeArea()
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(gameEngine.mapOverlayLines) { line in
                        TerminalLineView(line: line, scale: scale)
                    }
                }
                .padding(16)
            }
            Button(action: { gameEngine.recentreMap() }) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                    Text("Recentre")
                        .font(.system(size: 13 * scale, design: .monospaced))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.green))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .transition(.opacity)
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

        // Number keys for menu options — maps the typed digit to the Nth
        // regular (numbered) button, matching what's actually displayed on
        // screen (see MenuButtonsView's displayNumber), not the button's raw
        // position in currentMenuOptions. Those differ whenever a compact
        // item (e.g. << on page 2+) sits earlier in that array.
        if hasMenu {
            if let num = Int(chars), num >= 1 {
                let regularOptions = gameEngine.currentMenuOptions.enumerated().filter { !$0.element.isCompactNav }
                if num <= regularOptions.count {
                    let (absoluteIdx, option) = regularOptions[num - 1]
                    if !option.isDisabled {
                        gameEngine.handleMenuChoice(absoluteIdx + 1)
                        return .handled
                    }
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

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        if let firstLine = gameEngine.terminalLines.first {
            withAnimation {
                proxy.scrollTo(firstLine.id, anchor: .top)
            }
        }
    }

    /// Scrolls the pinned map panel to its first real grid row, skipping
    /// past the 3-line header (border/"MAP" title/separator — always first
    /// in pinnedMapLines; see GameEngine.printMap) without animation, so it
    /// never visibly scrolls INTO place on screen — it should just already
    /// be there, the same way scrollTo(anchor:.top) on first appearance
    /// never animates either.
    private func scrollMapPastHeader(_ proxy: ScrollViewProxy, isLandscape: Bool) {
        let lines = gameEngine.pinnedMapLines
        // Landscape targets the half-line spacer injected just before the
        // first grid row (see mapContent) instead of the row itself, so its
        // taller panel shows a half-line of breathing room above the grid
        // rather than just extra blank space at the bottom.
        if isLandscape, lines.count > 3 {
            proxy.scrollTo("landscapeMapHalfLineSpacer", anchor: .top)
            return
        }
        let target = lines.count > 3 ? lines[3] : lines.first
        if let target {
            proxy.scrollTo(target.id, anchor: .top)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        // Respect a deliberate scroll-up — e.g. scrolling back up mid-combat to
        // reread what happened — instead of snapping back down. Once the
        // reader isn't at the bottom any more, stay out of their way until
        // they scroll back down themselves (see isNearBottom).
        guard isNearBottom else { return }
        // Scroll to the sentinel itself (not the last content line) — anchoring
        // the last line at .bottom would leave the 1pt sentinel just past the
        // visible edge, flipping isNearBottom to false right after every
        // auto-scroll and permanently disabling this feature on first use.
        withAnimation {
            proxy.scrollTo("bottomSentinel", anchor: .bottom)
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
            } else if gameEngine.closeHandler == nil {
                // Nothing else applies and there's no closeHandler — an
                // orphaned screen. Fall back to the same emergency exit the
                // X icon uses, rather than the Return key doing nothing.
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
        if line.isUnderlined {
            result.underlineStyle = .single
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
    /// Undo/redo handlers — shown as ↩/↪ segments in the compact nav cell
    var onUndo: (() -> Void)? = nil
    var onRedo: (() -> Void)? = nil
    /// 0-based index of the menu button targeted by undo/redo (highlighted visually)
    var undoTargetIndex: Int? = nil
    var redoTargetIndex: Int? = nil

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

    /// Indices of compact-nav buttons (⏮, ⏭, ?)
    private var compactIndices: [Int] {
        options.indices.filter { options[$0].isCompactNav }
    }

    /// Regular (non-compact) button indices
    private var regularIndices: [Int] {
        options.indices.filter { !options[$0].isCompactNav }
    }

    var body: some View {
        let compact = compactIndices
        let regular = regularIndices
        let spacerIndex = needsTrailingSpacer ? options.count - 1 : -1

        LazyVGrid(columns: gridColumns, spacing: isCompact ? 4 : 6) {
            // Regular buttons — the displayed "N." is this button's position
            // among just the regular (numbered) buttons, not its raw index
            // into the full options array. Those differ whenever a compact
            // item (e.g. << on page 2+) sits earlier in that array: without
            // this, the first real button on page 2 would show "2." instead
            // of "1.", silently offset by however many compact items
            // precede it — inconsistent with the on-screen list above it.
            ForEach(Array(regular.enumerated()), id: \.element) { displayPos, index in
                let option = options[index]
                if index == spacerIndex {
                    Color.clear
                        .frame(minHeight: buttonMinHeight)
                }
                regularButton(option: option, index: index, fallbackDisplayNumber: displayPos + 1)
            }

            // Compact nav cell (↩ ⏮ ? ⏭ ↪) — single cell, bottom right
            if !compact.isEmpty {
                // Push to right column if regular count is even
                if regular.count % 2 == 0 {
                    Color.clear.frame(minHeight: buttonMinHeight)
                }
                compactNavCell(indices: compact)
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

    /// A standard full-width button. `index` is the real position in the
    /// full options array (used for selection/undo-redo targeting).
    /// `fallbackDisplayNumber` (the clean 1-based count among just the
    /// regular buttons on this page — see the ForEach comment in body) is
    /// shown unless the option carries its own explicit displayNumber (set
    /// by a caller whose printed reference list needs to match a stable,
    /// pagination-independent number instead).
    @ViewBuilder
    private func regularButton(option: MenuOption, index: Int, fallbackDisplayNumber: Int) -> some View {
        let isUndoTarget = undoTargetIndex == index
        let isRedoTarget = redoTargetIndex == index
        let shownNumber = option.displayNumber ?? fallbackDisplayNumber
        Button(action: {
            if !option.isDisabled {
                onSelect(index + 1)
            }
        }) {
            HStack(spacing: 4) {
                Text("\(shownNumber).")
                    .font(.system(size: 11 * scale, design: .monospaced))
                    .foregroundColor(buttonNumberColor(option))

                styledOptionText(option, index: index)
                    .font(.system(size: 13 * scale, design: .monospaced))
                    .fontWeight(option.isDefault || option.isAlert ? .semibold : .regular)
                    .foregroundColor(buttonTextColor(option))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                // Undo/redo target indicators — subtle amber hint
                if isUndoTarget && isRedoTarget {
                    Text("↩↪")
                        .font(.system(size: 10 * scale, design: .monospaced))
                        .foregroundColor(terminalAmber.opacity(0.5))
                } else if isUndoTarget {
                    Text("↩")
                        .font(.system(size: 10 * scale, design: .monospaced))
                        .foregroundColor(terminalAmber.opacity(0.5))
                } else if isRedoTarget {
                    Text("↪")
                        .font(.system(size: 10 * scale, design: .monospaced))
                        .foregroundColor(terminalAmber.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, buttonVerticalPadding)
            .frame(minHeight: buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isUndoTarget || isRedoTarget ? terminalAmber.opacity(0.35) : buttonStrokeColor(option),
                            lineWidth: option.isDefault || option.isAlert || isUndoTarget || isRedoTarget ? 2 : 1)
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

    /// Fixed 3-slot compact nav cell: [slot0 | slot1 | slot2]
    /// Slot 0 = << > < Back > other compact item > empty
    /// Slot 1 = ? > other compact item > empty
    /// Slot 2 = >> > other compact item > empty
    ///
    /// << and "< Back" always land in the same left-hand slot so the cell
    /// reads consistently everywhere: "leave/go back" on the left, "?" in
    /// the middle, "next page" on the right. They're never both shown at
    /// once — on a page where you can still go back within the list (<<
    /// active), that takes the slot; "< Back" (leave the screen entirely)
    /// only appears once << is gone, i.e. once you've paged back to the
    /// first page. Paging back that far is itself a way out, so nothing is
    /// lost by not showing both at once.
    private enum CompactSlotContent {
        case menuItem(Int) // index into options
        case empty
    }

    @ViewBuilder
    private func compactNavCell(indices: [Int]) -> some View {
        // Map known compact symbols to their index
        let backIdx = indices.first(where: { options[$0].text == "<<" })
        let backButtonIdx = indices.first(where: { options[$0].text == "< Back" })
        let helpIdx = indices.first(where: { options[$0].text == "?" || options[$0].text == "?\u{0338}" })
        let nextIdx = indices.first(where: { options[$0].text == ">>" })

        // Any other compact items (e.g. 🎲, ↺) fill remaining empty slots
        let knownIdxs = Set([backIdx, backButtonIdx, helpIdx, nextIdx].compactMap { $0 })
        let otherIndices = indices.filter { !knownIdxs.contains($0) }
        var otherIter = otherIndices.makeIterator()

        // Slot 0: << > < Back > other > empty — << wins when both are
        // active, since paging back to page 0 already gets you to where
        // "< Back" would otherwise be needed.
        let slot0: CompactSlotContent = {
            if let i = backIdx { return .menuItem(i) }
            if let i = backButtonIdx { return .menuItem(i) }
            if let i = otherIter.next() { return .menuItem(i) }
            return .empty
        }()
        // Slot 1: ? > other > empty — always the help slot, never shared
        // with Back, so its position is consistent across every screen.
        let slot1: CompactSlotContent = {
            if let i = helpIdx { return .menuItem(i) }
            if let i = otherIter.next() { return .menuItem(i) }
            return .empty
        }()
        // Slot 2: >> > other > empty
        let slot2: CompactSlotContent = {
            if let i = nextIdx { return .menuItem(i) }
            if let i = otherIter.next() { return .menuItem(i) }
            return .empty
        }()

        let slots = [slot0, slot1, slot2]
        // Matches regularButton's font exactly (13pt, semibold only for
        // default/alert) so compact nav cells (<</>>/?/pinned "< Back" etc.)
        // never look like a different font from the rest of the buttons.
        let compactFontSize: CGFloat = 13 * scale

        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { slotIdx in
                let isActive: Bool = {
                    switch slots[slotIdx] {
                    case .empty: return false
                    default: return true
                    }
                }()

                ZStack {
                    // Subtle background highlight for active slots
                    if isActive {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(terminalDimGreen.opacity(0.08))
                            .padding(2)
                    }

                    switch slots[slotIdx] {
                    case .menuItem(let index):
                        let option = options[index]
                        Button(action: { onSelect(index + 1) }) {
                            Text(option.text)
                                .font(.system(size: compactFontSize, design: .monospaced))
                                .fontWeight(option.isDefault || option.isAlert ? .semibold : .regular)
                                .foregroundColor(terminalDimGreen)
                                .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(pressedIndex == index + 1 ? 0.92 : 1.0)
                        .brightness(pressedIndex == index + 1 ? 0.3 : 0.0)
                        .animation(.easeInOut(duration: 0.15), value: pressedIndex)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: longPressDuration)
                                .onEnded { _ in onLongPress?(index + 1) }
                        )
                    case .empty:
                        Text("·")
                            .font(.system(size: 10 * scale, design: .monospaced))
                            .foregroundColor(terminalDimGreen.opacity(0.2))
                            .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                    }
                }
                // Divider between slots — always visible
                if slotIdx < 2 {
                    Rectangle()
                        .fill(terminalDimGreen.opacity(0.3))
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(minHeight: buttonMinHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(terminalDimGreen.opacity(0.4), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(terminalDarkDimGreen.opacity(0.15))
                )
        )
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
        [GridItem(.flexible()), GridItem(.flexible())]
    }
}

// MARK: - Direction Pad

struct DirectionPadView: View {
    let exits: [Direction: Bool]
    var secured: Set<Direction> = []
    let scale: CGFloat
    /// Overrides the button cell width (each of the 3x3 grid's columns is
    /// one of these) below its normal max(80, 80*scale) floor — set when
    /// the pad has to fit a column narrower than that floor allows (e.g.
    /// landscape's map|icons|text three-way split), rather than overflowing
    /// its allotted space. Leave nil for the normal floor-respecting size.
    var cellWidth: CGFloat? = nil
    let onSelect: (Direction) -> Void
    var onLongPress: ((Direction) -> Void)? = nil
    var centerLabel: String? = nil
    var onCenterTap: (() -> Void)? = nil
    var onCenterLongPress: (() -> Void)? = nil
    var longPressDuration: Double = 0.5
    var torchOff: Bool = false
    var npcLabel: String? = nil
    var onNPCTap: (() -> Void)? = nil
    var onTeleportTap: (() -> Void)? = nil
    var torchLabel: String? = nil
    var onTorchTap: (() -> Void)? = nil
    var onSearchTap: (() -> Void)? = nil
    var onListenTap: (() -> Void)? = nil

    let terminalGreen = Color(red: 0.0, green: 0.9, blue: 0.3)
    let terminalDarkGreen = Color(red: 0.0, green: 0.4, blue: 0.15)
    let disabledGreen = Color(red: 0.1, green: 0.25, blue: 0.1)
    let centerBlue = Color(red: 0.2, green: 0.5, blue: 0.8)
    let uncertainGrey = Color(red: 0.35, green: 0.35, blue: 0.35)
    let securedAmber = Color(red: 0.8, green: 0.6, blue: 0.1)

    private let npcCyan = Color(red: 0.2, green: 0.7, blue: 0.9)
    private let teleportPurple = Color(red: 0.65, green: 0.4, blue: 0.9)
    private let torchBlue = Color(red: 0.3, green: 0.55, blue: 0.95)
    private let searchAmber = Color(red: 0.8, green: 0.6, blue: 0.2)
    private let listenAmber = Color(red: 0.8, green: 0.6, blue: 0.2)

    private var effectiveCellWidth: CGFloat { cellWidth ?? max(80, 80 * scale) }

    @ViewBuilder
    private func cornerIconButton(systemName: String, color: Color, action: (() -> Void)?) -> some View {
        if let action = action {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 16 * scale))
                    .foregroundColor(color)
                    .frame(width: effectiveCellWidth, height: max(44, 34 * scale))
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color.opacity(0.6), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color.opacity(0.15))
                            )
                    )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: effectiveCellWidth, height: max(44, 34 * scale))
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Search Room (NW) + North + Listen (NE) — mirrors the bottom
            // row's [Torch | South | NPC] so the whole pad reads as three
            // symmetric rows.
            HStack(spacing: 4) {
                // Teleport pad always lives here (top-left/NW) — a fixed,
                // predictable spot rather than bouncing between corners
                // depending on whether an NPC also happens to be in the
                // room. Search Room is still reachable as a full menu
                // button, so bumping its shortcut icon here costs nothing.
                if onTeleportTap != nil {
                    cornerIconButton(systemName: "target", color: teleportPurple, action: onTeleportTap)
                } else {
                    cornerIconButton(systemName: "sparkle.magnifyingglass", color: searchAmber, action: onSearchTap)
                }
                dirButton(.north)
                cornerIconButton(systemName: "ear", color: listenAmber, action: onListenTap)
            }
            // West + Center + East
            HStack(spacing: 4) {
                dirButton(.west)
                if let label = centerLabel, let action = onCenterTap {
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 11 * scale, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(centerBlue)
                            .frame(width: effectiveCellWidth, height: max(44, 34 * scale))
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
            // Torch (SW) + South + NPC (SE)
            HStack(spacing: 4) {
                cornerIconButton(systemName: torchLabel == "Douse" ? "flame.fill" : "flame", color: torchBlue, action: onTorchTap)
                dirButton(.south)
                // Teleport now has its own fixed NW slot above, so this
                // corner is simply NPC-or-nothing again.
                if npcLabel != nil {
                    cornerIconButton(systemName: "scroll", color: npcCyan, action: onNPCTap)
                } else {
                    Color.clear.frame(width: effectiveCellWidth, height: max(44, 34 * scale))
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
                    .frame(width: effectiveCellWidth, height: max(44, 34 * scale))
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
#elseif os(macOS)
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
#else
// tvOS/watchOS: no UIViewRepresentable/NSViewRepresentable GIF playback here —
// this is purely decorative (the main menu dragon), so a plain empty view is
// a fine stand-in rather than pulling in a whole animated-image dependency.
struct AnimatedGIFView: View {
    let gifName: String
    var body: some View { EmptyView() }
}
#endif

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView()
            .environmentObject(GameEngine())
    }
}
