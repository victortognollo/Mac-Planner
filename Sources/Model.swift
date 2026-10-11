import Foundation

enum ItemKind: String, Codable, CaseIterable {
    case task, meeting, reminder

    var label: String {
        switch self {
        case .task: return tr("Task")
        case .meeting: return tr("Meeting")
        case .reminder: return tr("Reminder")
        }
    }

    var placeholder: String {
        switch self {
        case .task: return tr("What needs to be done?")
        case .meeting: return tr("Meeting name")
        case .reminder: return tr("What to remember?")
        }
    }
}

struct PlannerItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: String          // yyyy-MM-dd
    var kind: ItemKind
    var title: String
    var time: String? = nil   // HH:mm
    var link: String? = nil
    var done = false

    var linkURL: URL? {
        guard let raw = link?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let full = raw.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) == nil ? "https://" + raw : raw
        return URL(string: full)
    }
}

struct Modules: Codable, Equatable {
    var progress = true
    var focus = true
    var priorities = true
    var habits = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        progress = try c.decodeIfPresent(Bool.self, forKey: .progress) ?? true
        focus = try c.decodeIfPresent(Bool.self, forKey: .focus) ?? true
        priorities = try c.decodeIfPresent(Bool.self, forKey: .priorities) ?? true
        habits = try c.decodeIfPresent(Bool.self, forKey: .habits) ?? true
    }
}

struct PlannerData: Codable {
    var items: [PlannerItem] = []
    var focusMinutes: [String: Int] = [:]             // day -> minutes
    var habitChecks: [String: [String: Bool]] = [:]   // day -> habit -> done
    var habits: [String] = [tr("Water"), tr("Workout"), tr("Reading")]
    var priorities: [String: [String]] = [:]          // week start -> 3 lines
    var modules = Modules()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([PlannerItem].self, forKey: .items) ?? []
        focusMinutes = try c.decodeIfPresent([String: Int].self, forKey: .focusMinutes) ?? [:]
        habitChecks = try c.decodeIfPresent([String: [String: Bool]].self, forKey: .habitChecks) ?? [:]
        habits = try c.decodeIfPresent([String].self, forKey: .habits) ?? [tr("Water"), tr("Workout"), tr("Reading")]
        priorities = try c.decodeIfPresent([String: [String]].self, forKey: .priorities) ?? [:]
        modules = try c.decodeIfPresent(Modules.self, forKey: .modules) ?? Modules()
    }
}

// MARK: - Dates (weeks start on Sunday)

enum Day {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        c.locale = Locale(identifier: "en_US")
        return c
    }()

    static var weekdays: [String] {
        Lang.isPortuguese ? ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
                          : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
    static var months: [String] {
        Lang.isPortuguese ? ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                             "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
                          : ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]
    }
    static var monthsShort: [String] {
        Lang.isPortuguese ? ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
                          : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    }

    static func key(_ d: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static var todayKey: String { key(Date()) }

    static func startOfWeek(_ d: Date) -> Date {
        let start = calendar.startOfDay(for: d)
        let weekday = calendar.component(.weekday, from: start)
        return add(-(weekday - 1), to: start)
    }

    static func add(_ days: Int, to d: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: d) ?? d
    }

    static func fireDate(day: String, time: String) -> Date? {
        let p = time.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, let d = date(day) else { return nil }
        return calendar.date(bySettingHour: p[0], minute: p[1], second: 0, of: d)
    }

    static func timeString(_ d: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func weekdayIndex(_ d: Date) -> Int { calendar.component(.weekday, from: d) - 1 }
}

// MARK: - Store

@MainActor
final class PlannerStore: ObservableObject {
    @Published private(set) var data = PlannerData()
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Planner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("planner.json")
        if let raw = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(PlannerData.self, from: raw) {
            data = decoded
        }
    }

    private func mutate(_ change: (inout PlannerData) -> Void) {
        let before = data.items
        change(&data)
        save()
        if data.items != before { Notifier.shared.reschedule(data.items) }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? enc.encode(data) { try? raw.write(to: url, options: .atomic) }
    }

    // Items: timed ones first by hour, then the rest in the order they were added.
    func items(on day: String) -> [PlannerItem] {
        data.items.enumerated()
            .filter { $0.element.date == day }
            .sorted { a, b in
                switch (a.element.time, b.element.time) {
                case let (x?, y?): return x == y ? a.offset < b.offset : x < y
                case (.some, nil): return true
                case (nil, .some): return false
                default: return a.offset < b.offset
                }
            }
            .map(\.element)
    }

    func add(_ item: PlannerItem) { mutate { $0.items.append(item) } }

    func update(_ item: PlannerItem) {
        mutate { d in if let i = d.items.firstIndex(where: { $0.id == item.id }) { d.items[i] = item } }
    }

    func toggle(_ id: UUID) {
        mutate { d in if let i = d.items.firstIndex(where: { $0.id == id }) { d.items[i].done.toggle() } }
    }

    func delete(_ id: UUID) { mutate { $0.items.removeAll { $0.id == id } } }

    func move(_ id: UUID, to day: String) {
        mutate { d in if let i = d.items.firstIndex(where: { $0.id == id }) { d.items[i].date = day } }
    }

    // Focus
    func focusMinutes(_ day: String) -> Int { data.focusMinutes[day] ?? 0 }
    func addFocus(minutes: Int, day: String) { mutate { $0.focusMinutes[day, default: 0] += minutes } }

    // Habits
    func habitDone(_ name: String, day: String) -> Bool { data.habitChecks[day]?[name] ?? false }

    func toggleHabit(_ name: String, day: String) {
        mutate { d in d.habitChecks[day, default: [:]][name] = !(d.habitChecks[day]?[name] ?? false) }
    }

    func addHabit(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !data.habits.contains(n) else { return }
        mutate { $0.habits.append(n) }
    }

    func renameHabit(at index: Int, to name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard data.habits.indices.contains(index), !n.isEmpty, !data.habits.contains(n) else { return }
        let old = data.habits[index]
        mutate { d in
            d.habits[index] = n
            for day in d.habitChecks.keys {
                if let v = d.habitChecks[day]?[old] {
                    d.habitChecks[day]?[n] = v
                    d.habitChecks[day]?[old] = nil
                }
            }
        }
    }

    func removeHabit(at index: Int) {
        guard data.habits.indices.contains(index) else { return }
        mutate { _ = $0.habits.remove(at: index) }
    }

    // Priorities, one set of three per week
    func priorities(week: String) -> [String] {
        let p = data.priorities[week] ?? []
        return (0..<3).map { $0 < p.count ? p[$0] : "" }
    }

    func setPriority(week: String, index: Int, text: String) {
        mutate { d in
            var p = (d.priorities[week] ?? []) + Array(repeating: "", count: 3)
            p = Array(p.prefix(3))
            p[index] = text
            d.priorities[week] = p
        }
    }

    func setModule(_ path: WritableKeyPath<Modules, Bool>, _ on: Bool) { mutate { $0.modules[keyPath: path] = on } }
}
