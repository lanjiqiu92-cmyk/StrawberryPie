import AppKit
import SwiftUI

enum ReminderPreferenceKeys {
    static let enabled = "reminder.enabled"
    static let intervalMinutes = "reminder.intervalMinutes"
    static let startHour = "reminder.startHour"
    static let endHour = "reminder.endHour"
    static let nextFire = "reminder.nextFire"
}

@MainActor
final class WellnessReminderScheduler: ObservableObject {
    static let shared = WellnessReminderScheduler()

    @Published private(set) var nextFireDate: Date?
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private init() {}

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        reload(resetSchedule: false)
        Task { await ReminderLibrary.refreshIfNeeded() }
    }

    func reload(resetSchedule: Bool = true) {
        guard isEnabled else {
            nextFireDate = nil
            defaults.removeObject(forKey: ReminderPreferenceKeys.nextFire)
            return
        }

        if !resetSchedule,
           let saved = defaults.object(forKey: ReminderPreferenceKeys.nextFire) as? Date,
           saved > Date() {
            nextFireDate = adjustedToActiveHours(saved)
        } else {
            schedule(afterMinutes: intervalMinutes)
        }
    }

    func showTestReminder() {
        WellnessReminderPanelController.shared.show(ReminderLibrary.random())
    }

    func snooze(minutes: Int = 10) {
        guard isEnabled else { return }
        schedule(afterMinutes: minutes)
    }

    var nextFireLabel: String {
        guard isEnabled, let nextFireDate else { return "提醒还没有打开" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(nextFireDate) ? "今天 HH:mm" : "明天 HH:mm"
        return "下一次：\(formatter.string(from: nextFireDate))"
    }

    private var isEnabled: Bool { defaults.bool(forKey: ReminderPreferenceKeys.enabled) }
    private var intervalMinutes: Int { max(10, defaults.integer(forKey: ReminderPreferenceKeys.intervalMinutes)) }
    private var startHour: Int {
        defaults.object(forKey: ReminderPreferenceKeys.startHour) == nil ? 9 : defaults.integer(forKey: ReminderPreferenceKeys.startHour)
    }
    private var endHour: Int {
        defaults.object(forKey: ReminderPreferenceKeys.endHour) == nil ? 22 : defaults.integer(forKey: ReminderPreferenceKeys.endHour)
    }

    private func tick() {
        guard isEnabled else { return }
        guard let nextFireDate else {
            schedule(afterMinutes: intervalMinutes)
            return
        }
        guard Date() >= nextFireDate else { return }
        guard isInsideActiveHours(Date()) else {
            schedule(afterMinutes: intervalMinutes)
            return
        }

        WellnessReminderPanelController.shared.show(ReminderLibrary.random())
        schedule(afterMinutes: intervalMinutes)
    }

    private func schedule(afterMinutes minutes: Int) {
        let proposed = Date().addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        let adjusted = adjustedToActiveHours(proposed)
        nextFireDate = adjusted
        defaults.set(adjusted, forKey: ReminderPreferenceKeys.nextFire)
    }

    private func isInsideActiveHours(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if startHour <= endHour { return hour >= startHour && hour < endHour }
        return hour >= startHour || hour < endHour
    }

    private func adjustedToActiveHours(_ date: Date) -> Date {
        guard !isInsideActiveHours(date) else { return date }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        var dayOffset = 0
        if startHour <= endHour, hour >= endHour { dayOffset = 1 }
        if startHour > endHour, hour >= endHour && hour < startHour { dayOffset = 0 }
        let day = calendar.date(byAdding: .day, value: dayOffset, to: date) ?? date
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day) ?? date
    }
}

@MainActor
final class WellnessReminderPanelController: NSObject, NSWindowDelegate {
    static let shared = WellnessReminderPanelController()

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 344, height: 222),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        return panel
    }()

    func show(_ copy: WellnessReminderCopy) {
        panel.contentView = NSHostingView(rootView: WellnessReminderCard(
            copy: copy,
            onDone: { [weak self] in self?.panel.orderOut(nil) },
            onSnooze: { [weak self] in
                WellnessReminderScheduler.shared.snooze()
                self?.panel.orderOut(nil)
            }
        ))
        position()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - panel.frame.width - 26,
            y: visible.maxY - panel.frame.height - 28
        ))
    }
}

private struct WellnessReminderCard: View {
    let copy: WellnessReminderCopy
    let onDone: () -> Void
    let onSnooze: () -> Void
    @State private var appeared = false

    private let ink = Color(red: 0.17, green: 0.125, blue: 0.115)
    private let paper = Color(red: 0.99, green: 0.965, blue: 0.90)
    private let pink = Color(red: 0.84, green: 0.60, blue: 0.66)
    private let chocolate = Color(red: 0.31, green: 0.21, blue: 0.19)

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                familyThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(copy.emoji)  \(copy.title)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text(copy.message)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(copy.footer)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(chocolate.opacity(0.68))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 9) {
                Button("十分钟后再叫我", action: onSnooze)
                    .buttonStyle(ReminderButtonStyle(fill: paper, ink: ink))
                Button("我去我去！", action: onDone)
                    .buttonStyle(ReminderButtonStyle(fill: chocolate, ink: .white))
            }
        }
        .padding(15)
        .frame(width: 344, height: 222)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink, lineWidth: 3))
        .overlay(alignment: .topTrailing) {
            Text("PAW!")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(pink)
                .rotationEffect(.degrees(8))
                .padding(11)
        }
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) { appeared = true }
        }
    }

    private var familyThumbnail: some View {
        Group {
            if let url = Bundle.main.url(forResource: "TwoCats", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Text("🐱🐱").font(.system(size: 32))
            }
        }
        .frame(width: 82, height: 82)
        .background(pink.opacity(0.22))
        .clipShape(Circle())
        .overlay(Circle().stroke(ink, lineWidth: 2))
    }
}

private struct ReminderButtonStyle: ButtonStyle {
    let fill: Color
    let ink: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .black, design: .rounded))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(fill.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.17, green: 0.125, blue: 0.115), lineWidth: 2))
    }
}
