import AppKit
import SwiftUI

// MARK: - Tokens (Apple: one blue for every action, hairlines instead of shadows)

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

extension Color {
    /// Text links and selected states.
    static let actionBlue = Color(nsColor: NSColor(name: nil) { a in
        a.isDark ? NSColor(srgbRed: 0.161, green: 0.592, blue: 1.0, alpha: 1)
                 : NSColor(srgbRed: 0.0, green: 0.4, blue: 0.8, alpha: 1)
    })
    /// Filled controls (today, checked boxes, primary buttons).
    static let actionFill = Color(nsColor: NSColor(name: nil) { a in
        a.isDark ? NSColor(srgbRed: 0.0, green: 0.443, blue: 0.89, alpha: 1)
                 : NSColor(srgbRed: 0.0, green: 0.4, blue: 0.8, alpha: 1)
    })
    static let hair = Color.primary.opacity(0.08)
    static let hairStrong = Color.primary.opacity(0.2)
    static let raised = Color.primary.opacity(0.05)
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var settings: AppSettings
    @State private var weekStart = Day.startOfWeek(Date())
    @State private var today = Day.todayKey

    var body: some View {
        // Below the comfortable size, lay out at that size and scale everything down to fit,
        // so text, spacing and controls shrink together and nothing gets clipped.
        GeometryReader { geo in
            let comfortable = settings.layout.comfortableSize
            let scale = max(PlannerLayout.smallestScale,
                            min(1, geo.size.width / comfortable.width, geo.size.height / comfortable.height))
            content
                .id(settings.language)
                .ignoresSafeArea()
                .frame(width: geo.size.width / scale, height: geo.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .tint(.actionBlue)
        .onAppear { calendar.show(week: weekStart) }
        .onChange(of: weekStart) { _, week in calendar.show(week: week) }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            let now = Day.todayKey
            guard now != today else { return }
            let wasShowingThisWeek = Day.key(weekStart) == Day.key(Day.startOfWeek(Day.date(today) ?? Date()))
            today = now
            if wasShowingThisWeek { weekStart = Day.startOfWeek(Date()) }
        }
    }

    @ViewBuilder private var content: some View {
        Group {
            if settings.layout == .vertical {
                VStack(spacing: 0) {
                    HeaderView(weekStart: $weekStart, compact: true)
                    Rectangle().fill(Color.hair).frame(height: 1)
                    WeekList(weekStart: weekStart, today: today)
                    Rectangle().fill(Color.hair).frame(height: 1)
                    TimerPanel(compact: true)
                }
            } else {
                VStack(spacing: 0) {
                    HeaderView(weekStart: $weekStart)
                    Rectangle().fill(Color.hair).frame(height: 1)
                    HStack(spacing: 0) {
                        WeekGrid(weekStart: weekStart, today: today)
                        Rectangle().fill(Color.hair).frame(width: 1)
                        TimerPanel().frame(width: 168)
                    }
                }
            }
        }
    }
}

/// Lets the header act as the handle to reposition the window.
struct WindowDragHandle: NSViewRepresentable {
    final class HandleView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> NSView { HandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject var store: PlannerStore
    @Binding var weekStart: Date

    private var weekEnd: Date { Day.add(6, to: weekStart) }

    private var monthTitle: String {
        let m1 = Day.calendar.component(.month, from: weekStart) - 1
        let m2 = Day.calendar.component(.month, from: weekEnd) - 1
        let year = Day.calendar.component(.year, from: weekEnd)
        return m1 == m2 ? "\(Day.months[m2]) \(year)"
                        : "\(Day.monthsShort[m1]) – \(Day.monthsShort[m2]) \(year)"
    }

    private var rangeTitle: String {
        let d1 = Day.calendar.component(.day, from: weekStart), d2 = Day.calendar.component(.day, from: weekEnd)
        let m1 = Day.calendar.component(.month, from: weekStart) - 1
        let m2 = Day.calendar.component(.month, from: weekEnd) - 1
        let short = Day.monthsShort
        if Lang.isPortuguese {
            return m1 == m2 ? "\(d1) – \(d2) \(short[m2])" : "\(d1) \(short[m1]) – \(d2) \(short[m2])"
        }
        return m1 == m2 ? "\(short[m1]) \(d1) – \(d2)" : "\(short[m1]) \(d1) – \(short[m2]) \(d2)"
    }

    private var isThisWeek: Bool { Day.key(weekStart) == Day.key(Day.startOfWeek(Date())) }

    var compact = false

    var body: some View {
        Group {
            if compact {
                // Vertical layout: title and controls on top, priorities and progress below.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        titleView
                        Spacer(minLength: 8)
                        navigation
                        actions
                    }
                    if store.data.modules.priorities { PrioritiesBar(week: Day.key(weekStart)) }
                    if store.data.modules.progress { WeekProgress(weekStart: weekStart) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 20) {
                    titleView
                    Spacer(minLength: 12)
                    if store.data.modules.priorities { PrioritiesBar(week: Day.key(weekStart)) }
                    if store.data.modules.progress { WeekProgress(weekStart: weekStart) }
                    navigation
                    actions
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
            }
        }
        .background(WindowDragHandle())
    }

    private var titleView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthTitle).font(.system(size: 14, weight: .semibold))
            Text(rangeTitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .fixedSize()
    }

    private var navigation: some View {
        HStack(spacing: 4) {
            NavButton(systemName: "chevron.left", help: tr("Previous week")) { weekStart = Day.add(-7, to: weekStart) }
            Button(tr("Today")) { weekStart = Day.startOfWeek(Date()) }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10).frame(height: 26)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.hair))
                .opacity(isThisWeek ? 0.5 : 1)
                .disabled(isThisWeek)
            NavButton(systemName: "chevron.right", help: tr("Next week")) { weekStart = Day.add(7, to: weekStart) }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            CalendarButton()
            SettingsMenu()
        }
    }
}

struct NavButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 26)
                .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.raised : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct PrioritiesBar: View {
    @EnvironmentObject var store: PlannerStore
    let week: String

    var body: some View {
        HStack(spacing: 8) {
            Text(tr("Priorities")).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize()
            ForEach(0..<3, id: \.self) { i in
                TextField([tr("1st"), tr("2nd"), tr("3rd")][i], text: Binding(
                    get: { store.priorities(week: week)[i] },
                    set: { store.setPriority(week: week, index: i, text: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12).padding(.vertical, 4)
                .frame(minWidth: 90, maxWidth: 170)
                .overlay(Capsule().strokeBorder(Color.hair))
            }
        }
    }
}

struct WeekProgress: View {
    @EnvironmentObject var store: PlannerStore
    let weekStart: Date

    var body: some View {
        let keys = Set((0..<7).map { Day.key(Day.add($0, to: weekStart)) })
        let tasks = store.data.items.filter { $0.kind == .task && keys.contains($0.date) }
        let done = tasks.filter(\.done).count
        HStack(spacing: 10) {
            Text(Lang.isPortuguese ? "\(done) de \(tasks.count) concluídas" : "\(done) of \(tasks.count) done")
                .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary).fixedSize()
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.hair)
                    Capsule().fill(Color.actionFill)
                        .frame(width: tasks.isEmpty ? 0 : g.size.width * CGFloat(done) / CGFloat(tasks.count))
                }
            }
            .frame(width: 110, height: 4)
            .animation(.easeOut(duration: 0.25), value: done)
        }
    }
}

struct SettingsMenu: View {
    @EnvironmentObject var store: PlannerStore
    @EnvironmentObject var settings: AppSettings

    private func module(_ path: WritableKeyPath<Modules, Bool>) -> Binding<Bool> {
        Binding(get: { store.data.modules[keyPath: path] }, set: { store.setModule(path, $0) })
    }

    var body: some View {
        Menu {
            Picker(tr("Position on screen"), selection: $settings.placement) {
                ForEach(WindowPlacement.allCases) { Text($0.title).tag($0) }
            }
            Picker(tr("Language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
            }
            Picker(tr("Layout"), selection: $settings.layout) {
                ForEach(PlannerLayout.allCases) { Text($0.title).tag($0) }
            }
            Picker(tr("Text size"), selection: $settings.textSize) {
                ForEach(TextSize.allCases) { Text($0.title).tag($0) }
            }
            Toggle(tr("Open at login"), isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            Divider()
            Section(tr("Show")) {
                Toggle(tr("Weekly progress"), isOn: module(\.progress))
                Toggle(tr("Focus minutes per day"), isOn: module(\.focus))
                Toggle(tr("Weekly priorities"), isOn: module(\.priorities))
                Toggle(tr("Daily habits"), isOn: module(\.habits))
            }
            Divider()
            Button(tr("About Planner")) {
                NSApp.activate()
                NSApp.orderFrontStandardAboutPanel(options: [
                    .credits: NSAttributedString(
                        string: tr("Created by Victor Tognollo\nLicense: free forever"),
                        attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
                    )
                ])
            }
            Button(tr("Quit Planner")) { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 15))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help(tr("Settings"))
    }
}

// MARK: - Week

struct WeekGrid: View {
    let weekStart: Date
    let today: String

    var body: some View {
        // Fixed equal widths, so today's wider header never steals space from the other days.
        GeometryReader { geo in
            let columnWidth = max(0, (geo.size.width - 6) / 7)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    if i > 0 { Rectangle().fill(Color.hair).frame(width: 1) }
                    DayColumn(date: Day.add(i, to: weekStart), today: today)
                        .frame(width: columnWidth)
                }
            }
        }
    }
}

/// Vertical layout: the seven days stacked as rows, scrolled to today.
struct WeekList: View {
    let weekStart: Date
    let today: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        if i > 0 { Rectangle().fill(Color.hair).frame(height: 1) }
                        let d = Day.add(i, to: weekStart)
                        DayColumn(date: d, today: today, asRow: true).id(Day.key(d))
                    }
                }
            }
            .onAppear { proxy.scrollTo(today, anchor: .top) }
            .onChange(of: weekStart) { _, _ in proxy.scrollTo(today, anchor: .top) }
        }
    }
}

/// One line in a day: either a planner item or an event synced from a calendar.
enum DayEntry: Identifiable {
    case event(CalendarEvent)
    case item(PlannerItem)

    var id: String {
        switch self {
        case .event(let e): return "e-" + e.id
        case .item(let i): return "i-" + i.id.uuidString
        }
    }

    /// All-day events first, then anything with a time by hour, then untimed tasks.
    var sortKey: (Int, String) {
        switch self {
        case .event(let e): return e.isAllDay ? (0, "") : (1, Day.timeString(e.start))
        case .item(let i): return i.time.map { (1, $0) } ?? (2, "")
        }
    }
}

struct DayColumn: View {
    @EnvironmentObject var store: PlannerStore
    @EnvironmentObject var calendar: CalendarService
    let date: Date
    let today: String
    var asRow = false

    @State private var adding = false
    @State private var editingHabits = false
    @State private var dropTarget = false
    @State private var hover = false

    private var key: String { Day.key(date) }
    private var isToday: Bool { key == today }
    private var isPast: Bool { key < today }

    private var entries: [DayEntry] {
        let all = calendar.events(on: key).map(DayEntry.event) + store.items(on: key).map(DayEntry.item)
        return all.enumerated()
            .sorted { a, b in
                let ka = a.element.sortKey, kb = b.element.sortKey
                return ka != kb ? ka < kb : a.offset < b.offset
            }
            .map(\.element)
    }

    var body: some View {
        Group {
            if asRow { rowLayout } else { columnLayout }
        }
        // View-based background: unlike a plain color it never bleeds into the header above.
        .background { Rectangle().fill((isToday || dropTarget) ? Color.actionBlue.opacity(0.08) : Color.clear) }
        .overlay { if dropTarget { Rectangle().strokeBorder(Color.actionBlue, lineWidth: 1.5) } }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .dropDestination(for: String.self) { ids, _ in
            ids.compactMap { UUID(uuidString: $0) }.forEach { store.move($0, to: key) }
            return true
        } isTargeted: { dropTarget = $0 }
    }

    /// Horizontal layout: a column with the date on top and a scrolling list.
    private var columnLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                dateLabel
                Spacer(minLength: 4)
                focusLabel
                addButton
            }
            .padding(.horizontal, 4)
            ScrollView(.vertical, showsIndicators: false) { entryList }
            if store.data.modules.habits { habits }
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Vertical layout: a row with the date on the left and the day's items beside it.
    private var rowLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            dateLabel
                .frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                entryList
                if store.data.modules.habits { habits }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            VStack(alignment: .trailing, spacing: 6) {
                addButton
                focusLabel
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entries) { entry in
                switch entry {
                case .event(let e): EventRow(event: e)
                case .item(let i): ItemRow(item: i)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Weekday and date side by side, e.g. "FRI 9".
    private var dateLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Day.weekdays[Day.weekdayIndex(date)].uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(isToday ? Color.actionBlue : Color.secondary)
            Text("\(Day.calendar.component(.day, from: date))")
                .font(.system(size: 26, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(minWidth: isToday ? 38 : nil, minHeight: 38)
                .padding(.horizontal, isToday ? 5 : 0)
                .background { if isToday { Capsule().fill(Color.actionFill) } }
        }
        .fixedSize()
        .layoutPriority(1)
        .opacity(isPast ? 0.55 : 1)
    }

    @ViewBuilder private var focusLabel: some View {
        let minutes = store.focusMinutes(key)
        if store.data.modules.focus && minutes > 0 {
            Text("\(minutes) min")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var addButton: some View {
        PlusButton(emphasized: hover || adding) { adding = true }
            .popover(isPresented: $adding, arrowEdge: .bottom) {
                ComposerView(day: key) { adding = false }
            }
    }

    private var habits: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Color.hair).frame(height: 1)
            FlowLayout(spacing: 4) {
                ForEach(store.data.habits, id: \.self) { name in
                    HabitChip(name: name, on: store.habitDone(name, day: key)) {
                        store.toggleHabit(name, day: key)
                    }
                }
                Button { editingHabits = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Color.hairStrong, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(tr("Add or edit habits"))
                .popover(isPresented: $editingHabits, arrowEdge: .top) { HabitEditor() }
            }
        }
    }
}

struct PlusButton: View {
    let emphasized: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(hover ? Color.raised : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(hover ? Color.actionBlue : Color.secondary)
        .opacity(hover || emphasized ? 1 : 0.5)
        .onHover { hover = $0 }
        .help(tr("Add item"))
    }
}

struct HabitChip: View {
    let name: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 11))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .foregroundStyle(on ? Color.white : Color.secondary)
                .background(Capsule().fill(on ? Color.actionFill : Color.clear))
                .overlay(Capsule().strokeBorder(on ? Color.clear : Color.hair))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Items

struct ItemRow: View {
    @EnvironmentObject var store: PlannerStore
    @EnvironmentObject var settings: AppSettings
    let item: PlannerItem
    @State private var hover = false
    @State private var editing = false

    /// Everything in the row scales from the title size chosen in Ajustes.
    private var size: CGFloat { settings.textSize.points }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            lead
            VStack(alignment: .leading, spacing: 2) {
                // Time comes first, above the title.
                if item.kind != .task {
                    HStack(spacing: 8) {
                        if let t = item.time { Text(t).monospacedDigit().fontWeight(.semibold) }
                        if item.kind == .meeting, let url = item.linkURL {
                            Link(tr("Join"), destination: url)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.actionBlue)
                        }
                    }
                    .font(.system(size: size - 2))
                    .foregroundStyle(.secondary)
                }
                // Double-click and drag live on the title only, so they never swallow clicks
                // meant for the check circle, the delete button or the "Entrar" link.
                Text(item.title)
                    .font(.system(size: size))
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? Color.secondary : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editing = true }
                    .draggable(item.id.uuidString)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.raised : .clear))
        // The delete button floats over the row on hover, so it takes no width from the text.
        .overlay(alignment: .topTrailing) {
            if hover {
                Button { store.delete(item.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.regularMaterial))
                        .overlay(Circle().strokeBorder(Color.hair))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(3)
                .help(tr("Delete"))
            }
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .popover(isPresented: $editing, arrowEdge: .trailing) {
            ComposerView(day: item.date, editing: item) { editing = false }
        }
        .contextMenu {
            Button(tr("Edit")) { editing = true }
            if item.kind == .task { Button(item.done ? tr("Mark as not done") : tr("Mark as done")) { store.toggle(item.id) } }
            if let d = Day.date(item.date) {
                Button(tr("Move to tomorrow")) { store.move(item.id, to: Day.key(Day.add(1, to: d))) }
            }
            Divider()
            Button(tr("Delete"), role: .destructive) { store.delete(item.id) }
        }
    }

    @ViewBuilder private var lead: some View {
        switch item.kind {
        case .task:
            Button { withAnimation(.easeOut(duration: 0.15)) { store.toggle(item.id) } } label: {
                ZStack {
                    if item.done {
                        Circle().fill(Color.actionFill)
                        Image(systemName: "checkmark").font(.system(size: size * 0.55, weight: .bold)).foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(Color.hairStrong, lineWidth: 1.5)
                    }
                }
                .frame(width: size + 2, height: size + 2)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            .help(item.done ? tr("Mark as not done") : tr("Mark as done"))
        case .meeting:
            Image(systemName: "video").font(.system(size: size - 2)).foregroundStyle(.secondary).frame(width: size + 2, height: size + 4)
        case .reminder:
            Image(systemName: "bell").font(.system(size: size - 2)).foregroundStyle(.secondary).frame(width: size + 2, height: size + 4)
        }
    }
}

// MARK: - Add / edit card

struct ComposerView: View {
    @EnvironmentObject var store: PlannerStore
    let day: String
    var editing: PlannerItem? = nil
    let close: () -> Void

    @State private var kind: ItemKind = .task
    @State private var title = ""
    @State private var time = Date()
    @State private var link = ""
    @FocusState private var titleFocused: Bool

    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var dayLabel: String {
        guard let d = Day.date(day) else { return "" }
        let m = Day.calendar.component(.month, from: d) - 1
        let weekday = Day.weekdays[Day.weekdayIndex(d)], day = Day.calendar.component(.day, from: d)
        return Lang.isPortuguese ? "\(weekday), \(day) de \(Day.months[m].lowercased())" : "\(weekday), \(Day.months[m]) \(day)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(editing == nil ? tr("New item") : tr("Edit item")).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(dayLabel).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Picker(tr("Type"), selection: $kind) {
                ForEach(ItemKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField(kind.placeholder, text: $title)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .focused($titleFocused)

            if kind != .task {
                HStack(spacing: 6) {
                    DatePicker(tr("Time"), selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .controlSize(.large)
                    if kind == .meeting {
                        TextField("Link (Meet, Zoom…)", text: $link)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                    }
                }
            }

            HStack {
                if let e = editing {
                    Button(tr("Delete"), role: .destructive) { store.delete(e.id); close() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button(tr("Cancel"), action: close)
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? tr("Add") : tr("Save"), action: save)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear(perform: prefill)
    }

    private func prefill() {
        if let e = editing {
            kind = e.kind
            title = e.title
            link = e.link ?? ""
            if let t = e.time, let d = Day.fireDate(day: e.date, time: t) { time = d }
        } else {
            let nextHour = Day.calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            time = Day.calendar.date(bySettingHour: Day.calendar.component(.hour, from: nextHour), minute: 0, second: 0, of: nextHour) ?? nextHour
        }
        DispatchQueue.main.async { titleFocused = true }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        var item = editing ?? PlannerItem(date: day, kind: kind, title: trimmed)
        item.kind = kind
        item.title = trimmed
        item.time = kind == .task ? nil : Day.timeString(time)
        let l = link.trimmingCharacters(in: .whitespaces)
        item.link = kind == .meeting && !l.isEmpty ? l : nil
        if editing == nil { store.add(item) } else { store.update(item) }
        close()
    }
}

// MARK: - Habits editor

struct HabitEditor: View {
    @EnvironmentObject var store: PlannerStore
    @State private var newName = ""

    private var trimmed: String { newName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Your habits")).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(tr("apply to every day")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if store.data.habits.isEmpty {
                Text(tr("No habits yet. Add your first one below."))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(store.data.habits.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 4) {
                            HabitNameField(index: index, name: name)
                            Button { store.removeHabit(at: index) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).frame(width: 26, height: 26)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help(Lang.isPortuguese ? "Remover \(name)" : "Remove \(name)")
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                TextField(tr("New habit, e.g. Meditate"), text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button(tr("Add"), action: add)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func add() {
        store.addHabit(trimmed)
        newName = ""
    }
}

struct HabitNameField: View {
    @EnvironmentObject var store: PlannerStore
    let index: Int
    let name: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(tr("Habit"), text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onAppear { text = name }
            .onChange(of: name) { _, newValue in text = newValue }
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func commit() {
        if text.trimmingCharacters(in: .whitespaces).isEmpty || text == name { text = name; return }
        store.renameHabit(at: index, to: text)
    }
}

// MARK: - Focus timer

struct TimerPanel: View {
    @EnvironmentObject var timer: FocusTimer
    var compact = false
    @State private var custom = ""
    private let presets = [15, 25, 45, 60]

    var body: some View {
        if compact {
            // Vertical layout: a slim band under the days.
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        statusLine
                        digits(size: 26)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 4) { presetButtons }
                        controls
                    }
                }
                progressBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                statusLine
                digits(size: 30)
                progressBar
                FlowLayout(spacing: 4) { presetButtons }
                controls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
    }

    private var statusLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(tr("FOCUS")).font(.system(size: 12, weight: .semibold)).tracking(0.5).foregroundStyle(.secondary)
            if !compact { Spacer() }
            Text(tr(timer.status)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func digits(size: CGFloat) -> some View {
        Text(timer.display)
            .font(.system(size: size, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(timer.running ? Color.actionBlue : Color.primary)
    }

    private var progressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.hair)
                Capsule().fill(Color.actionFill).frame(width: g.size.width * timer.progress)
            }
        }
        .frame(height: 3)
    }

    @ViewBuilder private var presetButtons: some View {
        ForEach(presets, id: \.self) { m in
            Button("\(m)") { custom = ""; timer.set(minutes: m) }
                .buttonStyle(ChipStyle(selected: custom.isEmpty && timer.duration == m * 60))
        }
        TextField("min", text: $custom)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .multilineTextAlignment(.center)
            .frame(width: 38)
            .padding(.vertical, 2).padding(.horizontal, 5)
            .overlay(Capsule().strokeBorder(custom.isEmpty ? Color.hair : Color.actionBlue))
            .onChange(of: custom) { _, value in
                let digits = String(value.filter(\.isNumber).prefix(3))
                if digits != value { custom = digits; return }
                if let n = Int(digits), n >= 1 { timer.set(minutes: min(180, n)) }
            }
            .onSubmit { if !timer.running, (Int(custom) ?? 0) >= 1 { timer.start() } }
            .help(tr("Custom minutes (1–180). Press Return to start."))
    }

    private var controls: some View {
        HStack(spacing: 6) {
            CircleButton(systemName: timer.running ? "pause.fill" : "play.fill", filled: true) { timer.toggle() }
                .help(timer.running ? tr("Pause") : tr("Start"))
            CircleButton(systemName: "arrow.counterclockwise", filled: false) { timer.reset() }
                .help(tr("Reset"))
        }
    }
}

struct ChipStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .monospacedDigit()
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(selected ? Color.actionBlue : Color.primary)
            .overlay(Capsule().strokeBorder(selected ? Color.actionBlue : Color.hair))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct CircleButton: View {
    let systemName: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(filled ? Color.white : Color.secondary)
                .background(Circle().fill(filled ? Color.actionFill : Color.clear))
                .overlay(Circle().strokeBorder(filled ? Color.clear : Color.hair))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
