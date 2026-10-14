import SwiftUI

/// Official exam domains (Certiport "App Development with Swift") mapped to the course pillars and mock exams that cover them.
struct CertDomain: Identifiable {
    let id: String
    let titleKey: String
    let objectivesKey: String
    let pillars: [Int]
    let exam: String?
}

enum Certification {
    static let domains: [CertDomain] = [
        CertDomain(id: "d1", titleKey: "cert.d1", objectivesKey: "cert.d1.obj", pillars: [26, 27, 28, 29], exam: "exam-5"),
        CertDomain(id: "d2", titleKey: "cert.d2", objectivesKey: "cert.d2.obj", pillars: [30, 31, 32], exam: "exam-6"),
        CertDomain(id: "d3", titleKey: "cert.d3", objectivesKey: "cert.d3.obj", pillars: [49, 50, 51, 52, 53], exam: "exam-7"),
        CertDomain(id: "d4", titleKey: "cert.d4", objectivesKey: "cert.d4.obj", pillars: [1, 2, 3, 4, 5, 6, 7, 8, 34, 35, 36, 37, 38, 39, 40, 41, 42], exam: "exam-8"),
        CertDomain(id: "d5", titleKey: "cert.d5", objectivesKey: "cert.d5.obj", pillars: [33], exam: "exam-9"),
        CertDomain(id: "e1", titleKey: "cert.e1", objectivesKey: "cert.e1.obj", pillars: [43, 44, 45, 46, 47, 48], exam: "exam-10"),
        CertDomain(id: "e2", titleKey: "cert.e2", objectivesKey: "cert.e2.obj", pillars: [21, 22, 54, 55, 56, 57, 58], exam: "exam-11"),
        CertDomain(id: "e3", titleKey: "cert.e3", objectivesKey: "cert.e3.obj", pillars: [68, 69, 70], exam: "exam-13"),
        CertDomain(id: "e4", titleKey: "cert.e4", objectivesKey: "cert.e4.obj", pillars: [71, 72, 73, 74, 75, 76], exam: "exam-14"),
        CertDomain(id: "e5", titleKey: "cert.e5", objectivesKey: "cert.e5.obj", pillars: [10, 19, 20, 23, 65, 66, 67], exam: nil)
    ]
}

struct CertificationView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var route: SwiftQuestRoute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.cert")).font(.largeTitle.bold())
                Text(loc.t("cert.sub")).foregroundStyle(.secondary)
                if let general = loc.exams.first(where: { $0.id == "exam-12" }) {
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(general.title, systemImage: "checkmark.seal").font(.headline)
                                Text("\(general.questions.count) \(loc.t("questions")) · \(general.timeLimitMinutes) min").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if course.snapshot.passedExams.contains(general.id) {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            }
                            Button(loc.t("cert.open.exams")) { route.selection = .exams }.buttonStyle(.borderedProminent)
                        }
                        .padding(6)
                    }
                }
                Text(loc.t("cert.official")).font(.title3.bold())
                ForEach(Certification.domains.prefix(5)) { domainCard($0) }
                Text(loc.t("cert.more")).font(.title3.bold())
                ForEach(Certification.domains.dropFirst(5)) { domainCard($0) }
                Text(loc.t("cert.disclaimer")).font(.footnote).foregroundStyle(.tertiary)
                if let url = URL(string: "https://certiport.pearsonvue.com/Certifications/Apple/App-Dev-With-Swift/Overview") {
                    Link(loc.t("cert.link"), destination: url).font(.footnote)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func readiness(_ d: CertDomain) -> Double {
        let items = loc.pillars.filter { d.pillars.contains($0.id) }
        guard !items.isEmpty else { return 0 }
        return Double(items.reduce(0) { $0 + course.progress(for: $1).percentage }) / Double(items.count) / 100
    }

    private func domainCard(_ d: CertDomain) -> some View {
        let value = readiness(d)
        let exam = d.exam.flatMap { id in loc.exams.first { $0.id == id } }
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(loc.t(d.titleKey)).font(.headline)
                    Spacer()
                    Text("\(Int((value * 100).rounded()))%").font(.headline.monospacedDigit())
                }
                ProgressView(value: value)
                Text(loc.t(d.objectivesKey)).font(.callout).foregroundStyle(.secondary)
                FlowLinks(pillars: loc.pillars.filter { d.pillars.contains($0.id) }.sorted { $0.id < $1.id }, route: route)
                if let exam {
                    HStack {
                        Label(exam.title, systemImage: "timer").font(.caption)
                        if course.snapshot.passedExams.contains(exam.id) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                        Spacer()
                        Button(loc.t("cert.open.exams")) { route.selection = .exams }.buttonStyle(.link)
                    }
                }
            }
            .padding(6)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Wrapping row of buttons that open each pillar.
private struct FlowLinks: View {
    let pillars: [Pillar]
    let route: SwiftQuestRoute

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 320), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(pillars) { p in
                Button { route.pillarTarget = p.id; route.selection = .course } label: {
                    Text("\(p.id). \(p.title)").font(.caption).lineLimit(1)
                }
                .buttonStyle(.link)
            }
        }
    }
}
