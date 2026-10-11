import AppKit
import EventKit
import SwiftUI

/// An event read live from the Mac's Calendar (iCloud, Google, Outlook, subscribed .ics links…).
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    let calendarTitle: String
    let joinURL: URL?
    let eventIdentifier: String?
}

/// Keeps the planner in sync with every calendar the Mac knows about.
/// Google or Outlook accounts come in through System Settings > Internet Accounts,
/// and any site's .ics link through a Calendar subscription.
@MainActor
final class CalendarService: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "calendarsEnabled")
            if enabled { Task { await connect() } } else { reload() }
        }
    }
    @Published private(set) var authorized = false
    @Published private(set) var denied = false
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var hiddenIDs: Set<String>
    @Published private(set) var eventsByDay: [String: [CalendarEvent]] = [:]

    private let eventStore = EKEventStore()
    private var weekStart = Day.startOfWeek(Date())
    private var observer: NSObjectProtocol?

    init() {
        enabled = UserDefaults.standard.bool(forKey: "calendarsEnabled")
        hiddenIDs = Set(UserDefaults.standard.stringArray(forKey: "hiddenCalendars") ?? [])
        updateStatus()
        // Fires whenever any calendar changes, locally or after a sync with Google/iCloud.
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        if enabled { Task { await connect() } }
    }

    func connect() async {
        updateStatus()
        if !authorized && !denied {
            _ = try? await eventStore.requestFullAccessToEvents()
            updateStatus()
        }
        eventStore.refreshSourcesIfNecessary()
        reload()
    }

    func show(week: Date) {
        weekStart = week
        reload()
    }

    func events(on day: String) -> [CalendarEvent] { eventsByDay[day] ?? [] }

    func isVisible(_ calendar: EKCalendar) -> Bool { !hiddenIDs.contains(calendar.calendarIdentifier) }

    func setVisible(_ calendar: EKCalendar, _ visible: Bool) {
        if visible { hiddenIDs.remove(calendar.calendarIdentifier) } else { hiddenIDs.insert(calendar.calendarIdentifier) }
        UserDefaults.standard.set(Array(hiddenIDs), forKey: "hiddenCalendars")
        reload()
    }

    func reload() {
        updateStatus()
        guard enabled, authorized else {
            calendars = []
            eventsByDay = [:]
            return
        }
        calendars = eventStore.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
        let visible = calendars.filter(isVisible)
        guard !visible.isEmpty else {
            eventsByDay = [:]
            return
        }
        let predicate = eventStore.predicateForEvents(withStart: weekStart, end: Day.add(7, to: weekStart), calendars: visible)
        let events = eventStore.events(matching: predicate)

        var map: [String: [CalendarEvent]] = [:]
        for i in 0..<7 {
            let dayStart = Day.add(i, to: weekStart)
            let dayEnd = Day.add(i + 1, to: weekStart)
            map[Day.key(dayStart)] = events
                .filter { $0.startDate < dayEnd && ($0.endDate > dayStart || $0.startDate >= dayStart) }
                .map(Self.convert)
        }
        eventsByDay = map
    }

    // MARK: Adding calendars

    /// Google, Outlook/Exchange and iCloud accounts are added once in System Settings.
    func openInternetAccounts() {
        open("x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")
    }

    func openPrivacySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    /// Hands an .ics link to the Calendar app, which subscribes and keeps it updated.
    @discardableResult
    func subscribe(to link: String) -> Bool {
        var s = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        if let scheme = s.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) {
            s.replaceSubrange(scheme, with: "webcal://")
        } else {
            s = "webcal://" + s
        }
        guard let url = URL(string: s) else { return false }
        return NSWorkspace.shared.open(url)
    }

    static func openInCalendar(_ event: CalendarEvent) {
        if let id = event.eventIdentifier?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "ical://ekevent/\(id)?method=show&options=more"),
           NSWorkspace.shared.open(url) {
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    // MARK: Private

    private func updateStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorized = status == .fullAccess
        denied = status == .denied || status == .restricted || status == .writeOnly
    }

    private func open(_ raw: String) {
        if let url = URL(string: raw) { NSWorkspace.shared.open(url) }
    }

    private static func convert(_ e: EKEvent) -> CalendarEvent {
        let title = (e.title ?? "").trimmingCharacters(in: .whitespaces)
        return CalendarEvent(
            id: "\(e.calendarItemIdentifier)-\(e.startDate.timeIntervalSince1970)",
            title: title.isEmpty ? tr("Untitled") : title,
            start: e.startDate,
            end: e.endDate,
            isAllDay: e.isAllDay,
            color: Color(nsColor: e.calendar.color ?? .systemBlue),
            calendarTitle: e.calendar.title,
            joinURL: meetingURL(in: e),
            eventIdentifier: e.eventIdentifier
        )
    }

    private static let meetingPattern = try? NSRegularExpression(
        pattern: #"https?://[^\s<>"')]*(meet\.google\.com|zoom\.us|teams\.microsoft\.com|teams\.live\.com|webex\.com|whereby\.com|meet\.jit\.si)[^\s<>"')]*"#,
        options: .caseInsensitive
    )

    /// Finds a Meet/Zoom/Teams link in the event's URL, location or notes.
    private static func meetingURL(in e: EKEvent) -> URL? {
        let text = [e.url?.absoluteString, e.location, e.notes].compactMap { $0 }.joined(separator: "\n")
        guard let pattern = meetingPattern,
              let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return URL(string: String(text[range]))
    }
}

// MARK: - Views

struct EventRow: View {
    @EnvironmentObject var settings: AppSettings
    let event: CalendarEvent
    @State private var hover = false

    private var size: CGFloat { settings.textSize.points }
    private var isOver: Bool { event.end < Date() }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(event.color)
                .frame(width: 7, height: 7)
                .frame(width: size + 2, height: size + 4)
            VStack(alignment: .leading, spacing: 2) {
                // Time comes first, above the title.
                HStack(spacing: 8) {
                    Text(event.isAllDay ? tr("All day") : "\(Day.timeString(event.start)) – \(Day.timeString(event.end))")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                    if let url = event.joinURL {
                        Link(tr("Join"), destination: url)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.actionBlue)
                    }
                }
                .font(.system(size: size - 2))
                .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.system(size: size))
                    .foregroundStyle(isOver ? Color.secondary : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(hover ? Color.raised : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .help(event.calendarTitle)
        .contextMenu {
            Button(tr("Open in Calendar")) { CalendarService.openInCalendar(event) }
        }
    }
}

struct CalendarButton: View {
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Image(systemName: "calendar").font(.system(size: 15))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(tr("Synced calendars"))
        .popover(isPresented: $open, arrowEdge: .bottom) { CalendarSettingsView() }
    }
}

struct CalendarSettingsView: View {
    @EnvironmentObject var calendar: CalendarService
    @State private var link = ""
    @State private var sent = false

    private var groups: [(String, [EKCalendar])] {
        Dictionary(grouping: calendar.calendars, by: { $0.source.title })
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Calendars")).font(.system(size: 13, weight: .semibold))

            Toggle(tr("Sync with your Mac calendars"), isOn: $calendar.enabled)
                .toggleStyle(.switch)
                .font(.system(size: 13))

            if calendar.enabled && calendar.denied {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Planner can't access your calendars. Allow it in System Settings > Privacy & Security > Calendars."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(tr("Open Settings")) { calendar.openPrivacySettings() }
                }
            }

            if calendar.enabled && calendar.authorized {
                if calendar.calendars.isEmpty {
                    Text(tr("No calendars on this Mac yet. Add one below."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(groups, id: \.0) { source, cals in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.uppercased())
                                        .font(.system(size: 11, weight: .semibold)).tracking(0.5)
                                        .foregroundStyle(.secondary)
                                    ForEach(cals, id: \.calendarIdentifier) { cal in
                                        Toggle(isOn: Binding(get: { calendar.isVisible(cal) },
                                                             set: { calendar.setVisible(cal, $0) })) {
                                            HStack(spacing: 6) {
                                                Circle().fill(Color(nsColor: cal.color ?? .systemBlue)).frame(width: 8, height: 8)
                                                Text(cal.title).font(.system(size: 13)).lineLimit(1)
                                            }
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                }
            }

            Rectangle().fill(Color.hair).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Add a calendar")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Button(tr("Google, Outlook or iCloud account…")) { calendar.openInternetAccounts() }
                Text(tr("In Internet Accounts, sign in and turn on Calendars."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)

                Text(tr("Calendar link from any website (.ics)")).font(.system(size: 12)).padding(.top, 4)
                HStack(spacing: 6) {
                    TextField(tr("https://…/calendar.ics"), text: $link)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(subscribe)
                    Button(tr("Subscribe"), action: subscribe)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text(sent ? tr("Calendar opened to confirm. The events will show up here afterwards.")
                          : tr("Calendar opens to confirm, then keeps it up to date."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private func subscribe() {
        if calendar.subscribe(to: link) {
            sent = true
            link = ""
            if !calendar.enabled { calendar.enabled = true }
        }
    }
}
