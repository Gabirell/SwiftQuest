import SwiftUI

// MARK: - Documentation links (docs*.json, verified automatically when the content is built)

struct DocLink: Codable, Identifiable, Sendable {
    let title: String
    let url: String
    var id: String { url }
}

struct DocsFile: Codable, Sendable {
    var pillars: [String: [DocLink]]?
    var lessons: [String: [DocLink]]?
}

enum DocsData {
    /// Merges every bundled docs*.json (docs.json, docsA.json, …).
    static let all: (pillars: [String: [DocLink]], lessons: [String: [DocLink]]) = {
        var pillars: [String: [DocLink]] = [:], lessons: [String: [DocLink]] = [:]
        let urls = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("docs") && $0.lastPathComponent.split(separator: ".").count == 2 }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in urls {
            guard let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(DocsFile.self, from: data) else { continue }
            for (k, v) in file.pillars ?? [:] { pillars[k, default: []] += v }
            for (k, v) in file.lessons ?? [:] { lessons[k, default: []] += v }
        }
        return (pillars, lessons)
    }()

    static func links(pillar id: Int, main: String?) -> [DocLink] {
        var list = all.pillars[String(id)] ?? []
        if let main, !list.contains(where: { $0.url == main }) {
            list.insert(DocLink(title: "Documentation", url: main), at: 0)
        }
        return list
    }

    static func links(lesson id: String) -> [DocLink] { all.lessons[id] ?? [] }
}

struct DocLinksSection: View {
    let links: [DocLink]
    @EnvironmentObject var loc: Localizer

    private func icon(_ url: String) -> String {
        if url.contains("docs.swift.org") { return "book.closed" }
        if url.contains("human-interface-guidelines") { return "paintpalette" }
        if url.contains("/tutorials/") { return "graduationcap" }
        if url.contains("app-store") || url.contains("testflight") { return "bag" }
        return "apple.logo"
    }

    var body: some View {
        if !links.isEmpty {
            GroupBox(loc.t("docs.title")) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(links) { link in
                        if let url = URL(string: link.url) {
                            Link(destination: url) {
                                Label(link.title, systemImage: icon(link.url)).multilineTextAlignment(.leading)
                            }
                            .accessibilityHint(loc.t("docs.opens"))
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
