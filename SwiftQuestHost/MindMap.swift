import SwiftUI

/// Visual map of the whole course: root → categories → topics, coloured by your progress.
struct MindMapView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var route: SwiftQuestRoute

    private let rowHeight: CGFloat = 46
    private let rootX: CGFloat = 90, catX: CGFloat = 300, pillarX: CGFloat = 590

    private struct Node { let id: String; let title: String; let point: CGPoint; let color: Color; let pillar: Int? }
    private struct Edge { let from: CGPoint; let to: CGPoint; let color: Color }

    private func layout() -> (nodes: [Node], edges: [Edge], size: CGSize) {
        let palette: [Color] = [.blue, .purple, .teal, .mint, .pink, .orange, .green, .cyan, .indigo]
        var nodes: [Node] = [], edges: [Edge] = []
        var row = 0
        var catPoints: [CGPoint] = []
        for (ci, cat) in (CourseData.categoryOrder + Set(loc.pillars.map(\.categoryName)).subtracting(CourseData.categoryOrder).sorted()).enumerated() {
            let items = loc.pillars.filter { $0.categoryName == cat }.sorted { $0.id < $1.id }
            guard !items.isEmpty else { continue }
            let color = palette[ci % palette.count]
            let firstRow = row
            var pillarPoints: [CGPoint] = []
            for p in items {
                let pt = CGPoint(x: pillarX, y: CGFloat(row) * rowHeight + 76)
                pillarPoints.append(pt)
                let status = course.progress(for: p).status
                let fill: Color = status == .mastered ? .green : (status == .needsReview ? .orange : (status == .inProgress ? .blue : .gray))
                nodes.append(Node(id: "p\(p.id)", title: "\(p.id). \(p.title)", point: pt, color: fill, pillar: p.id))
                row += 1
            }
            let cy = (CGFloat(firstRow) + CGFloat(row - 1)) / 2 * rowHeight + 76
            let cp = CGPoint(x: catX, y: cy)
            catPoints.append(cp)
            nodes.append(Node(id: "c\(cat)", title: loc.category(cat), point: cp, color: color, pillar: nil))
            pillarPoints.forEach { edges.append(Edge(from: cp, to: $0, color: color)) }
        }
        let ry = catPoints.isEmpty ? 76 : (catPoints.first!.y + catPoints.last!.y) / 2
        let rp = CGPoint(x: rootX, y: ry)
        nodes.append(Node(id: "root", title: "Swift", point: rp, color: .accentColor, pillar: nil))
        catPoints.forEach { edges.append(Edge(from: rp, to: $0, color: .secondary)) }
        return (nodes, edges, CGSize(width: pillarX + 260, height: CGFloat(row) * rowHeight + 110))
    }

    var body: some View {
        let (nodes, edges, size) = layout()
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for e in edges {
                        var path = Path()
                        path.move(to: e.from)
                        let mid = (e.from.x + e.to.x) / 2
                        path.addCurve(to: e.to, control1: CGPoint(x: mid, y: e.from.y), control2: CGPoint(x: mid, y: e.to.y))
                        ctx.stroke(path, with: .color(e.color.opacity(0.5)), lineWidth: 2)
                    }
                }
                .frame(width: size.width, height: size.height)
                ForEach(nodes, id: \.id) { n in
                    Button {
                        if let pid = n.pillar { route.pillarTarget = pid; route.selection = .course }
                    } label: {
                        Text(n.title)
                            .font(.callout.weight(n.pillar == nil ? .bold : .regular))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .frame(maxWidth: n.pillar == nil ? 170 : 250)
                            .background(n.color, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(n.pillar == nil)
                    .position(n.point)
                    .accessibilityLabel(n.title)
                }
            }
            .frame(width: size.width, height: size.height)
            .padding(20)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                legend(.green, "status.mastered"); legend(.blue, "status.inprogress")
                legend(.orange, "status.review"); legend(.gray, "status.notstarted")
            }
            .padding(10).background(.bar, in: RoundedRectangle(cornerRadius: 8)).padding(12)
        }
    }

    private func legend(_ color: Color, _ key: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 9, height: 9); Text(loc.t(key)).font(.caption) }
    }
}
