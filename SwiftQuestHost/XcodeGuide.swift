import SwiftUI

// MARK: - Xcode Guide (xcodeGuide*.json): plain-language explanations of the Xcode interface

struct GuideStep: Codable, Sendable {
    let text: String
    let shortcut: String?
}

struct GuideArticle: Codable, Identifiable, Sendable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let steps: [GuideStep]
    let tips: [String]
    let pitfalls: [String]
    let links: [DocLink]
    let related: [Int]
}

enum GuideData {
    /// Study order of the guide categories (stable keys; display names are localized).
    static let categoryOrder = ["start", "interface", "editing", "run", "concepts", "assets", "debug", "help"]
    static func categoryRank(_ key: String) -> Int { categoryOrder.firstIndex(of: key) ?? categoryOrder.count }
    static let mapID = "window-map-interactive"
}

/// A shortcut drawn like a keyboard key.
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.secondary.opacity(0.35)))
            .accessibilityLabel(text)
    }
}

struct XcodeGuideView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var route: SwiftQuestRoute
    @State private var selected: String? = GuideData.mapID
    @State private var query = ""

    private var groups: [(String, [GuideArticle])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let matches = loc.guide.filter { a in
            q.isEmpty || a.title.localizedCaseInsensitiveContains(q) || a.summary.localizedCaseInsensitiveContains(q)
                || a.steps.contains { $0.text.localizedCaseInsensitiveContains(q) || ($0.shortcut ?? "").contains(q) }
                || a.tips.contains { $0.localizedCaseInsensitiveContains(q) }
        }
        return GuideData.categoryOrder.compactMap { cat in
            let items = matches.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField(loc.t("guide.search"), text: $query)
                    .textFieldStyle(.roundedBorder).padding(10)
                List(selection: $selected) {
                    if query.isEmpty {
                        Label(loc.t("guide.map"), systemImage: "rectangle.3.group").tag(GuideData.mapID as String?)
                    }
                    ForEach(groups, id: \.0) { cat, items in
                        Section(loc.t("guide.cat." + cat)) {
                            ForEach(items) { a in
                                HStack {
                                    Text(a.title)
                                    Spacer()
                                    if course.snapshot.guideRead.contains(a.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                                .tag(a.id as String?)
                            }
                        }
                    }
                }
            }
            .frame(width: 310)
            .onAppear { applyTarget() }
            .onChange(of: route.guideTarget) { _, _ in applyTarget() }
            Divider()
            if selected == GuideData.mapID {
                XcodeWindowMap()
            } else if let id = selected, let article = loc.guide.first(where: { $0.id == id }) {
                GuideArticleView(article: article).id(article.id)
            } else {
                Text(loc.t("guide.pick")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func applyTarget() {
        if let t = route.guideTarget { selected = t; query = ""; route.guideTarget = nil }
    }
}

struct GuideArticleView: View {
    let article: GuideArticle
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var route: SwiftQuestRoute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(loc.t("guide.cat." + article.category)).font(.subheadline).foregroundStyle(.secondary)
                Text(article.title).font(.largeTitle.bold())
                Text(markdown(article.summary)).font(.title3).foregroundStyle(.secondary)
                GroupBox(loc.t("guide.steps")) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(article.steps.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)").font(.headline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(markdown(article.steps[i].text)).textSelection(.enabled)
                                    if let sc = article.steps[i].shortcut, !sc.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(Array(sc.enumerated()), id: \.offset) { _, ch in KeyCap(text: String(ch)) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                if !article.tips.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(loc.t("guide.tips"), systemImage: "lightbulb.fill").font(.headline).foregroundStyle(.yellow)
                            ForEach(article.tips, id: \.self) { Text("• " + $0) }
                        }
                        .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !article.pitfalls.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(loc.t("guide.pitfalls"), systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(.orange)
                            ForEach(article.pitfalls, id: \.self) { Text("• " + $0) }
                        }
                        .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                DocLinksSection(links: article.links)
                let related = loc.pillars.filter { article.related.contains($0.id) }.sorted { $0.id < $1.id }
                if !related.isEmpty {
                    GroupBox(loc.t("guide.related")) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(related) { p in
                                Button("\(p.id). \(p.title)") { route.pillarTarget = p.id; route.selection = .course }.buttonStyle(.link)
                            }
                        }
                        .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Button {
                    course.toggleGuideRead(article.id)
                } label: {
                    Label(course.snapshot.guideRead.contains(article.id) ? loc.t("guide.read.done") : loc.t("guide.read.mark"),
                          systemImage: course.snapshot.guideRead.contains(article.id) ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Interactive map of the Xcode window

struct XcodeWindowMap: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var route: SwiftQuestRoute
    @State private var region: MapRegion = .navigator

    enum MapRegion: String, CaseIterable, Identifiable {
        case toolbar, tabs, navigator, editor, inspector, debug
        var id: String { rawValue }
        var number: Int { MapRegion.allCases.firstIndex(of: self)! + 1 }
        var color: Color {
            switch self {
            case .toolbar: .gray
            case .tabs: .teal
            case .navigator: .blue
            case .editor: .green
            case .inspector: .purple
            case .debug: .orange
            }
        }
        /// Guide article that explains this area in depth.
        var article: String {
            switch self {
            case .toolbar: "xcode-window-map"
            case .tabs: "open-quickly"
            case .navigator: "navigators"
            case .editor: "editor-layouts"
            case .inspector: "inspectors-libraries"
            case .debug: "build-run-stop"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("guide.map")).font(.largeTitle.bold())
                Text(loc.t("guide.map.sub")).foregroundStyle(.secondary)
                // Schematic of the Xcode window; tap an area to learn what it is.
                VStack(spacing: 4) {
                    area(.toolbar).frame(height: 40)
                    HStack(spacing: 4) {
                        area(.navigator).frame(width: 120)
                        VStack(spacing: 4) {
                            area(.tabs).frame(height: 56)
                            area(.editor)
                            area(.debug).frame(height: 70)
                        }
                        area(.inspector).frame(width: 120)
                    }
                    .frame(height: 280)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
                .frame(maxWidth: 620)
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(region.number)").font(.headline).foregroundStyle(.white)
                                .frame(width: 26, height: 26).background(region.color, in: Circle())
                            Text(loc.t("region." + region.rawValue)).font(.title3.bold())
                        }
                        Text(loc.t("region." + region.rawValue + ".desc"))
                        Button(loc.t("guide.open.article")) { route.guideTarget = region.article }.buttonStyle(.borderedProminent)
                    }
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 620)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func area(_ r: MapRegion) -> some View {
        Button { region = r } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(r.color.opacity(region == r ? 0.55 : 0.25))
                RoundedRectangle(cornerRadius: 8).stroke(r.color, lineWidth: region == r ? 3 : 1)
                VStack(spacing: 2) {
                    Text("\(r.number)").font(.headline)
                    Text(loc.t("region." + r.rawValue)).font(.caption).multilineTextAlignment(.center).padding(.horizontal, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(r.number). \(loc.t("region." + r.rawValue))")
    }
}
