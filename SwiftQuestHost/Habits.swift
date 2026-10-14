import SwiftUI
import UserNotifications

/// Daily study tracking: activity per day, streaks, a daily goal and an optional reminder.
@MainActor
final class HabitStore: ObservableObject {
    static let shared = HabitStore()

    @Published private(set) var counts: [String: Int]
    @Published var dailyGoal: Int { didSet { UserDefaults.standard.set(dailyGoal, forKey: Storage.key("habitGoal")) } }
    @Published var reminderEnabled: Bool { didSet { UserDefaults.standard.set(reminderEnabled, forKey: "habitReminderOn") } }
    @Published var reminderMinutes: Int { didSet { UserDefaults.standard.set(reminderMinutes, forKey: "habitReminderMinutes") } }
    @Published var notificationsDenied = false

    private var countsKey: String { Storage.key("habitCounts") }

    private init() {
        counts = (UserDefaults.standard.dictionary(forKey: Storage.key("habitCounts")) as? [String: Int]) ?? [:]
        let goal = UserDefaults.standard.integer(forKey: Storage.key("habitGoal"))
        dailyGoal = goal > 0 ? goal : 3
        reminderEnabled = UserDefaults.standard.bool(forKey: "habitReminderOn")
        let minutes = UserDefaults.standard.object(forKey: "habitReminderMinutes") as? Int
        reminderMinutes = minutes ?? 19 * 60
    }

    /// Reloads the current profile's habits (called when the profile changes).
    func reload() {
        counts = (UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int]) ?? [:]
        let goal = UserDefaults.standard.integer(forKey: Storage.key("habitGoal"))
        dailyGoal = goal > 0 ? goal : 3
    }

    // MARK: Days

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { formatter.string(from: date) }

    /// Call whenever the learner does something meaningful (answers, finishes a lesson, reviews a card…).
    func recordActivity() {
        counts[Self.key(Date()), default: 0] += 1
        UserDefaults.standard.set(counts, forKey: countsKey)
    }

    var todayCount: Int { counts[Self.key(Date())] ?? 0 }
    var goalMetToday: Bool { todayCount >= dailyGoal }

    /// Consecutive active days ending today (or yesterday, so the streak is not lost before you study today).
    var streak: Int {
        let cal = Calendar.current
        var day = Date()
        if (counts[Self.key(day)] ?? 0) == 0 {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while (counts[Self.key(day)] ?? 0) > 0 {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    func lastDays(_ n: Int) -> [(date: Date, count: Int)] {
        let cal = Calendar.current
        return (0..<n).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (d, counts[Self.key(d)] ?? 0)
        }
    }

    // MARK: Reminder

    func updateReminder(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["swiftquest.daily"])
        guard reminderEnabled else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in self.notificationsDenied = !granted }
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            var comps = DateComponents()
            comps.hour = self.reminderMinutes / 60
            comps.minute = self.reminderMinutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: "swiftquest.daily", content: content, trigger: trigger))
        }
    }
}

struct TodayCard: View {
    @ObservedObject var habits = HabitStore.shared
    @EnvironmentObject var loc: Localizer

    var body: some View {
        GroupBox {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 10)
                    Circle().trim(from: 0, to: min(1, Double(habits.todayCount) / Double(max(1, habits.dailyGoal))))
                        .stroke(habits.goalMetToday ? Color.green : Color.accentColor,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(habits.todayCount)/\(habits.dailyGoal)").font(.headline.monospacedDigit())
                }
                .frame(width: 84, height: 84)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(loc.t("habit.goal"))
                .accessibilityValue("\(habits.todayCount) / \(habits.dailyGoal)")
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(habits.streak) \(loc.t("habit.streak.days"))", systemImage: "flame.fill")
                        .font(.headline).foregroundStyle(habits.streak > 0 ? .orange : .secondary)
                    Text(habits.goalMetToday ? loc.t("habit.goal.met") : loc.t("habit.goal"))
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(habits.lastDays(7), id: \.date) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day.count == 0 ? Color.secondary.opacity(0.25) : (day.count >= habits.dailyGoal ? Color.green : Color.accentColor))
                                .frame(width: 14, height: 8 + CGFloat(min(day.count, 6)) * 4)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Spacer()
            }
            .padding(6)
        }
    }
}
