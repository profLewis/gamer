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

/// Where an in-text link line sits on screen — the text area's tap-to-
/// continue strip lies on top of the text, so it checks these first and
/// follows a tapped link instead of continuing.
private struct LinkFrame: Equatable {
    let key: String
    let rect: CGRect
}

private struct LinkFramesKey: PreferenceKey {
    static var defaultValue: [LinkFrame] = []
    static func reduce(value: inout [LinkFrame], nextValue: () -> [LinkFrame]) {
        value.append(contentsOf: nextValue())
    }
}

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
    /// Last gameEngine.screenGeneration value we actually scrolled-to-top
    /// for — lets the scroll-to-top handler tell "brand new screen" apart
    /// from "same screen, more content appended" (see its own comment).
    @State private var lastScrolledGeneration: Int = -1
    /// Measured D-pad height — lets the portrait controls block keep a
    /// steady height with its spare room above the D-pad.
    @State private var dpadMeasuredHeight: CGFloat = 0
    /// Scrolling rules (see the terminalLines.count handler): when this
    /// page appeared, how many lines it had when last looked at, and a
    /// token that cancels a pending Auto-Scroll glide once the page changes.
    @State private var screenShownAt: Date = .distantPast
    @State private var lastSeenLineCount: Int = 0
    @State private var focusScheduled: Bool = false
    @State private var glideToken = UUID()
    @State private var linkFrames: [LinkFrame] = []
    #if os(macOS)
    /// Mac pane sizes, set by dragging the small handles (remembered).
    /// 0 = map pane tall enough for the whole map box, key included.
    @AppStorage("macLeftPaneFraction") private var macLeftPaneFraction: Double = 0.5
    @State private var macDragBase: CGFloat? = nil
    #endif
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
    /// The big map's zoom (pinch, or the -/+ buttons).
    @State private var mapZoom: CGFloat = 1
    /// Which story lines are on screen (roughly — the list is lazy), so a
    /// swipe over the controls can scroll the story by whole lines. A
    /// reference, so updating it doesn't redraw the view.
    final class LineVisibility { var indices = Set<Int>() }
    @State private var lineVisibility = LineVisibility()
    @State private var swipeScrollLines = 0
    @State private var swipeScrollToken = 0
    @State private var pinchScale: CGFloat = 1
    @State private var showMapButtonHelp = false

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
            // Map's own font stays the regular text scale — "bigger map"
            // on macOS means showing more of the dungeon (a wider viewport
            // — see GameEngine.bestMapRadius's macOS branch), not a bigger
            // font blown up to fill extra window space.
            let mapScale = scale
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
                                TerminalLineView(line: line, scale: mapScale)
                            }
                        }
                        #if os(macOS)
                        // Mac: the box sits in the middle of its pane, so @ (always
                        // the middle of the grid) is the middle of the map area too.
                        .frame(maxWidth: .infinity, alignment: .center)
                        #else
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #endif
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
                        #if os(macOS)
                        // Mac: from the dotted line under MAP to the one under "@ here"
                        // — the header and key are a scroll away, leaving more room
                        // for text. Its rows are the Map Length setting (the handle
                        // below sets it too).
                        .frame(height: CGFloat(gameEngine.mapOnlyLineCount + 1) * (gameEngine.mapFontSize * mapScale * 1.3 + 2) + 6)
                        // Tell the engine the pane's width, so the map's extent follows it.
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: MacMapPaneWidthKey.self, value: geo.size.width)
                        })
                        .onPreferenceChange(MacMapPaneWidthKey.self) { width in gameEngine.macMapPaneChanged(width: width) }
                        #elseif os(tvOS)
                        .frame(height: CGFloat(gameEngine.pinnedMapLines.count) * (gameEngine.mapFontSize * mapScale * 1.3 + 2) + 8)
                        #else
                        .frame(height: (CGFloat(gameEngine.mapOnlyLineCount) - (isLandscape ? 0.0 : 0.5)) * (gameEngine.mapFontSize * mapScale * 1.3 + 2))
                        #endif
                        .background(terminalBackground)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.5) {
                            gameEngine.showExpandedMapOverlay()
                        }
                        // VoiceOver: a plain-words summary, not a string of ASCII.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(gameEngine.mapAccessibilitySummary)
                        .accessibilityHint("Long-press for the whole map")

                        // No on-screen resize control here — a drag handle
                        // was fiddly against the nearby scroll gestures, and
                        // even a plain tap-to-cycle button was still visual
                        // clutter sitting on every screen with a map. Sizing
                        // lives entirely in Settings > Gameplay > Map Radius
                        // > Panel Size instead, out of the way until wanted.
                        // (No divider line under the map either — the map
                        // panel's own background marks where it ends.)
                        #if os(macOS)
                        // Mac: drag this small handle to show more or fewer rooms up
                        // and down — it sets Map Length (Settings > Gameplay), the pane
                        // snapping to whole rows. Double-click: back to the default 3.
                        macPaneHandle(vertical: false)
                            .gesture(DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let lineHeight = gameEngine.mapFontSize * mapScale * 1.3 + 2
                                    let base = macDragBase ?? CGFloat(gameEngine.mapOnlyLineCount + 1) * lineHeight + 6
                                    macDragBase = base
                                    let target = max(80, min(geometry.size.height - 140, base + value.translation.height))
                                    gameEngine.macFitMapRows(toHeight: target, lineHeight: lineHeight)
                                }
                                .onEnded { _ in macDragBase = nil })
                            .onTapGesture(count: 2) { gameEngine.macSetMapRows(3) }
                        #endif
                    }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilitySortPriority(2)   // VoiceOver: the map, then the story

                    // Terminal output area
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(gameEngine.terminalLines.enumerated()), id: \.element.id) { index, line in
                                    Group {
                                    if let link = line.link {
                                        // In-text link — always its own tap target, whatever
                                        // the screen's other tap handling is.
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture { gameEngine.followLink(link) }
                                            .background(GeometryReader { geo in
                                                Color.clear.preference(key: LinkFramesKey.self,
                                                                       value: [LinkFrame(key: link, rect: geo.frame(in: .global))])
                                            })
                                    } else if gameEngine.textTapEnabled {
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                gameEngine.textLongPressHandler?(index)
                                            }
                                    } else if gameEngine.swipeLeftHandler != nil && gameEngine.currentCombat == nil {
                                        // Out-of-combat card browsers (monster/NPC detail, character
                                        // cards, tale reader...) — advancing to the next card is the
                                        // whole point here, so the full line stays one big tap target.
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                gameEngine.swipeLeftHandler?()
                                            }
                                    } else if gameEngine.swipeLeftHandler != nil || gameEngine.awaitingContinue {
                                        // Live combat, AND any timed/auto-dismiss info page (rest/trap/
                                        // NPC results, etc.) — advancing used to be a tap ANYWHERE on the
                                        // line, full width, which made it impossible to scroll back up to
                                        // reread a long result before its timeout fired: any tap meant to
                                        // start a scroll just advanced instead. The tap-to-advance zone
                                        // now lives only in a strip on the left edge (see the
                                        // tapToAdvanceStrip overlay below) — everywhere else is free for
                                        // ordinary scroll drags.
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                    } else {
                                        TerminalLineView(line: line, scale: scale)
                                            .id(line.id)
                                    }
                                    }
                                    .onAppear { lineVisibility.indices.insert(index) }
                                    .onDisappear { lineVisibility.indices.remove(index) }
                                }
                                // Animated GIF (e.g. main menu dragon)
                                if let gifName = gameEngine.dragonGifName {
                                    HStack {
                                        Spacer()
                                        AnimatedGIFView(gifName: gifName)
                                            // Fits its column and at most ~35% of the screen's
                                            // height — landscape phones used to get the full
                                            // portrait size, running off the screen.
                                            .frame(width: landingDragonWidth(geometry.size, isLandscape: isLandscape),
                                                   height: landingDragonWidth(geometry.size, isLandscape: isLandscape) * 186 / 280)
                                            .clipped()
                                            .offset(x: -6 * scale) // Centre the dragon's head, not the image
                                        Spacer()
                                    }
                                    if let caption = gameEngine.currentPoseCaption {
                                        Text(caption)
                                            .font(.system(size: 11 * scale, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .multilineTextAlignment(.center)
                                            .onTapGesture { gameEngine.showPoseLore(for: caption) }
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
                                // EXCEPT when this is a genuinely new screen (screenGeneration
                                // changed since the last scroll) — the recent-manual-scroll guard
                                // is only meant to protect "still reading the same paginated
                                // content, just tapped a nav button" from being yanked back to
                                // top; it must not also suppress the very first scroll-to-top of
                                // a brand new screen. Without this, a few points of incidental
                                // finger movement during the tap that OPENED this new screen
                                // (trivially easy on a real touchscreen) read as "the reader just
                                // manually scrolled," leaving the new screen at whatever offset
                                // the previous one was scrolled to — which can be well past this
                                // screen's shorter content, i.e. showing nothing at all until an
                                // unrelated later transition happened to land right.
                                let isNewScreen = gameEngine.screenGeneration != lastScrolledGeneration
                                guard isNewScreen || !recentlyScrolledManually else { return }
                                lastScrolledGeneration = gameEngine.screenGeneration
                                scrollToTop(scrollProxy)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    guard gameEngine.suppressAutoScroll else { return }
                                    scrollToTop(scrollProxy)
                                }
                            } else {
                                let count = gameEngine.terminalLines.count
                                if gameEngine.screenGeneration != lastScrolledGeneration {
                                    // A NEW PAGE always shows its start — the reader must see
                                    // the top of long text (help, lore, results). Auto-Scroll
                                    // (Accessibility) may then glide down it; otherwise the
                                    // reader scrolls for themselves.
                                    lastScrolledGeneration = gameEngine.screenGeneration
                                    screenShownAt = Date()
                                    lastSeenLineCount = count
                                    let token = UUID()
                                    glideToken = token
                                    jumpToTop(scrollProxy)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        guard glideToken == token else { return }
                                        jumpToTop(scrollProxy)
                                    }
                                    scheduleAutoGlide(scrollProxy, token: token)
                                    return
                                }
                                // Same page: its own first burst of printing — stay at the top.
                                if Date().timeIntervalSince(screenShownAt) < 0.5 {
                                    lastSeenLineCount = count
                                    return
                                }
                                // Text added afterwards — a result, a warning, the DM's reply:
                                // bring it into view (usually the end of the page; the start of
                                // the new block if it's long). The reader can still scroll back
                                // up to see the rest.
                                guard !focusScheduled else { return }
                                focusScheduled = true
                                let firstNew = lastSeenLineCount
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    focusScheduled = false
                                    guard !gameEngine.suppressAutoScroll else { return }
                                    let lines = gameEngine.terminalLines
                                    lastSeenLineCount = lines.count
                                    let added = lines.count - firstNew
                                    guard added > 0 else { return }
                                    glideToken = UUID()   // new text takes over from any glide
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if added > 14 && firstNew >= 0 && firstNew < lines.count {
                                            scrollProxy.scrollTo(lines[firstNew].id, anchor: .top)
                                        } else {
                                            scrollProxy.scrollTo("bottomSentinel", anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        // A vertical swipe over the controls scrolls the story.
                        .onChange(of: swipeScrollToken) { _ in
                            let lines = gameEngine.terminalLines
                            guard !lines.isEmpty else { return }
                            let top = lineVisibility.indices.min() ?? 0
                            let target = min(max(0, top + swipeScrollLines), lines.count - 1)
                            lastManualScrollAt = Date()
                            withAnimation(.easeOut(duration: 0.3)) { scrollProxy.scrollTo(lines[target].id, anchor: .top) }
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
                    .onPreferenceChange(LinkFramesKey.self) { linkFrames = $0 }
                    .overlay(alignment: .leading) { tapToAdvanceStrip }
                    #if !os(tvOS)
                    // tvOS has no touch/swipe input (remote + focus engine
                    // instead) — swipe-left/right card navigation doesn't apply.
                    // simultaneousGesture, not gesture: a plain .gesture() here
                    // competed with the ScrollView's own native drag-to-scroll
                    // recognizer for every touch inside it — on many drags it
                    // won that race and swallowed the touch before the
                    // ScrollView ever saw it, which is why this text/combat
                    // log read as "not scrollable" even though nothing was
                    // actually disabling scroll. This gesture's own logic
                    // already ignores anything that isn't a clear, mostly-
                    // horizontal swipe, so letting it run alongside scrolling
                    // instead of ahead of it doesn't change when it fires.
                    .simultaneousGesture(
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
                                    } else if gameEngine.closeHandler != nil {
                                        gameEngine.invokeClose()
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
                    // VoiceOver reads top to bottom: map and story, then the controls.
                    .accessibilityElement(children: .contain)
                    .accessibilitySortPriority(2)
                    #if os(macOS)
                    // Mac: map+text width set by the handle on its right edge.
                    .frame(width: geometry.size.width * CGFloat(macLeftPaneFraction))
                    .overlay(alignment: .trailing) {
                        macPaneHandle(vertical: true)
                            .gesture(DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let base = macDragBase ?? geometry.size.width * CGFloat(macLeftPaneFraction)
                                    macDragBase = base
                                    let width = max(1, geometry.size.width)
                                    macLeftPaneFraction = Double(min(0.75, max(0.3, (base + value.translation.width) / width)))
                                }
                                .onEnded { _ in macDragBase = nil })
                            .onTapGesture(count: 2) { macLeftPaneFraction = 0.5 }
                    }
                    #endif

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
                        // Fight Club (@) in portrait: above the buttons; the text gives way.
                        if !isLandscape && gameEngine.showCombatArena {
                            CombatArenaView(engine: gameEngine, scale: scale)
                                .frame(height: max(170, min(240, geometry.size.height * 0.26)))
                                // A tap on the fight counts as "tap anywhere" to move on.
                                .contentShape(Rectangle())
                                .onTapGesture { advanceFromStrip() }
                        }
                        // (VoiceOver: the buttons before the input line, whichever is on top.)
                        if isLandscape {
                            inputBarAndKeyboardBlock.accessibilitySortPriority(1)
                            dpadAndMenuButtonsBlock.accessibilitySortPriority(2)
                        } else {
                            dpadAndMenuButtonsBlock.accessibilitySortPriority(2)
                            inputBarAndKeyboardBlock.accessibilitySortPriority(1)
                        }
                        // Combat Arena: the fight acted out in ASCII in the space
                        // below the buttons (Mac only for now — see
                        // GameEngine.combatArenaAvailable).
                        if isLandscape && gameEngine.showCombatArena {
                            CombatArenaView(engine: gameEngine, scale: scale)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                // A tap on the fight counts as "tap anywhere" to move on.
                                .contentShape(Rectangle())
                                .onTapGesture { advanceFromStrip() }
                        }
                    }
                    .frame(maxWidth: isLandscape ? .infinity : nil, alignment: .top)
                    // The right-hand panel's empty space counts as "anywhere" for
                    // tap-to-continue too (buttons and the input line keep their own taps).
                    .frame(maxHeight: isLandscape ? .infinity : nil, alignment: .top)
                    .background {
                        if gameEngine.awaitingContinue || gameEngine.swipeLeftHandler != nil {
                            Color.black.opacity(0.001)
                                .contentShape(Rectangle())
                                .onTapGesture { advanceFromStrip() }
                        }
                    }
                    #if !os(tvOS)
                    // Swiping up or down over the controls scrolls the story too.
                    .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                        let dy = value.translation.height
                        guard abs(dy) > abs(value.translation.width) * 1.5, abs(dy) > 30 else { return }
                        let lineHeight = 14 * scale * 1.2 + 2
                        // Finger up: on to later text; finger down: back up.
                        let lines = Int((dy / lineHeight * 1.5).rounded())
                        swipeScrollLines = lines < 0 ? max(3, -lines) : -max(3, lines)
                        swipeScrollToken += 1
                    })
                    #endif
                    .accessibilityElement(children: .contain)
                    .accessibilitySortPriority(1)
                }
                .background(terminalBackground)
                // A full-screen tap-anywhere-to-continue catcher used to live
                // here — it sat on top of EVERYTHING, including the text
                // ScrollView and its own tapToAdvanceStrip below, so it kept
                // intercepting scroll drags no matter how the text area's own
                // tap handling was scoped down. tapToAdvanceStrip (see the
                // text ScrollView's overlay) is the sole tap-to-continue
                // affordance now — a visible, discoverable right-edge strip
                // instead of an invisible full-screen trap.
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
        #if os(iOS)
        // The system text size changed — terminal text follows it.
        .onReceive(NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)) { _ in
            gameEngine.refreshFontScale()
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
        #if !os(tvOS)
        .background(
            Color.clear
                .fileExporter(isPresented: $gameEngine.showAtlasPDFExporter,
                              document: PDFFileDocument(data: gameEngine.pendingAtlasPDF),
                              contentType: .pdf,
                              defaultFilename: gameEngine.pendingAtlasPDFName) { result in
                    gameEngine.handleAtlasExportResult(result)
                }
        )
        #endif
    }

    /// Reserves stable vertical space for the button grid so its position
    /// doesn't shift depending on whether the current screen has 1, 2, or 3
    /// rows of buttons — sized for maxButtonsPerScreen (the "Buttons"
    /// Gameplay setting, 2 per row), using the same row-height/spacing math
    /// as MenuButtonsView itself. A screen with fewer buttons just leaves
    /// blank space below them instead of the whole block (and the text
    /// ScrollView above it, which greedily fills whatever's left) shifting.
    /// In a portrait adventure the D-pad and button areas keep their places
    /// on every screen (blank when unused), so they never jump about.
    private var reserveControlSlots: Bool {
        // Not in combat — there's no D-pad there, and a blank D-pad-sized
        // slot squeezed the combat text into a sliver.
        gameEngine.dungeon != nil && gameEngine.currentCombat == nil
            && !gameEngine.isLandscapeOrientation && !gameEngine.isJustDMActive
    }

    private var portraitControlsMinHeight: CGFloat {
        let dpad = gameEngine.directionExits.isEmpty ? 0 : dpadMeasuredHeight + 6
        return dpad + reservedButtonGridHeight + 12
    }

    private var reservedButtonGridHeight: CGFloat {
        let maxButtons = max(1, gameEngine.maxButtonsPerScreen)
        let rows = Int(ceil(Double(maxButtons) / 2.0))
        let isCompact = maxButtons > 6
        let rowHeight: CGFloat = isCompact ? max(36, 32 * scale) * macControlScale : max(44, 38 * scale) * macControlScale
        let spacing: CGFloat = isCompact ? 4 : 6
        return CGFloat(rows) * rowHeight + CGFloat(max(0, rows - 1)) * spacing
    }

    /// Direction D-pad + action button row — one of Region B's two blocks
    /// (see body), reordered relative to inputBarAndKeyboardBlock depending
    /// on orientation.
    @ViewBuilder
    private var dpadAndMenuButtonsBlock: some View {
                    // Direction pad + menu buttons (hidden in Just DM mode, except on
                    // victory/defeat milestone screens — see forceInteractiveControls).
                    if (!gameEngine.isJustDMActive || gameEngine.forceInteractiveControls || !gameEngine.inDMMode),
                       !gameEngine.directionExits.isEmpty || !gameEngine.currentMenuOptions.isEmpty {
                        // (No controls at all — e.g. a tap-to-continue result — means
                        // no block: the text takes the whole area, all of it tappable.)
                        VStack(spacing: 10) {
                            // Direction D-pad (when exploring)
                            if !gameEngine.directionExits.isEmpty {
                                DirectionPadView(exits: gameEngine.directionExits, secured: gameEngine.securedExits, scale: scale,
                                    onSelect: { direction in
                                        gameEngine.handleDirectionChoice(direction)
                                    },
                                    onLongPress: gameEngine.directionLongPressHandler,
                                    centerLabel: gameEngine.dpadCenterLabel,
                                    onCenterTap: gameEngine.frozenGuard(gameEngine.dpadCenterHandler),
                                    onCenterLongPress: gameEngine.frozenGuard(gameEngine.dpadCenterLongPressHandler),
                                    longPressDuration: gameEngine.longPressDuration,
                                    torchOff: !gameEngine.torchLit,
                                    npcLabel: gameEngine.dpadNPCLabel,
                                    onNPCTap: gameEngine.frozenGuard(gameEngine.dpadNPCHandler),
                                    onTeleportTap: gameEngine.frozenGuard(gameEngine.dpadTeleportHandler),
                                    torchLabel: gameEngine.dpadTorchLabel,
                                    onTorchTap: gameEngine.frozenGuard(gameEngine.dpadTorchHandler),
                                    onSearchTap: gameEngine.frozenGuard(gameEngine.dpadSearchHandler),
                                    onListenTap: gameEngine.frozenGuard(gameEngine.dpadListenHandler)
                                )
                                .background(GeometryReader { geo in
                                    Color.clear
                                        .onAppear { dpadMeasuredHeight = geo.size.height }
                                        .onChange(of: geo.size.height) { dpadMeasuredHeight = $0 }
                                })
                            }
                            // (No blank D-pad placeholder: the controls sit on the input
                            // bar and the button area has a fixed height, so the D-pad is
                            // always in the same place when shown — screens without it
                            // (Atlas, inventory...) give that space to the text instead.)

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
                                    redoTargetIndex: gameEngine.redoTargetButtonIndex,
                                    compactRows: gameEngine.maxButtonsPerScreen > 6,
                                    onHover: { choice, inside in gameEngine.setMenuHover(choice, inside) },
                                    maxGridHeight: reservedButtonGridHeight
                                )
                                // Buttons fill their area from the top — one row is always
                                // the top row of a two-row layout, so nothing jumps about.
                                .frame(minHeight: reservedButtonGridHeight, alignment: .top)
                            } else if reserveControlSlots {
                                Color.clear.frame(height: reservedButtonGridHeight)
                            }

                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .background(Color.black.opacity(0.95))
                        #if !os(tvOS)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                                .onEnded { value in
                                    let horizontal = value.translation.width
                                    let vertical = value.translation.height
                                    guard abs(horizontal) > abs(vertical) * 0.5 else { return }
                                    guard abs(horizontal) > 40 else { return }
                                    if horizontal < 0 {
                                        if let next = gameEngine.swipeLeftHandler {
                                            next()
                                        } else if gameEngine.closeHandler != nil {
                                            gameEngine.invokeClose()
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

    /// Auto-continue countdown — a little hourglass by the > prompt that
    /// turns over as the screen's timeout runs, with a thin ring showing the
    /// time left. Tap it (and only it) to pause/resume — amber, still, with a
    /// gently pulsing "paused" while held; long-press to hurry it along.
    /// Tapping anywhere else still just continues.
    private var autoCountdownBar: some View {
        let paused = gameEngine.autoContinuePaused
        let amber = Color(red: 1.0, green: 0.72, blue: 0.0)
        let size = 20 * scale
        return TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let total = max(0.1, gameEngine.autoCountdownTotal)
            let remaining = gameEngine.autoCountdownPausedRemaining
                ?? max(0, (gameEngine.autoCountdownEnd ?? context.date).timeIntervalSince(context.date))
            let fraction = min(1, max(0, remaining / total))
            // A quick flip every two seconds while running; still when paused.
            let phase = t.truncatingRemainder(dividingBy: 2.0)
            let angle = (paused || gameEngine.reduceAnimations) ? 0 : (phase < 0.45 ? phase / 0.45 * 180 : 180)
            // A soft pulse for "paused", not a blink.
            let pulse = 0.45 + 0.4 * (0.5 + 0.5 * sin(t * 2.6))
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(paused ? amber : terminalDarkGreen.opacity(0.9),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: fraction > 0.5 ? "hourglass.tophalf.filled" : "hourglass.bottomhalf.filled")
                        .font(.system(size: size * 0.55))
                        .foregroundColor(paused ? amber : terminalGreen)
                        .rotationEffect(.degrees(angle))
                }
                .frame(width: size, height: size)
                if paused {
                    Text("paused")
                        .font(.system(size: 11 * scale, design: .monospaced))
                        .foregroundColor(amber.opacity(pulse))
                    // Help on un-pausing, printed onto the current screen.
                    Button(action: { gameEngine.printAutoContinuePauseHelp() }) {
                        Text("?")
                            .font(.system(size: 12 * scale, weight: .semibold, design: .monospaced))
                            .foregroundColor(amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .overlay(Capsule().stroke(amber.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("How to un-pause")
                }
            }
        }
        .frame(height: 26)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onTapGesture { gameEngine.toggleAutoContinuePause() }
        .onLongPressGesture(minimumDuration: 0.45) { gameEngine.hurryAutoContinue() }
        .accessibilityElement()
        .accessibilityLabel(paused ? "Auto-continue paused. Tap to resume." : "Auto-continue countdown. Tap to pause, long-press to hurry.")
        .accessibilityAddTraits(.isButton)
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

                            // Blinking block cursor — a plain on/off setting (Accessibility).
                            // Hidden while the field has focus or holds text, so it never
                            // sits beside the system's own text caret (two cursors at once).
                            if gameEngine.blinkingCursorEnabled && inputText.isEmpty && !isInputFocused && !GameEngine.systemVoiceOverRunning {
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
                                    // Typing on a counting-down screen pauses it — you're busy.
                                    if !newText.isEmpty && gameEngine.awaitingContinue {
                                        gameEngine.pauseAutoContinueForTyping()
                                    }
                                    // Text mode sends what you typed once you stop typing — only
                                    // with Auto-Continue on, and never after a mere 1.5s pause.
                                    if gameEngine.isJustDMActive && gameEngine.autoContinueEnabled && !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        textModeAutoSubmitTimer = Timer.scheduledTimer(withTimeInterval: gameEngine.textAutoSubmitDelay, repeats: false) { _ in
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

                            // Auto-continue countdown — at the right of the line, clear of
                            // where you type. Tap to pause/resume, long-press to hurry.
                            // While time is frozen it always shows — it's how you unfreeze.
                            // Every waiting screen shows it (speaker mode and iOS included).
                            if gameEngine.timeFrozen || (gameEngine.awaitingContinue && gameEngine.showCountdownControl) {
                                autoCountdownBar
                            }
                            // Combat help, among the other symbols on this line.
                            if gameEngine.combatHelpAvailable {
                                Button(action: { gameEngine.showCombatHelpFromBar() }) {
                                    Text(MenuOption.helpGlyph == "Help" ? "?" : MenuOption.helpGlyph)
                                        .font(.system(size: 17 * scale, weight: .semibold, design: .monospaced))
                                        .foregroundColor(terminalGreen)
                                        .padding(.horizontal, 4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Combat help")
                            }
                            // Fight Club: @ shows or hides the fight acted out in ASCII.
                            if gameEngine.fightClubAvailableNow {
                                Button(action: { gameEngine.fightClubOn.toggle() }) {
                                    Text("@")
                                        .font(.system(size: 18 * scale, weight: gameEngine.fightClubOn ? .heavy : .regular, design: .monospaced))
                                        .foregroundColor(gameEngine.fightClubOn ? terminalGreen : TerminalColor.dimGreen.swiftUIColor)
                                        .padding(.horizontal, 4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(gameEngine.fightClubOn ? "Hide Fight Club" : "Show Fight Club")
                            }
                            #if os(macOS)
                            // Settings, always to hand on the Mac — music, AI and the rest;
                            // Back returns to where you were.
                            Menu {
                                Button(gameEngine.musicEnabled ? "Music Off" : "Music On") { gameEngine.toggleMusicQuick() }
                                Button(gameEngine.battleSoundsEnabled ? "Sound Effects Off" : "Sound Effects On") { gameEngine.battleSoundsEnabled.toggle() }
                                Button(gameEngine.combatArenaEnabled ? "Fight Club Off" : "Fight Club On") { gameEngine.combatArenaEnabled.toggle() }
                                Button(gameEngine.hitAnimationsEnabled ? "Hit Animations Off" : "Hit Animations On") {
                                    gameEngine.hitAnimationsEnabled.toggle()
                                    gameEngine.objectWillChange.send()
                                }
                                Divider()
                                Button("Change AI…") { gameEngine.followLink("ai") }
                                Button("DM & Voice…") { gameEngine.followLink("dm") }
                                Button("Gameplay…") { gameEngine.followLink("gameplay") }
                                Button("Accessibility…") { gameEngine.followLink("accessibility") }
                                Divider()
                                Button("All Settings…") { gameEngine.followLink("settings") }
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 17 * scale))
                                    .foregroundColor(terminalGreen)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .help("Settings — music, AI, gameplay (⌘,)")
                            .accessibilityLabel("Settings")
                            #endif

                        if !gameEngine.isJustDMActive || gameEngine.forceInteractiveControls || !gameEngine.inDMMode {
                        // Card navigation — <</>>/swipe mode
                        if let posLabel = gameEngine.cardPositionLabel {
                            if gameEngine.useArrowNavigation {
                                HStack(spacing: 2) {
                                    Button(action: { gameEngine.swipeRightHandler?() }) {
                                        Text("<<")
                                            .accessibilityLabel("Previous card")
                                            .font(.system(size: 13 * scale, design: .monospaced))
                                            .foregroundColor(gameEngine.swipeRightHandler != nil
                                                ? Color(red: 0.0, green: 0.6, blue: 0.25)
                                                : Color(red: 0.2, green: 0.2, blue: 0.2))
                                    }
                                    .disabled(gameEngine.swipeRightHandler == nil)
                                    Text(posLabel)
                                        .font(.system(size: 13 * scale, design: .monospaced))
                                        .foregroundColor(TerminalColor.dimGreen.swiftUIColor)
                                    Button(action: { gameEngine.swipeLeftHandler?() }) {
                                        Text(">>")
                                            .accessibilityLabel("Next card")
                                            .font(.system(size: 13 * scale, design: .monospaced))
                                            .foregroundColor(gameEngine.swipeLeftHandler != nil
                                                ? Color(red: 0.0, green: 0.6, blue: 0.25)
                                                : Color(red: 0.2, green: 0.2, blue: 0.2))
                                    }
                                    .disabled(gameEngine.swipeLeftHandler == nil)
                                    if gameEngine.swipeRandomHandler != nil {
                                        Button(action: { gameEngine.swipeRandomHandler?() }) {
                                            Image(systemName: "dice")
                                                .accessibilityLabel("Random")
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
                                        .foregroundColor(TerminalColor.dimGreen.swiftUIColor)
                                    if gameEngine.swipeRandomHandler != nil {
                                        Button(action: { gameEngine.swipeRandomHandler?() }) {
                                            Image(systemName: "dice")
                                                .accessibilityLabel("Random")
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
                                        .accessibilityLabel("Random")
                                        .font(.system(size: 20 * scale * gameEngine.iconScale))
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        // Undo/redo icon buttons + feedback
                        if gameEngine.undoHandler != nil {
                            Button(action: { gameEngine.undoHandler?() }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .accessibilityLabel("Undo")
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
                                    .accessibilityLabel("Redo")
                                    .font(.system(size: 18 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.95, green: 0.7, blue: 0.2))
                            }
                        }

                        #if os(iOS)
                        // Dismiss system keyboard button (only when system keyboard is active)
                        if isInputFocused {
                            Button(action: { isInputFocused = false }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .accessibilityLabel("Hide keyboard")
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
                                    .accessibilityLabel(gameEngine.speakerModeOn ? "Stop reading aloud" : "Read the screen aloud")
                                    .accessibilityHint("Long-press to pause this page")
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
                                    .accessibilityLabel(voiceInput.isListening ? "Stop listening" : "Voice input")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(voiceInput.isListening ? .red : Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        }
                        #endif

                        // Close button — closeHandler, chat exit, continue, or forced on combat/victory/gameOver
                        if gameEngine.chatInputMode {
                            Button(action: { gameEngine.handleChatExit() }) {
                                Image(systemName: "xmark.circle")
                                    .accessibilityLabel("Close")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        } else if gameEngine.closeHandler != nil {
                            Button(action: {
                                gameEngine.invokeClose()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .accessibilityLabel("Close")
                                    .font(.system(size: 20 * scale * gameEngine.iconScale))
                                    .foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.25))
                            }
                        } else if gameEngine.awaitingContinue {
                            Button(action: {
                                gameEngine.handleContinue()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .accessibilityLabel("Close")
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
                                    .accessibilityLabel("Close")
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

    /// Tap-to-advance zone for card mode / "Press to continue" screens
    /// (victory, level-up, combat reports...) — the left 5/6 of the width is
    /// tappable to advance; the right 1/6 is deliberately left with no
    /// gesture at all, so a scroll drag started there is never mistaken for
    /// a tap. Went through a 44pt right-edge sliver, then a wider-but-still-
    /// right-edge strip, before landing here — no visual marker (a faint
    /// chevron was tried and explicitly not wanted).
    @ViewBuilder
    private var tapToAdvanceStrip: some View {
        if gameEngine.swipeLeftHandler != nil || gameEngine.awaitingContinue {
            GeometryReader { geo in
                HStack(spacing: 0) {
                // Left-handed: the free scrolling edge is on the left instead.
                if gameEngine.leftHanded { Spacer(minLength: 0) }
                Color.clear
                    .frame(width: geo.size.width * 5 / 6)
                    .contentShape(Rectangle())
                    #if os(tvOS)
                    .onTapGesture { advanceFromStrip() }
                    #else
                    // A tap on an in-text link follows the link rather than
                    // continuing — this strip lies on top of the text.
                    .onTapGesture(coordinateSpace: .global) { location in
                        if let hit = linkFrames.first(where: { $0.rect.contains(location) }) {
                            gameEngine.followLink(hit.key)
                        } else {
                            advanceFromStrip()
                        }
                    }
                    #endif
                if !gameEngine.leftHanded { Spacer(minLength: 0) }
                }
            }
        }
    }

    private func advanceFromStrip() {
        if gameEngine.swipeLeftHandler != nil {
            gameEngine.swipeLeftHandler?()
        } else {
            gameEngine.handleContinue()
        }
    }

    /// Easter egg: the whole explored floor, pannable in both directions,
    /// with a Recentre button — shown by long-pressing the pinned map pane.
    private var fullMapOverlay: some View {
        ZStack(alignment: .topTrailing) {
            terminalBackground.opacity(0.98).ignoresSafeArea()
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Group {
                    if gameEngine.pictureMapOn, let level = gameEngine.overlayAtlasLevel {
                        PictureMapView(level: level, fontSize: gameEngine.mapFontSize * scale * mapZoom, showAll: gameEngine.atlasShowAllRooms)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(gameEngine.mapOverlayLines) { line in
                                TerminalLineView(line: line, scale: scale * mapZoom)
                            }
                        }
                    }
                }
                // Live while pinching; the layout settles at the new size after.
                .scaleEffect(pinchScale, anchor: .center)
                .onTapGesture(count: 2) { mapZoom = 1 }   // double-tap: back to normal size
                .padding(16)
                .padding(.top, 44)
            }
            #if !os(tvOS)
            // Pinch to zoom (a trackpad pinch on a Mac): the map scales smoothly
            // under your fingers, then settles at that size when you let go —
            // resizing the layout every frame made it jump about.
            .simultaneousGesture(MagnificationGesture()
                .onChanged { value in pinchScale = min(4 / mapZoom, max(0.4 / mapZoom, value)) }
                .onEnded { value in
                    mapZoom = min(4, max(0.4, mapZoom * value))
                    pinchScale = 1
                })
            #endif
            VStack(alignment: .trailing, spacing: 8) {
                // Symbols only — each one's words are a hover-over hint (and
                // VoiceOver's label), and ? explains them all.
                HStack(spacing: 8) {
                    // Page between the levels you've mapped (the Atlas keeps
                    // every level you've left behind).
                    if gameEngine.atlasLevelCount > 1 {
                        overlayCapsule("Previous level", systemImage: "chevron.left", enabled: gameEngine.atlasLevelIndex > 0) {
                            gameEngine.atlasShowLevel(offset: -1)
                        }
                        overlayCapsule("Next level", systemImage: "chevron.right", enabled: gameEngine.atlasLevelIndex < gameEngine.atlasLevelCount - 1) {
                            gameEngine.atlasShowLevel(offset: 1)
                        }
                    }
                    if gameEngine.atlasExploreAvailable && !gameEngine.atlasScreenActive {
                        overlayCapsule("Explore the rooms, one by one", systemImage: "book.closed") { gameEngine.openAtlasFromOverlay() }
                    }
                    overlayCapsule(gameEngine.atlasShowAllRooms ? "Show only where you've been (The Charted Reaches)" : "Show every room (The Whole Deep)",
                                   systemImage: gameEngine.atlasShowAllRooms ? "map" : "globe") {
                        gameEngine.setAtlasShowAll(!gameEngine.atlasShowAllRooms)
                    }
                    overlayCapsule(gameEngine.pictureMapOn ? "Show as text" : "Show as a picture", systemImage: gameEngine.pictureMapOn ? "text.alignleft" : "photo") {
                        gameEngine.pictureMapOn.toggle()
                    }
                    overlayCapsule("Zoom out", systemImage: "minus.magnifyingglass", enabled: mapZoom > 0.45) { mapZoom = max(0.4, mapZoom / 1.25) }
                    overlayCapsule("Zoom in", systemImage: "plus.magnifyingglass", enabled: mapZoom < 3.9) { mapZoom = min(4, mapZoom * 1.25) }
                    overlayCapsule("Save or print this map", systemImage: "printer") {
                        showMapButtonHelp = false
                        gameEngine.saveOrPrintOverlayMap()
                    }
                    overlayCapsule("What the buttons do", systemImage: "questionmark") { showMapButtonHelp.toggle() }
                    overlayCapsule("Close the map", systemImage: "xmark") {
                        showMapButtonHelp = false
                        gameEngine.recentreMap()
                    }
                }
                if showMapButtonHelp {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Self.mapButtonKey.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                Image(systemName: Self.mapButtonKey[i].symbol)
                                    .frame(width: 22 * scale)
                                Text(Self.mapButtonKey[i].meaning)
                                    .font(.system(size: 12 * scale, design: .monospaced))
                            }
                            .foregroundColor(terminalGreen)
                        }
                        Text("Pinch to zoom (double-tap to reset); drag to look around.")
                            .font(.system(size: 11 * scale, design: .monospaced))
                            .foregroundColor(TerminalColor.dimGreen.swiftUIColor)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.92)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(terminalGreen.opacity(0.6), lineWidth: 1))
                    .onTapGesture { showMapButtonHelp = false }
                }
            }
            .padding(16)
        }
        .transition(.opacity)
    }

    #if os(macOS)
    /// A small grab handle for resizing Mac panes — a short capsule, not a
    /// full-width line, with the matching resize cursor on hover.
    private func macPaneHandle(vertical: Bool) -> some View {
        ZStack {
            Color.clear
            Capsule()
                .fill(terminalDarkGreen.opacity(0.55))
                .frame(width: vertical ? 3 : 40, height: vertical ? 40 : 3)
        }
        .frame(width: vertical ? 10 : nil, height: vertical ? nil : 10)
        .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { (vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() } else { NSCursor.pop() }
        }
    }
    #endif

    /// What each of the big map's symbols means — the ? button's key.
    private static let mapButtonKey: [(symbol: String, meaning: String)] = [
        ("chevron.left", "Previous level you've mapped"),
        ("chevron.right", "Next level you've mapped"),
        ("book.closed", "Explore the rooms, one by one"),
        ("globe", "The Whole Deep — every room"),
        ("map", "The Charted Reaches — where you've been"),
        ("photo", "Show the map as a picture"),
        ("text.alignleft", "Show the map as text"),
        ("minus.magnifyingglass", "Zoom out"),
        ("plus.magnifyingglass", "Zoom in"),
        ("printer", "Save or print (not quite in the spirit of the game!)"),
        ("xmark", "Close the map"),
    ]

    /// The big map's buttons: a symbol in a green circle — the words are a
    /// hover-over hint and VoiceOver's label.
    private func overlayCapsule(_ title: String, systemImage: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 36 * scale, height: 36 * scale)
                .background(Circle().fill(Color.green.opacity(enabled ? 1.0 : 0.35)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(title)
        .accessibilityLabel(title)
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

        // Time frozen: Space unfreezes; any other key just says so.
        if gameEngine.timeFrozen {
            if press.key == .space { gameEngine.toggleAutoContinuePause() } else { gameEngine.showFrozenNotice() }
            return .handled
        }

        // Continue: any key triggers continue — except Space, which
        // pauses/resumes Auto-Continue while a screen is counting down.
        if gameEngine.awaitingContinue {
            if press.key == .space && gameEngine.autoContinueCountdownAvailable {
                gameEngine.toggleAutoContinuePause()
                return .handled
            }
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
            // The button under the mouse, if any; otherwise the default.
            if let hovered = gameEngine.hoveredMenuChoiceIfValid {
                gameEngine.handleMenuChoice(hovered)
                return .handled
            }
            if hasMenu, let defaultIdx = gameEngine.currentMenuOptions.firstIndex(where: { $0.isDefault && !$0.isDisabled }) {
                gameEngine.handleMenuChoice(defaultIdx + 1)
                return .handled
            }
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

    /// Landing-page dragon width: its natural 280pt (x text scale), but no
    /// wider than 80% of its column nor taller than ~35% of the screen.
    private func landingDragonWidth(_ size: CGSize, isLandscape: Bool) -> CGFloat {
        let column = isLandscape ? size.width / 2 : size.width
        return max(120, min(280 * scale, column * 0.8, size.height * 0.35 * 280 / 186))
    }

    /// New page: straight to its first line, no animation (it should simply
    /// already be there, not visibly scroll into place).
    private func jumpToTop(_ proxy: ScrollViewProxy) {
        if let firstLine = gameEngine.terminalLines.first {
            proxy.scrollTo(firstLine.id, anchor: .top)
        }
    }

    /// Accessibility > Auto-Scroll: a moment after a long page appears,
    /// glide down it at the chosen speed. Off by default — then scrolling
    /// long text is entirely up to the reader. A touch/scroll by the reader
    /// (or the page changing) stops it.
    private func scheduleAutoGlide(_ proxy: ScrollViewProxy, token: UUID) {
        let linesPerSecond = gameEngine.autoScrollLinesPerSecond
        guard linesPerSecond > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard glideToken == token, !isNearBottom,
                  Date().timeIntervalSince(lastManualScrollAt) > 1.5 else { return }
            let lines = gameEngine.terminalLines.count
            let duration = max(0.8, Double(max(0, lines - 10)) / linesPerSecond)
            withAnimation(.linear(duration: duration)) {
                proxy.scrollTo("bottomSentinel", anchor: .bottom)
            }
        }
    }

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
        #if os(macOS)
        // Mac: start at the dotted line under MAP (header a scroll up).
        if let target = lines.count > 2 ? lines[2] : lines.first { proxy.scrollTo(target.id, anchor: .top) }
        #elseif os(tvOS)
        if let first = lines.first { proxy.scrollTo(first.id, anchor: .top) }
        #else
        // Landscape's panel is half a line taller — show that extra half
        // line ABOVE the first grid row (a little of what's above the map)
        // rather than as blank space below it. scrollTo's anchor lines up
        // the same relative point of the row and the panel, so solve for
        // the one that puts the row's top half a line down.
        if isLandscape, lines.count > 3 {
            let lineHeight = gameEngine.mapFontSize * scale * 1.3 + 2
            let panelHeight = CGFloat(gameEngine.mapOnlyLineCount) * lineHeight
            let k = (lineHeight / 2) / max(1, panelHeight - lineHeight)
            proxy.scrollTo(lines[3].id, anchor: UnitPoint(x: 0, y: min(1, k)))
            return
        }
        let target = lines.count > 3 ? lines[3] : lines.first
        if let target {
            proxy.scrollTo(target.id, anchor: .top)
        }
        #endif
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
            if let hovered = gameEngine.hoveredMenuChoiceIfValid {
                gameEngine.handleMenuChoice(hovered)
            } else if let defaultIdx = gameEngine.currentMenuOptions.firstIndex(where: { $0.isDefault }) {
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
            } else if gameEngine.awaitingTextInput {
                // An empty Return while the game is waiting for typed text
                // (e.g. text mode, where closeHandler is deliberately nil)
                // is just an accidental tap — often right after text mode's
                // 1.5s auto-submit already sent what was typed. It used to
                // fall through to emergencyExit() below, which resets the
                // whole game back to the dragon home screen.
                return
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

/// Mac: buttons, D-pad and their text a size up — there's room.
#if os(macOS)
let macControlScale: CGFloat = 1.2
#else
let macControlScale: CGFloat = 1.0
#endif

/// The Mac map pane's width — reported on every layout, the first included.
struct MacMapPaneWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The Combat Arena panel: redraws ArenaRenderer's grid many times a second.
struct CombatArenaView: View {
    let engine: GameEngine
    let scale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let fontSize = 13 * scale
            let charWidth = Self.charWidth(fontSize)
            let lineHeight = (fontSize * 1.22).rounded(.up)
            let cols = max(10, Int((geo.size.width - 12) / charWidth))
            let rows = max(4, Int((geo.size.height - 8) / lineHeight))
            TimelineView(.periodic(from: .now, by: engine.reduceAnimations ? 0.5 : 1.0 / 24)) { context in
                let grid = ArenaRenderer.render(engine.arenaScene(), width: cols, height: rows, now: context.date, reduced: engine.reduceAnimations)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<grid.count, id: \.self) { r in
                        Text(Self.attributed(grid[r]))
                            .font(.system(size: fontSize, design: .monospaced))
                            .lineLimit(1)
                            .fixedSize()
                            .frame(height: lineHeight)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .background(Color.black)
        .clipped()
        // The text log says the same thing in words.
        .accessibilityHidden(true)
    }

    /// The monospaced font's real character width — the panel's column
    /// count comes from it, so a row never runs past the edge and wraps.
    static func charWidth(_ fontSize: CGFloat) -> CGFloat {
        #if os(macOS)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        #else
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        #endif
        return max(1, ("M" as NSString).size(withAttributes: [.font: font]).width)
    }

    static func attributed(_ row: [ArenaRenderer.Cell]) -> AttributedString {
        var out = AttributedString()
        var i = 0
        while i < row.count {
            var j = i
            var run = ""
            while j < row.count && row[j].color == row[i].color { run.append(row[j].ch); j += 1 }
            var part = AttributedString(run)
            part.foregroundColor = row[i].color.swiftUIColor
            out += part
            i = j
        }
        return out
    }
}

/// The whole level as one pixel-art landscape: every cell of the map is a
/// patch of textured ground (the room's own kind of floor, dirt passages,
/// bedrock and the odd underground pool), textured by position so it all
/// joins up — walls only where rooms don't connect, and ground that frays
/// into the next room where they do. Tiny pixel sprites mark what each room
/// is; green names and little info panels sit on top. Every room and
/// passage — the full map, as exploring would find it.
struct PictureMapView: View {
    let level: AtlasLevel
    /// The text map's font size — the picture uses the very same grid, so
    /// flicking between the two, everything stays in place.
    let fontSize: CGFloat
    private var zoom: CGFloat { fontSize / 14 }
    /// The Whole Deep (every room) or The Charted Reaches (only where
    /// you've been — passages into the unknown fade off into the rock).
    var showAll: Bool = true
    private var rooms: [AtlasRoom] { showAll ? level.rooms : level.rooms.filter { $0.visited } }

    /// The text map's grid (see Dungeon.atlasMapLines): each room is 5
    /// characters by 2 lines, its "[X]" starting 2 characters in, with the
    /// grid 4 lines down (a title line and the 3-line ATLAS header).
    private struct Layout {
        let minX: Int, minY: Int, cols: Int, rows: Int
        let charW: CGFloat, lineH: CGFloat
        var cellW: CGFloat { charW * 5 }
        var cellH: CGFloat { lineH * 2 }
        var originX: CGFloat { charW * 3.5 - cellW / 2 }
        var originY: CGFloat { lineH * 4.5 - cellH / 2 }
        func origin(_ x: Int, _ y: Int) -> CGPoint {
            CGPoint(x: originX + CGFloat(x - minX) * cellW, y: originY + CGFloat(y - minY) * cellH)
        }
        func centre(_ x: Int, _ y: Int) -> CGPoint {
            let o = origin(x, y)
            return CGPoint(x: o.x + cellW / 2, y: o.y + cellH / 2)
        }
    }

    private static let pixelsPerCell = 12

    /// The monospaced font's real character width and line height (plus the
    /// text map's 2pt line spacing).
    private var metrics: (charW: CGFloat, lineH: CGFloat) {
        #if os(macOS)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let lineHeight = font.ascender - font.descender + font.leading
        #else
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let lineHeight = font.lineHeight
        #endif
        let charW = ("M" as NSString).size(withAttributes: [.font: font]).width
        return (charW, ceil(lineHeight) + 2)
    }

    private var layout: Layout {
        let xs = rooms.map { $0.x }, ys = rooms.map { $0.y }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let m = metrics
        return Layout(minX: minX, minY: minY, cols: maxX - minX + 1, rows: maxY - minY + 1, charW: m.charW, lineH: m.lineH)
    }

    var body: some View {
        let l = layout
        Canvas { ctx, size in draw(&ctx, size, l) }
            .frame(width: l.originX + CGFloat(l.cols) * l.cellW + l.charW * 3,
                   height: l.originY + CGFloat(l.rows) * l.cellH + l.lineH * 2)
            .accessibilityLabel("Picture map of \(level.dungeonName), level \(level.level): \(rooms.count) rooms")
    }

    private struct RGB: Equatable {
        var r: Double, g: Double, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        func scaled(_ k: Double) -> RGB { RGB(r * k, g * k, b * k) }
        var color: Color { Color(red: r, green: g, blue: b) }
    }

    private enum Terrain { case bedrock, water, stone, corridor, treasure, library, shrine, armoury, prison, shop, entrance, boss, trap }

    private static func terrain(for typeName: String) -> Terrain {
        let k = typeName.lowercased()
        if k.contains("treasure") { return .treasure }
        if k.contains("trap") { return .trap }
        if k.contains("boss") { return .boss }
        if k.contains("shrine") { return .shrine }
        if k.contains("library") { return .library }
        if k.contains("armour") || k.contains("armor") { return .armoury }
        if k.contains("prison") { return .prison }
        if k.contains("shop") { return .shop }
        if k.contains("entrance") { return .entrance }
        if k.contains("corridor") { return .corridor }
        return .stone
    }

    /// A stable 0..<1 value for a pixel — the same every time it's drawn.
    private static func noise(_ x: Int, _ y: Int, _ seed: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ seed &* 1442695041)
        h = (h ^ (h >> 13)) &* 1274126177
        h ^= h >> 16
        return Double(h & 0xffff) / 65536
    }

    /// Ground textures by global pixel position, so neighbouring cells of the
    /// same ground join seamlessly into one landscape.
    private static func texture(_ t: Terrain, _ x: Int, _ y: Int) -> RGB {
        let n = noise(x, y, 1)
        func pick(_ p: [RGB]) -> RGB { p[min(p.count - 1, Int(n * Double(p.count)))] }
        switch t {
        case .bedrock:
            if n > 0.97 { return RGB(0.22, 0.20, 0.17) }                       // pebbles
            return pick([RGB(0.09, 0.08, 0.07), RGB(0.11, 0.10, 0.08), RGB(0.08, 0.07, 0.06), RGB(0.13, 0.11, 0.09)])
        case .water:
            if noise(x / 2, y, 5) > 0.9 { return RGB(0.45, 0.65, 0.85) }       // ripples
            return pick([RGB(0.10, 0.22, 0.42), RGB(0.12, 0.26, 0.48), RGB(0.09, 0.20, 0.38)])
        case .stone:
            if x % 4 == 0 || y % 4 == 0 { return RGB(0.24, 0.24, 0.27) }       // grout between flagstones
            return pick([RGB(0.38, 0.38, 0.42), RGB(0.34, 0.34, 0.38), RGB(0.42, 0.41, 0.45)])
        case .corridor:
            return pick([RGB(0.36, 0.27, 0.18), RGB(0.32, 0.24, 0.16), RGB(0.40, 0.30, 0.20), RGB(0.30, 0.23, 0.15)])
        case .treasure:
            if n > 0.95 { return RGB(1.0, 0.92, 0.45) }                         // glints
            return pick([RGB(0.58, 0.46, 0.18), RGB(0.52, 0.41, 0.15), RGB(0.62, 0.50, 0.21)])
        case .library:
            if y % 3 == 0 { return RGB(0.24, 0.15, 0.08) }                       // plank seams
            return pick([RGB(0.46, 0.30, 0.16), RGB(0.42, 0.27, 0.14), RGB(0.50, 0.33, 0.18)])
        case .shrine:
            return ((x / 2) + (y / 2)) % 2 == 0 ? RGB(0.26, 0.36, 0.62) : RGB(0.20, 0.28, 0.52)
        case .armoury:
            if x % 6 == 0 || y % 6 == 0 { return RGB(0.18, 0.19, 0.21) }         // plate edges
            if x % 6 == 2 && y % 6 == 2 { return RGB(0.55, 0.56, 0.60) }         // rivets
            return pick([RGB(0.32, 0.33, 0.36), RGB(0.29, 0.30, 0.33)])
        case .prison:
            if n > 0.93 { return RGB(0.55, 0.48, 0.20) }                         // straw
            if x % 3 == 0 || y % 3 == 0 { return RGB(0.12, 0.12, 0.13) }
            return pick([RGB(0.21, 0.21, 0.23), RGB(0.18, 0.18, 0.20)])
        case .shop:
            if y % 3 == 0 { return RGB(0.30, 0.18, 0.09) }
            return pick([RGB(0.55, 0.36, 0.18), RGB(0.50, 0.32, 0.16)])
        case .entrance:
            if n > 0.96 { return RGB(0.95, 0.85, 0.30) }                          // flowers
            return pick([RGB(0.18, 0.42, 0.16), RGB(0.15, 0.36, 0.13), RGB(0.22, 0.48, 0.19)])
        case .boss:
            if noise(x, y, 9) > 0.9 { return RGB(0.95, 0.40, 0.10) }              // embers in the cracks
            return pick([RGB(0.20, 0.08, 0.07), RGB(0.16, 0.06, 0.05), RGB(0.25, 0.10, 0.08)])
        case .trap:
            if noise(x, y, 3) > 0.9 { return RGB(0.10, 0.10, 0.10) }              // cracks
            return pick([RGB(0.36, 0.33, 0.30), RGB(0.32, 0.29, 0.26)])
        }
    }

    // Tiny pixel sprites — one character per pixel, "." see-through.
    private static let spritePalette: [Swift.Character: RGB] = [
        "Y": RGB(1.0, 0.84, 0.2), "O": RGB(0.45, 0.30, 0.06), "B": RGB(0.45, 0.27, 0.12), "W": RGB(0.92, 0.90, 0.85),
        "G": RGB(0.66, 0.66, 0.70), "D": RGB(0.20, 0.20, 0.24), "R": RGB(0.72, 0.16, 0.16), "N": RGB(0.20, 0.55, 0.25),
        "U": RGB(0.25, 0.45, 0.80), "K": RGB(0.07, 0.07, 0.07), "F": RGB(1.0, 0.60, 0.15), "C": RGB(0.3, 0.9, 0.9),
        "P": RGB(0.75, 0.45, 1.0), "A": RGB(1.0, 0.9, 0.2),
    ]
    private static func sprite(for t: Terrain) -> [String]? {
        switch t {
        case .treasure: return ["..YY..", ".YOOY.", "BBBBBB", "BYBBYB", "BBBBBB"]
        case .shrine:   return ["..F...", "..W...", "GGGGGG", ".GGGG.", ".G..G."]
        case .armoury:  return ["DDDDDD", ".DDDDD", "..DD..", ".DDDD."]
        case .library:  return ["RUNBRU", "RUNBRU", "RUNBRU", "KKKKKK"]
        case .boss:     return [".WWWW.", "WKWWKW", "WWWWWW", ".WKWK.", "..WW.."]
        case .shop:     return ["..KK..", ".YYYY.", "YYOYYY", "YYYYYY", ".YYYY."]
        case .entrance: return [".GGGG.", "GKKKKG", "GKKKKG", "GKKKKG"]
        case .prison:   return ["D.D.D.", "D.D.D.", "D.D.D.", "D.D.D."]
        case .trap:     return ["......", "G..G..", "GG.GG.", "GGGGGG"]
        default:        return nil
        }
    }

    private func outlined(_ ctx: inout GraphicsContext, _ s: String, at p: CGPoint, size: CGFloat, color: Color, anchor: UnitPoint = .center) {
        let font = Font.system(size: size, weight: .bold, design: .monospaced)
        let shadow = ctx.resolve(Text(s).font(font).foregroundColor(.black))
        for dx in [-1.3, 0, 1.3] as [CGFloat] {
            for dy in [-1.3, 0, 1.3] as [CGFloat] where dx != 0 || dy != 0 {
                ctx.draw(shadow, at: CGPoint(x: p.x + dx, y: p.y + dy), anchor: anchor)
            }
        }
        ctx.draw(ctx.resolve(Text(s).font(font).foregroundColor(color)), at: p, anchor: anchor)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ l: Layout) {
        let P = Self.pixelsPerCell
        let pxW = l.cellW / CGFloat(P), pxH = l.cellH / CGFloat(P)
        let cols = l.cols, rows = l.rows
        let green = Color(red: 0.0, green: 1.0, blue: 0.4)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.05, green: 0.05, blue: 0.04)))

        // Each cell: which room (if any), which sides open onto a connected
        // neighbour (1 N, 2 E, 4 S, 8 W), and whether a passage winds through.
        var roomIndex = [Int](repeating: -1, count: cols * rows)
        var openSides = [UInt8](repeating: 0, count: cols * rows)
        var corridor = [Bool](repeating: false, count: cols * rows)
        var stubs = [UInt8](repeating: 0, count: cols * rows)   // passages into unknown rooms
        func idx(_ x: Int, _ y: Int) -> Int? {
            let cx = x - l.minX, cy = y - l.minY
            return (cx >= 0 && cy >= 0 && cx < cols && cy < rows) ? cy * cols + cx : nil
        }
        func side(_ dx: Int, _ dy: Int) -> UInt8 { dy < 0 ? 1 : (dx > 0 ? 2 : (dy > 0 ? 4 : 8)) }
        let byId = Dictionary(level.rooms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (i, r) in rooms.enumerated() { if let k = idx(r.x, r.y) { roomIndex[k] = i } }
        let visibleIds = Set(rooms.map { $0.id })
        for r in rooms {
            for (_, id) in r.exits {
                guard let o = byId[id] else { continue }
                let dx = o.x - r.x, dy = o.y - r.y
                let known = visibleIds.contains(o.id)
                if abs(dx) + abs(dy) == 1 {
                    if let a = idx(r.x, r.y) { openSides[a] |= side(dx, dy) }
                    if let b = idx(o.x, o.y) {
                        if known { openSides[b] |= side(-dx, -dy) } else { stubs[b] |= side(-dx, -dy) }
                    }
                } else if known {
                    var x = r.x, y = r.y
                    while x != o.x { x += o.x > x ? 1 : -1; if let k = idx(x, y), roomIndex[k] < 0 { corridor[k] = true } }
                    while y != o.y { y += o.y > y ? 1 : -1; if let k = idx(x, y), roomIndex[k] < 0 { corridor[k] = true } }
                }
            }
        }
        let terrains = rooms.map { Self.terrain(for: $0.typeName) }
        let wall = RGB(0.05, 0.04, 0.04)
        func neighbourTerrain(_ cx: Int, _ cy: Int) -> Terrain? {
            guard cx >= 0, cy >= 0, cx < cols, cy < rows else { return nil }
            let ri = roomIndex[cy * cols + cx]
            return ri >= 0 ? terrains[ri] : nil
        }
        func pixel(_ gx: Int, _ gy: Int) -> RGB {
            let cx = gx / P, cy = gy / P, lx = gx % P, ly = gy % P
            let k = cy * cols + cx
            let ri = roomIndex[k]
            if ri >= 0 {
                let open = openSides[k]
                // Walls round each room, except where a passage joins a neighbour.
                if ly == 0 && open & 1 == 0 { return wall }
                if lx == P - 1 && open & 2 == 0 { return wall }
                if ly == P - 1 && open & 4 == 0 { return wall }
                if lx == 0 && open & 8 == 0 { return wall }
                // Near an open side the neighbour's ground frays in, so the
                // rooms run together as one landscape.
                var t = terrains[ri]
                let n = Self.noise(gx, gy, 4)
                if open & 1 != 0, ly < 3, n < 0.5 - Double(ly) * 0.15, let nb = neighbourTerrain(cx, cy - 1) { t = nb }
                else if open & 2 != 0, lx > P - 4, n < 0.5 - Double(P - 1 - lx) * 0.15, let nb = neighbourTerrain(cx + 1, cy) { t = nb }
                else if open & 4 != 0, ly > P - 4, n < 0.5 - Double(P - 1 - ly) * 0.15, let nb = neighbourTerrain(cx, cy + 1) { t = nb }
                else if open & 8 != 0, lx < 3, n < 0.5 - Double(lx) * 0.15, let nb = neighbourTerrain(cx - 1, cy) { t = nb }
                let c = Self.texture(t, gx, gy)
                return rooms[ri].visited ? c : c.scaled(0.72)
            }
            // A passage leading off into rock you haven't charted — a dirt
            // track that fades into the dark.
            let stub = stubs[k]
            if stub != 0 {
                let half = P / 2
                let across = lx >= 4 && lx < P - 4, down = ly >= 4 && ly < P - 4
                let n = Self.noise(gx, gy, 6)
                if stub & 1 != 0, across, ly < half, n < 1 - Double(ly) / Double(half) { return Self.texture(.corridor, gx, gy) }
                if stub & 4 != 0, across, ly >= half, n < 1 - Double(P - 1 - ly) / Double(half) { return Self.texture(.corridor, gx, gy) }
                if stub & 8 != 0, down, lx < half, n < 1 - Double(lx) / Double(half) { return Self.texture(.corridor, gx, gy) }
                if stub & 2 != 0, down, lx >= half, n < 1 - Double(P - 1 - lx) / Double(half) { return Self.texture(.corridor, gx, gy) }
            }
            if corridor[k] && ((lx >= 4 && lx < P - 4) || (ly >= 4 && ly < P - 4)) { return Self.texture(.corridor, gx, gy) }
            if Self.noise(cx + l.minX, cy + l.minY, 7) < 0.12 && lx > 1 && lx < P - 2 && ly > 1 && ly < P - 2 {
                return Self.texture(.water, gx, gy)
            }
            return Self.texture(.bedrock, gx, gy)
        }

        // The landscape, a row at a time (runs of one colour drawn together).
        let width = cols * P, height = rows * P
        let ox = l.originX, oy = l.originY
        for gy in 0..<height {
            var start = 0
            var run = pixel(0, gy)
            for gx in 1...width {
                let c = gx < width ? pixel(gx, gy) : RGB(-1, -1, -1)
                if c != run {
                    ctx.fill(Path(CGRect(x: ox + CGFloat(start) * pxW, y: oy + CGFloat(gy) * pxH,
                                         width: CGFloat(gx - start) * pxW + 0.5, height: pxH + 0.5)), with: .color(run.color))
                    start = gx
                    run = c
                }
            }
        }

        // Pixel sprites and markers.
        func drawSprite(_ art: [String], cellX x: Int, cellY y: Int, offsetX: Int? = nil, offsetY: Int? = nil) {
            let o = l.origin(x, y)
            let w = art.map { $0.count }.max() ?? 0
            let sx = offsetX ?? (P - w) / 2, sy = offsetY ?? (P - art.count) / 2 + 1
            for (j, row) in art.enumerated() {
                for (i, ch) in row.enumerated() {
                    guard let c = Self.spritePalette[ch] else { continue }
                    ctx.fill(Path(CGRect(x: o.x + CGFloat(sx + i) * pxW, y: o.y + CGFloat(sy + j) * pxH,
                                         width: pxW + 0.5, height: pxH + 0.5)), with: .color(c.color))
                }
            }
        }
        for (i, r) in rooms.enumerated() {
            if let art = Self.sprite(for: terrains[i]) { drawSprite(art, cellX: r.x, cellY: r.y) }
            if r.verticalTo != nil {
                drawSprite(r.verticalDirection == "down" ? ["CCC", ".C."] : [".C.", "CCC"], cellX: r.x, cellY: r.y, offsetX: P - 4, offsetY: 1)
            }
            if r.teleportTo != nil { drawSprite(["P.P", ".P.", "P.P"], cellX: r.x, cellY: r.y, offsetX: 1, offsetY: 1) }
            if r.danger { drawSprite(["R", "R", ".", "R"], cellX: r.x, cellY: r.y, offsetX: 1, offsetY: P - 5) }
            if level.currentRoomId == r.id {
                let o = l.origin(r.x, r.y)
                ctx.stroke(Path(CGRect(x: o.x + pxW * 0.5, y: o.y + pxH * 0.5, width: l.cellW - pxW, height: l.cellH - pxH)),
                           with: .color(.yellow), lineWidth: pxH * 0.7)
                outlined(&ctx, "@", at: CGPoint(x: o.x + l.cellW / 2, y: o.y + l.cellH - pxH * 2.4), size: pxH * 2.6, color: .yellow)
            }
        }

        // Names across the top of each room.
        for r in rooms {
            let o = l.origin(r.x, r.y)
            let name = r.name.count > 12 ? String(r.name.prefix(11)) + "…" : r.name
            outlined(&ctx, name, at: CGPoint(x: o.x + l.cellW / 2, y: o.y + pxH * 1.9), size: 6.5 * zoom, color: r.visited ? green : green.opacity(0.6))
        }

        // Info panels in clear rock beside the rooms — the spot touching the
        // most rooms wins — with a leader line to the room they describe.
        let occupied = Set(rooms.map { "\($0.x),\($0.y)" })
        var used = Set<String>()
        for r in rooms {
            var lines: [String] = []
            if let m = r.merchantName { lines.append("Shop: \(m)") }
            if let g = r.gymName { lines.append("Gym: \(g)") }
            if let n = r.npcName, n != r.merchantName { lines.append(n) }
            if r.danger { lines.append("Danger!") }
            if r.treasureLeft { lines.append("Treasure") }
            guard !lines.isEmpty else { continue }
            var best: (x: Int, y: Int, score: Int)?
            for dx in -1...1 {
                for dy in -1...1 where dx != 0 || dy != 0 {
                    let x = r.x + dx, y = r.y + dy, key = "\(x),\(y)"
                    guard x >= l.minX, y >= l.minY, x < l.minX + l.cols, y < l.minY + l.rows else { continue }
                    guard !occupied.contains(key), !used.contains(key) else { continue }
                    var score = 0
                    for ex in -1...1 { for ey in -1...1 where ex != 0 || ey != 0 { if occupied.contains("\(x + ex),\(y + ey)") { score += 1 } } }
                    if best == nil || score > best!.score { best = (x, y, score) }
                }
            }
            guard let spot = best else { continue }
            used.insert("\(spot.x),\(spot.y)")
            let pc = l.centre(spot.x, spot.y)
            let lineH = 8.5 * zoom
            let w = l.cellW * 0.98, h = CGFloat(lines.count) * lineH + 8 * zoom
            let rect = CGRect(x: pc.x - w / 2, y: pc.y - h / 2, width: w, height: h)
            var leader = Path()
            leader.move(to: pc)
            leader.addLine(to: l.centre(r.x, r.y))
            ctx.stroke(leader, with: .color(green.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ctx.fill(Path(rect), with: .color(Color.black.opacity(0.85)))
            ctx.stroke(Path(rect), with: .color(green.opacity(0.7)), lineWidth: 1)
            for (i, text) in lines.enumerated() {
                let t = text.count > 12 ? String(text.prefix(11)) + "…" : text
                ctx.draw(ctx.resolve(Text(t).font(.system(size: 6.5 * zoom, design: .monospaced)).foregroundColor(text == "Danger!" ? .red : green)),
                         at: CGPoint(x: rect.midX, y: rect.minY + 4 * zoom + lineH * (CGFloat(i) + 0.5)))
            }
        }

        outlined(&ctx, "\(level.dungeonName) — Level \(level.level) · \(showAll ? "The Whole Deep" : "The Charted Reaches")", at: CGPoint(x: l.charW * 2, y: l.lineH * 2.5), size: fontSize, color: green, anchor: .leading)
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
                    .accessibilityLabel(TerminalLine.spokenText(line.text))
                    .accessibilityHidden(line.isDecorativeArt)
                Spacer()
            }
        } else {
            Text(attributedString)
                .font(.system(size: scaledSize, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(TerminalLine.spokenText(line.text))
                .accessibilityHidden(line.isDecorativeArt)
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
        if let range = line.highlightRange, range.lowerBound >= 0, range.upperBound <= line.text.count {
            let chars = result.characters
            let start = chars.index(chars.startIndex, offsetBy: range.lowerBound)
            let end = chars.index(chars.startIndex, offsetBy: range.upperBound)
            result[start..<end].foregroundColor = line.highlightColor.swiftUIColor
            result[start..<end].font = .system(size: scaledSize, design: .monospaced).bold()
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

    /// Row size comes from the Button Limit setting (compactRows), not from
    /// how many buttons this screen happens to have — so three rows are
    /// always the same height from one screen to the next.
    var compactRows: Bool? = nil
    /// Mac: the pointer entering/leaving a button (Return presses the hovered one).
    var onHover: ((Int, Bool) -> Void)? = nil
    /// The height kept for the grid; rows shrink to fit it.
    var maxGridHeight: CGFloat? = nil
    private var isCompact: Bool { compactRows ?? (options.count > 6) }
    private var baseButtonHeight: CGFloat { isCompact ? max(36, 32 * scale) * macControlScale : max(44, 38 * scale) * macControlScale }
    /// Rows the grid lays out: regular buttons, a spacer, the nav cell and its padding.
    private var gridRowCount: Int {
        let regular = regularIndices.count
        var cells = regular + (needsTrailingSpacer ? 1 : 0)
        if !compactIndices.isEmpty { cells = regular <= 1 ? 4 : cells + (regular % 2 == 0 ? 2 : 1) }
        return max(1, (cells + 1) / 2)
    }
    /// Buttons shrink (a little) rather than spill out of the space kept for
    /// them — six buttons plus the ?/Back cell make a fourth row.
    private var buttonMinHeight: CGFloat {
        guard let maxH = maxGridHeight, maxH > 0 else { return baseButtonHeight }
        let rows = CGFloat(gridRowCount)
        let spacing: CGFloat = isCompact ? 4 : 6
        return max(28, min(baseButtonHeight, (maxH - (rows - 1) * spacing) / rows))
    }
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
        // Never let the compact nav cell (?, <<, >>, < Back...) share the
        // ONLY row on screen — with 0 or 1 regular buttons, the grid would
        // otherwise be a single row with the nav cell crammed in next to
        // the lone action button (or standing alone). Force a second row
        // instead, so the nav cell always settles into a bottom-right
        // corner below at least one row of real content, not sharing a
        // row with it. 2+ regular buttons already produce 2+ rows on their
        // own (see the plain "push to right column" logic below), so this
        // only kicks in for the single-row case.
        let forceSecondRow = !compact.isEmpty && regular.count <= 1

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
                        .frame(height: buttonMinHeight)
                }
                regularButton(option: option, index: index, fallbackDisplayNumber: displayPos + 1)
            }

            // Compact nav cell (↩ ⏮ ? ⏭ ↪) — single cell, bottom right
            if !compact.isEmpty {
                if forceSecondRow {
                    // Pad with empty cells so the nav cell lands as the 4th
                    // cell overall (i.e. bottom-right of a forced 2-row,
                    // 2-column layout) — contiguous with the lone button's
                    // row rather than leaving a blank row above it.
                    ForEach(0..<max(0, 3 - regular.count), id: \.self) { _ in
                        Color.clear.frame(height: buttonMinHeight)
                    }
                } else if regular.count % 2 == 0 {
                    // Push to right column if regular count is even
                    Color.clear.frame(height: buttonMinHeight)
                }
                compactNavCell(indices: compact)
            }
        }
        .onAppear {
            if options.contains(where: { $0.isAlert }) && !GameEngine.animationsReduced {
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
                    .font(.system(size: 11 * scale * macControlScale, design: .monospaced))
                    .foregroundColor(buttonNumberColor(option))

                styledOptionText(option, index: index)
                    .font(.system(size: 13 * scale * macControlScale, design: .monospaced))
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
            // Fixed height — a row never grows (text shrinks to fit instead).
            .frame(height: buttonMinHeight)
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
        #if os(macOS)
        .onHover { inside in onHover?(index + 1, inside) }
        #endif
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
                            Text(option.text == "?" ? MenuOption.helpGlyph : option.text)
                                .accessibilityLabel(MenuOption.spokenLabel(option.text))
                                // Longer labels ("< Leave Game") wrap neatly onto two
                                // centred lines, shrinking only a little if still needed.
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.75)
                                .font(.system(size: compactFontSize, design: .monospaced))
                                .fontWeight(option.text == "< Leave Game" ? .light : (option.isDefault || option.isAlert ? .semibold : .regular))
                                .foregroundColor(option.text == "< Leave Game" ? terminalDimGreen.opacity(0.7) : terminalDimGreen)
                                .frame(maxWidth: .infinity, minHeight: buttonMinHeight, maxHeight: buttonMinHeight)
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
                            .frame(maxWidth: .infinity, minHeight: buttonMinHeight, maxHeight: buttonMinHeight)
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
        .frame(height: buttonMinHeight)
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
    let uncertainGrey = Color(red: 0.55, green: 0.55, blue: 0.55)   // 6:1 on black (was 3:1)
    let securedAmber = Color(red: 0.8, green: 0.6, blue: 0.1)

    private let npcCyan = Color(red: 0.2, green: 0.7, blue: 0.9)
    private let teleportPurple = Color(red: 0.65, green: 0.4, blue: 0.9)
    private let torchBlue = Color(red: 0.3, green: 0.55, blue: 0.95)
    private let searchAmber = Color(red: 0.8, green: 0.6, blue: 0.2)
    private let listenAmber = Color(red: 0.8, green: 0.6, blue: 0.2)

    private var effectiveCellWidth: CGFloat { cellWidth ?? max(80, 80 * scale) * macControlScale }

    @ViewBuilder
    private func cornerIconButton(systemName: String, color: Color, action: (() -> Void)?) -> some View {
        if let action = action {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 16 * scale))
                    .foregroundColor(color)
                    .frame(width: effectiveCellWidth, height: max(44, 34 * scale) * macControlScale)
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
            .accessibilityLabel(iconLabel(systemName))
        } else {
            Color.clear.frame(width: effectiveCellWidth, height: max(44, 34 * scale) * macControlScale)
                .accessibilityHidden(true)
        }
    }

    /// What VoiceOver says for each corner icon.
    private func iconLabel(_ systemName: String) -> String {
        switch systemName {
        case "target": return "Teleport pad"
        case "sparkle.magnifyingglass": return "Search the room"
        case "ear": return "Listen"
        case "flame": return "Light torch"
        case "flame.fill": return "Douse torch"
        case "scroll": return "Talk to \(npcLabel ?? "someone here")"
        default: return systemName
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
                            .frame(width: effectiveCellWidth, height: max(44, 34 * scale) * macControlScale)
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
                    Color.clear.frame(width: effectiveCellWidth, height: max(44, 34 * scale) * macControlScale)
                }
            }
        }
    }

    /// "Go north", "North, locked", "North, can't see in the dark"...
    static func spokenDirection(_ dir: Direction, dark: Bool, locked: Bool, open: Bool) -> String {
        let names = ["N": "north", "S": "south", "E": "east", "W": "west", "U": "up", "D": "down",
                     "NE": "north-east", "NW": "north-west", "SE": "south-east", "SW": "south-west"]
        let name = names[dir.rawValue.uppercased()] ?? dir.rawValue.lowercased()
        if dark { return "\(name.capitalized), can't see in the dark" }
        if locked { return "\(name.capitalized), locked" }
        return open ? "Go \(name)" : "\(name.capitalized), no way through"
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
                    .accessibilityLabel(Self.spokenDirection(dir, dark: isDark, locked: isSecured, open: enabled))
                    .font(.system(size: 11 * scale * macControlScale, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                    .frame(width: effectiveCellWidth, height: max(44, 34 * scale) * macControlScale)
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
                        .accessibilityHidden(true)
                        .font(.system(size: 10 * scale))
                        .offset(x: 25 * scale, y: -10 * scale)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(isDark ? "\(dir.rawValue), too dark to see" : (isSecured ? "\(dir.rawValue), barred" : (enabled ? "Go \(dir.rawValue)" : "\(dir.rawValue), no way through")))
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
        // NSImageView's intrinsic size is the GIF's full pixel size, held
        // at required priority — that pushed the view far past the frame
        // SwiftUI gave it (the splash dragon spilled over the title).
        for axis in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            imageView.setContentCompressionResistancePriority(.defaultLow, for: axis)
            imageView.setContentHuggingPriority(.defaultLow, for: axis)
        }
        container.wantsLayer = true
        container.layer?.masksToBounds = true
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
