//
//  EndgameViews.swift — the end of an adventure: fireworks, the printable
//  certificate (and a look at any PDF before it's kept), and the shelf
//  where finished adventures' certificates are kept (Settings > Certificates).
//

import SwiftUI
#if canImport(PDFKit) && !os(tvOS)
import PDFKit
#endif

// MARK: - Fireworks

/// Bursts of sparks over everything for a few seconds — none at all with
/// Reduce Motion on. Never takes a tap.
struct FireworksView: View {
    let start: Date
    let until: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let now = timeline.date
                    Self.draw(&ctx, size: size, t: now.timeIntervalSince(start),
                              fade: min(1, max(0, until.timeIntervalSince(now))))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private static let colors: [Color] = [.yellow, .red, .orange, .pink, .cyan, .green, .white,
                                           Color(red: 0.86, green: 0.69, blue: 0.24)]

    /// A fixed "random" number in 0..<1 for n, so a burst stays put frame to frame.
    private static func rand(_ n: Int) -> Double {
        var x = UInt64(bitPattern: Int64(n)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 32
        return Double(x % 100_000) / 100_000
    }

    private static func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double, fade: Double) {
        let every = 0.5, life = 1.8
        guard t >= 0 else { return }
        let last = Int(t / every)
        let first = max(0, Int((t - life - 0.3) / every))
        let reach = Double(min(size.width, size.height))
        for b in first...max(first, last) {
            let born = Double(b) * every + 0.3 * rand(b &* 7)
            let age = t - born
            guard age >= 0, age < life else { continue }
            let cx = Double(size.width) * (0.12 + 0.76 * rand(b &* 3 &+ 1))
            let cy = Double(size.height) * (0.1 + 0.45 * rand(b &* 5 &+ 2))
            let color = colors[Int(rand(b &* 11 &+ 3) * Double(colors.count)) % colors.count]
            let speed = reach * (0.18 + 0.14 * rand(b &* 13 &+ 4))
            let alpha = (1 - age / life) * fade
            let spread = speed * (1 - exp(-age * 2.4))
            let drop = 0.12 * reach * age * age
            let dot = 1.6 + 1.8 * (1 - age / life)
            for p in 0..<30 {
                let angle = Double(p) / 30 * 2 * Double.pi + 0.2 * rand(b &* 17 &+ p)
                let x = cx + cos(angle) * spread
                let y = cy + sin(angle) * spread + drop
                ctx.fill(Path(ellipseIn: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2)),
                         with: .color(color.opacity(alpha)))
            }
            if age < 0.18 {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14)),
                         with: .color(.white.opacity((0.18 - age) / 0.18 * fade)))
            }
        }
    }
}

// MARK: - Certificates kept

/// A finished adventure's certificate, as kept on disk.
struct SavedCertificate: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let title: String
    let heroes: [[String]]      // [name, detail]
    let quest: String
    let village: String?
    let stats: [[String]]       // [label, value]
    let levels: [AtlasLevel]
    let date: String

    init(_ c: GameEngine.EndgameCertificate) {
        id = UUID()
        savedAt = Date()
        title = c.title
        heroes = c.heroes.map { [$0.name, $0.detail] }
        quest = c.quest
        village = c.village
        stats = c.stats.map { [$0.0, $0.1] }
        levels = c.levels
        date = c.date
    }

    var certificate: GameEngine.EndgameCertificate {
        GameEngine.EndgameCertificate(title: title,
                                      heroes: heroes.map { (name: $0.first ?? "", detail: $0.count > 1 ? $0[1] : "") },
                                      quest: quest, village: village,
                                      stats: stats.map { ($0.first ?? "", $0.count > 1 ? $0[1] : "") },
                                      levels: levels, date: date, preview: false)
    }

    /// "Ada, Wren & Pip" — short enough for a button.
    var heroNames: String {
        let names = heroes.compactMap { $0.first?.split(separator: " ").first.map(String.init) }
        guard names.count > 1 else { return names.first ?? "Heroes" }
        return names.dropLast().joined(separator: ", ") + " & " + names.last!
    }
}

/// The certificate shelf: Documents/Certificates, one file each.
enum CertificateStore {
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Certificates")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ c: GameEngine.EndgameCertificate) {
        let saved = SavedCertificate(c)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(saved) else { return }
        try? data.write(to: directory.appendingPathComponent("\(saved.id.uuidString).json"))
    }

    /// Newest first.
    static func list() -> [SavedCertificate] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(SavedCertificate.self, from: Data(contentsOf: $0)) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id.uuidString).json"))
    }
}

// MARK: - PDFs

/// A PDF waiting in the preview sheet, before it's saved or printed.
struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let data: Data
    let name: String
    let title: String
}

/// The illustrated certificate as US-Letter PDF pages: the certificate
/// itself, in the chosen style, then the maps of the journey, two a page.
enum CertificatePDF {
    static let page = CGSize(width: 612, height: 792)

    @available(iOS 16, macOS 13, tvOS 16, *)
    @MainActor
    static func illustrated(_ cert: GameEngine.EndgameCertificate, style: Int) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var box = CGRect(origin: .zero, size: page)
        guard let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        func addPage<V: View>(_ view: V) {
            let renderer = ImageRenderer(content: view.frame(width: page.width, height: page.height))
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        addPage(CertificateFrontPage(cert: cert, style: style))
        // Each map as big as half a page allows: measured once at a known size
        // (the picture scales with its font size).
        let maps: [(AtlasLevel, CGFloat)] = cert.levels.map { level in
            var natural = CGSize(width: 1, height: 1)
            ImageRenderer(content: PictureMapView(level: level, fontSize: 10, showAll: false)).render { size, _ in natural = size }
            let fit = min((page.width - 110) / max(1, natural.width), (page.height / 2 - 100) / max(1, natural.height), 2.2)
            return (level, 10 * fit)
        }
        var i = 0
        while i < maps.count {
            addPage(CertificateMapsPage(style: style, maps: Array(maps[i..<min(i + 2, maps.count)])))
            i += 2
        }
        pdf.closePDF()
        return data as Data
    }
}

private struct CertificateFrontPage: View {
    let cert: GameEngine.EndgameCertificate
    let style: Int

    var body: some View {
        let p = CertificateView.palette(style)
        let heroSize: CGFloat = cert.heroes.count > 4 ? 18 : 24
        ZStack {
            p.bg
            RoundedRectangle(cornerRadius: 16).stroke(p.border, lineWidth: 5).padding(14)
            RoundedRectangle(cornerRadius: 12).stroke(p.border.opacity(0.5), lineWidth: 1.2).padding(24)
            VStack(spacing: 13) {
                Text("✦  ✦  ✦").font(.system(size: 16, design: .serif)).foregroundColor(p.accent)
                Text(cert.title).font(.system(size: 34, weight: .bold, design: .serif)).foregroundColor(p.ink)
                Text("This is to certify that").font(.system(size: 15, design: .serif).italic()).foregroundColor(p.ink.opacity(0.85))
                VStack(spacing: 7) {
                    ForEach(Array(cert.heroes.enumerated()), id: \.offset) { _, hero in
                        VStack(spacing: 1) {
                            Text(hero.name).font(.system(size: heroSize, weight: .heavy, design: .serif)).foregroundColor(p.accent)
                            Text(hero.detail).font(.system(size: 12, design: .serif)).foregroundColor(p.ink.opacity(0.8))
                        }
                    }
                }
                Text(cert.quest).font(.system(size: 15, design: .serif)).foregroundColor(p.ink)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
                Rectangle().fill(p.border).frame(width: 260, height: 2)
                VStack(spacing: 5) {
                    ForEach(Array(cert.stats.enumerated()), id: \.offset) { _, stat in
                        HStack {
                            Text(stat.0).foregroundColor(p.ink.opacity(0.85))
                            Spacer()
                            Text(stat.1).foregroundColor(p.accent).bold()
                        }
                        .font(.system(size: 14, design: .serif))
                    }
                }
                .frame(width: 320)
                if !cert.levels.isEmpty {
                    Text("The maps of the journey follow.").font(.system(size: 12, design: .serif).italic()).foregroundColor(p.ink.opacity(0.7))
                }
                Spacer(minLength: 0)
                Text(cert.date).font(.system(size: 13, design: .serif).italic()).foregroundColor(p.ink.opacity(0.85))
                HStack(spacing: 50) {
                    CertificateSignature(who: "The Dungeon Master", p: p)
                    CertificateSignature(who: cert.village.map { "The Elder of \($0)" } ?? "The Bards of the Realm", p: p)
                }
                if cert.preview {
                    Text("(a preview — not a real adventure)").font(.system(size: 11, design: .serif).italic()).foregroundColor(p.ink.opacity(0.6))
                }
            }
            .padding(.vertical, 50)
            .padding(.horizontal, 44)
        }
    }
}

private struct CertificateSignature: View {
    let who: String
    let p: CertificateView.Palette

    var body: some View {
        VStack(spacing: 3) {
            Text("~ signed ~").font(.system(size: 15, design: .serif).italic()).foregroundColor(p.accent)
            Rectangle().fill(p.ink.opacity(0.6)).frame(width: 150, height: 1)
            Text(who).font(.system(size: 11, design: .serif)).foregroundColor(p.ink.opacity(0.85))
        }
    }
}

private struct CertificateMapsPage: View {
    let style: Int
    let maps: [(AtlasLevel, CGFloat)]

    var body: some View {
        let p = CertificateView.palette(style)
        ZStack {
            p.bg
            RoundedRectangle(cornerRadius: 16).stroke(p.border, lineWidth: 5).padding(14)
            VStack(spacing: 16) {
                Text("The Journey").font(.system(size: 22, weight: .bold, design: .serif)).foregroundColor(p.ink)
                ForEach(Array(maps.enumerated()), id: \.offset) { _, map in
                    VStack(spacing: 6) {
                        Text("Level \(map.0.level)").font(.system(size: 15, weight: .semibold, design: .serif)).foregroundColor(p.accent)
                        PictureMapView(level: map.0, fontSize: map.1, showAll: false)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(p.border.opacity(0.7), lineWidth: 1))
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 36)
        }
    }
}

#if canImport(PDFKit) && !os(tvOS)
/// A PDF before it's kept: look it over, then Save… or Print (on a Mac,
/// or open it in Preview).
struct PDFPreviewSheet: View {
    let item: PDFPreviewItem
    let onSave: () -> Void
    let onPrint: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(item.title).font(.headline)
                Spacer()
                #if os(macOS)
                Button("Open in Preview", action: openInPreview)
                #endif
                Button("Print", action: onPrint)
                Button("Save…", action: onSave).keyboardShortcut(.defaultAction)
                Button("Close", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            PDFKitView(data: item.data)
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 780)
        #endif
    }

    #if os(macOS)
    private func openInPreview() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.name + ".pdf")
        try? item.data.write(to: url)
        NSWorkspace.shared.open(url)
    }
    #endif
}

#if os(iOS)
private struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
#else
private struct PDFKitView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {}
}
#endif
#endif
