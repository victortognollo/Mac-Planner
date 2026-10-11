import AppKit

@MainActor
final class FocusTimer: ObservableObject {
    @Published private(set) var duration = 25 * 60
    @Published private(set) var remaining = 25 * 60
    @Published private(set) var running = false
    @Published private(set) var status = "Ready"

    var onFinish: ((Int) -> Void)?

    private var end: Date?
    private var ticker: Timer?

    var display: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var progress: Double { duration > 0 ? 1 - Double(remaining) / Double(duration) : 0 }

    /// Picking a new length always stops the current run and loads the new time.
    func set(minutes: Int) {
        stopTicker()
        Notifier.shared.cancelTimerEnd()
        duration = max(1, minutes) * 60
        remaining = duration
        running = false
        status = "Ready"
    }

    func toggle() { running ? pause() : start() }

    func start() {
        if remaining <= 0 { remaining = duration }
        end = Date().addingTimeInterval(TimeInterval(remaining))
        running = true
        status = "Focusing"
        Notifier.shared.scheduleTimerEnd(after: remaining, minutes: duration / 60)
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func pause() {
        if let end { remaining = max(0, Int(ceil(end.timeIntervalSinceNow))) }
        stopTicker()
        Notifier.shared.cancelTimerEnd()
        running = false
        status = "Paused"
    }

    func reset() {
        stopTicker()
        Notifier.shared.cancelTimerEnd()
        running = false
        remaining = duration
        status = "Ready"
    }

    private func tick() {
        guard let end else { return }
        let left = Int(ceil(end.timeIntervalSinceNow))
        if left > 0 {
            remaining = left
            return
        }
        stopTicker()
        running = false
        remaining = duration
        status = "Done"
        NSSound(named: "Glass")?.play()
        onFinish?(duration / 60)
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        end = nil
    }
}
