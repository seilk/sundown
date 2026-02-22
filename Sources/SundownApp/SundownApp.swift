import SwiftUI
import AppKit
import Combine
import SundownCore

@main
struct SundownApp: App {
    @NSApplicationDelegateAdaptor(StatusAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {}
    }
}

@MainActor
private final class StatusAppDelegate: NSObject, NSApplicationDelegate {
    let model = SundownViewModel()
    private var statusCoordinator: StatusCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusCoordinator = StatusCoordinator(model: model)
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
private final class StatusCoordinator: NSObject {
    private let model: SundownViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let menu: NSMenu
    private let settingsWindowController: SettingsWindowController
    private let iconRenderer = StatusIconRenderer(theme: .sunset)
    private var iconPhase: StatusIconPhase = .onboarding
    private var cancellables = Set<AnyCancellable>()

    init(model: SundownViewModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        menu = NSMenu()
        settingsWindowController = SettingsWindowController(model: model)
        super.init()

        if let button = statusItem.button {
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refreshStatusIcon()
            }
            .store(in: &cancellables)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: MenuPanelView(model: model)
                .frame(width: 360, height: 620, alignment: .top)
                .padding(10)
                .background(UIStyle.panelBackground)
        )

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Sundown", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        refreshStatusIcon()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        if event.type == .rightMouseUp {
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
            return
        }

        togglePopover(sender)
    }

    @objc private func openSettings() {
        settingsWindowController.showWindow(nil)
        settingsWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }

    private func refreshStatusIcon() {
        let render = iconRenderer.render(snapshot: model.statusIconSnapshot, previousPhase: iconPhase)
        iconPhase = render.1

        guard let button = statusItem.button else {
            return
        }

        button.contentTintColor = nil
        button.imagePosition = render.0.showsIcon ? .imageLeft : .noImage
        button.image = render.0.showsIcon ? render.0.image : nil
        button.attributedTitle = NSAttributedString(
            string: render.0.title,
            attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: render.0.titleColor
            ]
        )
        button.toolTip = render.0.toolTip
    }
}

@MainActor
private final class SettingsWindowController: NSWindowController {
    init(model: SundownViewModel) {
        let rootView = SettingsWindowView(model: model)
            .frame(width: 430, height: 560)
            .padding(14)
            .background(UIStyle.panelBackground)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Sundown Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private struct MenuPanelView: View {
    @ObservedObject var model: SundownViewModel

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sundown")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(UIStyle.subtleText)
                    Spacer()
                    Button("Reset") {
                        model.resetSundownSession()
                    }
                    .buttonStyle(HeroGlassButtonStyle())
                }

                if model.gateState == .allowed, model.hasStartedSundown, let worktimeState = model.worktimeState {
                    Text(model.worktimeStateFormatter.displayText(for: worktimeState))
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(model.worktimeStateFormatter.isOverLimit(worktimeState) ? UIStyle.alertText : UIStyle.primaryText)
                } else if model.gateState == .allowed, model.hasStartedSundown, !model.isSundownActive {
                    Text("Paused")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(UIStyle.primaryText)
                } else {
                    Text(model.menuTitle)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(UIStyle.primaryText)
                }

                Text(model.hasStartedSundown ? (model.isSundownActive ? "Session Active" : "Session Paused") : "Session Not Started")
                    .font(.caption)
                    .foregroundStyle(UIStyle.subtleText)

                HStack(spacing: 8) {
                    Text("Worktime \(model.limitLabel)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(UIStyle.subtleText)

                    Spacer()

                    Button("-30m") {
                        model.adjustDailyLimit(by: -30)
                    }
                    .buttonStyle(HeroGlassButtonStyle())

                    Button("+30m") {
                        model.adjustDailyLimit(by: 30)
                    }
                    .buttonStyle(HeroGlassButtonStyle(prominent: true))
                }

                if !model.hasStartedSundown {
                    Button {
                        model.startSundown()
                    } label: {
                        Label("Start Sundown", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HeroGlassButtonStyle(prominent: true))
                    .disabled(model.gateState != .allowed)
                } else {
                    LightSwitchPauseToggle(
                        isPaused: Binding(
                            get: { !model.isSundownActive },
                            set: { model.setPaused($0) }
                        )
                    )
                }
            }
            .frame(height: 285, alignment: .top)
            .padding(14)
            .background(UIStyle.heroBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today Ritual")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(UIStyle.subtleText)
                }

                if model.hasStartedSundown {
                    RitualDonutView(
                        workedSeconds: model.trackedWorkSecondsTotal,
                        limitMinutes: model.currentLimitMinutes
                    )
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Complete onboarding in Settings to start ritual tracking.")
                        .font(.caption)
                        .foregroundStyle(UIStyle.subtleText)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 315, alignment: .top)
            .padding(12)
            .background(UIStyle.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsWindowView: View {
    @ObservedObject var model: SundownViewModel
    @State private var selectedTab: SettingsTab = .workday

    var body: some View {
        TabView(selection: $selectedTab) {
            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "Workday") {
                        HStack(spacing: 8) {
                            Button("6h") { model.setDailyLimit(360) }.buttonStyle(.bordered)
                            Button("8h") { model.setDailyLimit(480) }.buttonStyle(.bordered)
                            Button("10h") { model.setDailyLimit(600) }.buttonStyle(.bordered)
                            Button("Clear") { model.clearOnboardingSettings() }.buttonStyle(.bordered)
                        }

                        HStack(spacing: 12) {
                            Stepper(value: Binding(
                                get: { model.dailyLimitHours },
                                set: { model.setDailyLimitHours($0) }
                            ), in: 0...23, step: 1) {
                                Text("Hours: \(model.dailyLimitHours)")
                            }

                            Stepper(value: Binding(
                                get: { model.dailyLimitRemainderMinutes },
                                set: { model.setDailyLimitRemainderMinutes($0) }
                            ), in: 0...59, step: 1) {
                                Text("Minutes: \(model.dailyLimitRemainderMinutes)")
                            }
                        }

                        Text("Daily Limit: \(model.limitLabel)")
                            .font(.caption)
                            .foregroundStyle(UIStyle.subtleText)

                        Picker("Menu Bar Display", selection: Binding(
                            get: { model.menuBarDisplayMode },
                            set: { model.setMenuBarDisplayMode($0) }
                        )) {
                            ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Stepper(value: Binding(
                            get: { model.persistedSettings.dayResetMinutesFromMidnight ?? 240 },
                            set: { model.setResetTime($0) }
                        ), in: 0...1_439, step: 15) {
                            Text("Reset Time: \(model.resetLabel)")
                        }

                        Text("Overworked today: \(model.todayOverworkLabel)")
                            .font(.caption)
                            .foregroundStyle(model.todayOverworkMinutes > 0 ? UIStyle.alertText : UIStyle.subtleText)
                    }
                }
            }
            .tabItem { Label("Workday", systemImage: "briefcase.fill") }
            .tag(SettingsTab.workday)

            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "Behavior") {
                        Stepper(value: Binding(
                            get: { model.persistedSettings.idleThresholdMinutes ?? 5 },
                            set: { model.setIdleThreshold(max(1, $0)) }
                        ), in: 1...30, step: 1) {
                            Text("Idle Threshold: \(model.persistedSettings.idleThresholdMinutes ?? 5)m")
                        }

                        HStack(spacing: 8) {
                            Button("Set Active Input") { model.setActiveInput() }
                                .buttonStyle(.bordered)
                            Button("Simulate Idle") { model.simulateIdleThresholdCrossing() }
                                .buttonStyle(.bordered)
                        }

                        Text("Current Activity: \(model.activityLabel)")
                            .font(.caption)
                            .foregroundStyle(UIStyle.subtleText)
                    }

                    SettingsCard(title: "Scenario") {
                        Picker("Scenario", selection: Binding(
                            get: { model.prototypeScenario },
                            set: { model.setScenario($0) }
                        )) {
                            ForEach(PrototypeScenario.allCases, id: \.self) { scenario in
                                Text(scenario.label).tag(scenario)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Day ID: \(model.currentDayId)")
                            .font(.caption)
                            .foregroundStyle(UIStyle.subtleText)
                    }
                }
            }
            .tabItem { Label("Behavior", systemImage: "figure.walk") }
            .tag(SettingsTab.behavior)

            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "Notifications") {
                        Toggle("Enable Notifications", isOn: Binding(
                            get: { model.persistedSettings.notificationsEnabled ?? false },
                            set: { model.setNotificationsEnabled($0) }
                        ))

                        Stepper(value: Binding(
                            get: { model.persistedSettings.overLimitReminderMinutes ?? 30 },
                            set: { model.setReminderInterval(max(1, $0)) }
                        ), in: 1...120, step: 5) {
                            Text("Reminder Interval: \(model.reminderInterval)m")
                        }

                        HStack(spacing: 8) {
                            Button("Mark Sent") { model.markNotificationSentNow() }
                                .buttonStyle(.bordered)
                            Button("Clear History") { model.clearNotificationHistory() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .tabItem { Label("Alerts", systemImage: "bell.badge.fill") }
            .tag(SettingsTab.notifications)

            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "QA Lab") {
                        Text("Run one-click scenarios to verify onboarding, overwork, idle/break, and notification behavior.")
                            .font(.caption)
                            .foregroundStyle(UIStyle.subtleText)

                        Picker("Scenario Pack", selection: Binding(
                            get: { model.selectedQAPreset },
                            set: { model.selectedQAPreset = $0 }
                        )) {
                            ForEach(QAPreset.allCases, id: \.self) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }

                        Text(model.selectedQAPreset.summary)
                            .font(.caption)
                            .foregroundStyle(UIStyle.subtleText)

                        HStack(spacing: 8) {
                            Button("Apply Scenario") {
                                model.applyQAPreset(model.selectedQAPreset)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Reminder Ready") {
                                model.simulateReminderReady()
                            }
                            .buttonStyle(.bordered)

                            Button("Reminder Blocked") {
                                model.simulateReminderBlocked()
                            }
                            .buttonStyle(.bordered)
                        }

                        if let qaStatusMessage = model.qaStatusMessage {
                            Text(qaStatusMessage)
                                .font(.caption)
                                .foregroundStyle(UIStyle.subtleText)
                        }
                    }
                }
            }
            .tabItem { Label("QA Lab", systemImage: "testtube.2") }
            .tag(SettingsTab.qa)
        }
    }
}

private enum SettingsTab {
    case workday
    case behavior
    case notifications
    case qa
}

private struct LightSwitchPauseToggle: View {
    @Binding var isPaused: Bool

    private let trackWidth: CGFloat = 58
    private let trackHeight: CGFloat = 30
    private let knobSize: CGFloat = 24

    var body: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.12)) {
                isPaused.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Text(isPaused ? "Paused" : "Running")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(UIStyle.primaryText)
                    .frame(width: 60, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isPaused ? Color(red: 0.82, green: 0.83, blue: 0.85) : Color(red: 0.20, green: 0.76, blue: 0.42))
                        .frame(width: trackWidth, height: trackHeight)

                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: Color.black.opacity(0.12), radius: 1.5, x: 0, y: 1)
                        .offset(x: isPaused ? -(trackWidth - knobSize) / 2 + 3 : (trackWidth - knobSize) / 2 - 3)
                }
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.12), value: isPaused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HeroGlassButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Color.white.opacity(0.92) : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(prominent ? UIStyle.primaryText : UIStyle.subtleText)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(UIStyle.subtleText)

            content
        }
        .padding(12)
        .background(UIStyle.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@MainActor
private final class SundownViewModel: ObservableObject {
    let worktimeStateFormatter = WorktimeStateFormatter()

    private let onboardingGateEvaluator = OnboardingGateEvaluator()
    private let overLimitNotificationPolicy = OverLimitNotificationPolicy()
    private let notificationService: NotificationService
    private let timeEngine = TimeEngine()
    private let settingsStore: UserDefaultsSettingsStore
    private let dayRecordStore: UserDefaultsDayRecordStore
    private var timerCancellable: AnyCancellable?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var wakeObserver: AnyCancellable?
    private var lastTickAt: Date?
    private var trackedSecondsAccumulator: Double = 0
    private var lastInteractionAt = Date()

    @Published var persistedSettings: PersistedSettings
    @Published var prototypeScenario: PrototypeScenario = .overLimit
    @Published var previousScenario: PrototypeScenario = .atLimit
    @Published var lastNotificationAt: Date?
    @Published var inactivitySeconds = 0
    @Published var isSundownActive = false
    @Published var hasStartedSundown = false
    @Published private(set) var trackedWorkSecondsTotal = 0
    @Published var dayRecord: DayRecord?
    @Published var selectedQAPreset: QAPreset = .overworkNow
    @Published var qaStatusMessage: String?

    init(
        notificationService: NotificationService = UserNotificationCenterService(),
        settingsStore: UserDefaultsSettingsStore = UserDefaultsSettingsStore(),
        dayRecordStore: UserDefaultsDayRecordStore = UserDefaultsDayRecordStore()
    ) {
        self.notificationService = notificationService
        self.settingsStore = settingsStore
        self.dayRecordStore = dayRecordStore
        self.persistedSettings = settingsStore.load()

        setupHeartbeat()
        setupActivityMonitors()
        setupWakeObserver()
    }

    deinit {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }

    var gateState: OnboardingGateState {
        onboardingGateEvaluator.evaluate(
            OnboardingSettings(
                dailyLimitMinutes: persistedSettings.dailyLimitMinutes,
                dayResetMinutesFromMidnight: persistedSettings.dayResetMinutesFromMidnight
            )
        )
    }

    var worktimeState: WorktimeState? {
        guard let trackedWorkSeconds else {
            return nil
        }

        return timeEngine.worktimeState(elapsedSeconds: trackedWorkSeconds, settings: persistedSettings)
    }

    var activity: ActivityKind {
        guard isSundownActive else {
            return .idle
        }

        return timeEngine.activity(
            isBreakActive: false,
            inactivitySeconds: inactivitySeconds,
            settings: persistedSettings
        )
    }

    var reminderInterval: Int {
        timeEngine.reminderIntervalMinutes(settings: persistedSettings)
    }

    var shouldNotify: Bool {
        overLimitNotificationPolicy.shouldNotify(
            notificationsEnabled: persistedSettings.notificationsEnabled,
            isOverLimit: worktimeState.map(worktimeStateFormatter.isOverLimit) ?? false,
            wasOverLimit: previousScenario == .overLimit,
            now: Date(),
            lastNotificationAt: lastNotificationAt,
            reminderIntervalMinutes: reminderInterval
        )
    }

    var currentDayId: String {
        timeEngine.dayId(now: Date(), settings: persistedSettings) ?? "Unavailable"
    }

    var todayRecord: DayRecord? {
        guard isSundownActive else {
            return nil
        }

        return resolvedDayRecord(now: Date())
    }

    var activityLabel: String {
        switch activity {
        case .work:
            return "Work"
        case .breakTime:
            return "Break"
        case .idle:
            return "Idle"
        }
    }

    var liveOverworkSeconds: Int {
        guard let worktimeState else {
            return 0
        }

        switch worktimeState {
        case .underLimit:
            return 0
        case let .overLimit(overtimeSeconds):
            return max(0, overtimeSeconds)
        }
    }

    var liveOverworkLabel: String? {
        guard liveOverworkSeconds > 0 else {
            return nil
        }

        return formatDuration(seconds: liveOverworkSeconds)
    }

    var todayOverworkMinutes: Int {
        guard currentLimitMinutes > 0 else {
            return 0
        }

        return max(0, workedMinutesToday - currentLimitMinutes)
    }

    var workedMinutesToday: Int {
        max(0, trackedWorkSecondsTotal / 60)
    }

    var currentLimitMinutes: Int {
        max(0, persistedSettings.dailyLimitMinutes ?? 0)
    }

    var todayOverworkLabel: String {
        if todayOverworkMinutes <= 0 {
            return "0m"
        }

        let hours = todayOverworkMinutes / 60
        let minutes = todayOverworkMinutes % 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    var todayWorkdayDeltaMinutes: Int? {
        guard isSundownActive, currentLimitMinutes > 0 else {
            return nil
        }

        return workedMinutesToday - currentLimitMinutes
    }

    var todayWorkdayDeltaCaption: String {
        guard let deltaMinutes = todayWorkdayDeltaMinutes else {
            return "No data"
        }

        if deltaMinutes == 0 {
            return "On target"
        }

        let hours = Double(abs(deltaMinutes)) / 60.0
        let sign = deltaMinutes > 0 ? "+" : "-"
        let direction = deltaMinutes > 0 ? "over" : "under"
        return String(format: "%@%.1fh %@", sign, hours, direction)
    }

    var todayWorkdayDeltaTone: Color {
        guard let deltaMinutes = todayWorkdayDeltaMinutes else {
            return UIStyle.subtleText
        }

        if deltaMinutes > 0 {
            return UIStyle.alertText
        }

        if deltaMinutes < 0 {
            return Color(red: 0.12, green: 0.44, blue: 0.84)
        }

        return UIStyle.subtleText
    }

    var menuTitle: String {
        switch gateState {
        case .blockedMissingDailyLimit:
            return "Set daily limit to start"
        case .blockedInvalidDailyLimit:
            return "Daily limit must be above 0"
        case .blockedMissingResetTime:
            return "Set day reset time to start"
        case .blockedInvalidResetTime:
            return "Reset time must be 00:00-23:59"
        case .allowed:
            return "Sundown is ready"
        }
    }

    var limitLabel: String {
        if let dailyLimitMinutes = persistedSettings.dailyLimitMinutes {
            let hours = dailyLimitMinutes / 60
            let minutes = dailyLimitMinutes % 60
            return String(format: "%dh %02dm", hours, minutes)
        }

        return "Unset"
    }

    var dailyLimitHours: Int {
        (persistedSettings.dailyLimitMinutes ?? 480) / 60
    }

    var dailyLimitRemainderMinutes: Int {
        (persistedSettings.dailyLimitMinutes ?? 480) % 60
    }

    var resetLabel: String {
        guard let dayResetMinutesFromMidnight = persistedSettings.dayResetMinutesFromMidnight else {
            return "Unset"
        }

        let hours = dayResetMinutesFromMidnight / 60
        let minutes = dayResetMinutesFromMidnight % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    var statusIconSnapshot: StatusIconSnapshot {
        StatusIconSnapshot(
            gateState: gateState,
            worktimeState: worktimeState,
            dailyLimitMinutes: persistedSettings.dailyLimitMinutes,
            menuTitle: menuTitle,
            menuBarDisplayMode: menuBarDisplayMode
        )
    }

    var menuBarDisplayMode: MenuBarDisplayMode {
        let rawValue = persistedSettings.menuBarDisplayModeRawValue ?? MenuBarDisplayMode.icon.rawValue
        return MenuBarDisplayMode(rawValue: rawValue) ?? .icon
    }

    func setScenario(_ scenario: PrototypeScenario) {
        previousScenario = prototypeScenario
        prototypeScenario = scenario
    }

    func startSundown() {
        guard gateState == .allowed else {
            return
        }

        hasStartedSundown = true
        isSundownActive = true
        lastTickAt = Date()
        if trackedWorkSecondsTotal == 0 {
            trackedSecondsAccumulator = 0
        }
        markUserInteraction()
    }

    func toggleSundownSession() {
        guard gateState == .allowed else {
            return
        }

        hasStartedSundown = true
        isSundownActive.toggle()
    }

    func setPaused(_ paused: Bool) {
        guard hasStartedSundown else {
            return
        }

        if paused {
            flushTick(now: Date())
        } else {
            lastTickAt = Date()
            markUserInteraction()
        }

        isSundownActive = !paused
    }

    func resetSundownSession() {
        let now = Date()
        hasStartedSundown = false
        isSundownActive = false
        inactivitySeconds = 0
        lastNotificationAt = nil
        lastTickAt = now
        lastInteractionAt = now
        setTrackedWorkSeconds(0)

        if let dayId = timeEngine.dayId(now: now, settings: persistedSettings),
           let limitMinutes = persistedSettings.dailyLimitMinutes {
            let record = DayRecord(dayId: dayId, limitMinutes: limitMinutes)
            dayRecordStore.save(record)
            dayRecord = record
        } else {
            dayRecord = nil
        }
    }

    func setActiveInput() {
        markUserInteraction()
    }

    func simulateIdleThresholdCrossing() {
        inactivitySeconds = (persistedSettings.idleThresholdMinutes ?? 5) * 60
    }

    func setDailyLimit(_ minutes: Int) {
        updateSettings { settings in
            settings.dailyLimitMinutes = minutes
        }
    }

    func adjustDailyLimit(by deltaMinutes: Int) {
        let current = persistedSettings.dailyLimitMinutes ?? 480
        let next = min(max(30, current + deltaMinutes), 1_440)
        setDailyLimit(next)
    }

    func setDailyLimitHours(_ hours: Int) {
        let normalizedHours = min(max(0, hours), 23)
        setDailyLimitComponents(hours: normalizedHours, minutes: dailyLimitRemainderMinutes)
    }

    func setDailyLimitRemainderMinutes(_ minutes: Int) {
        let normalizedMinutes = min(max(0, minutes), 59)
        setDailyLimitComponents(hours: dailyLimitHours, minutes: normalizedMinutes)
    }

    func setMenuBarDisplayMode(_ mode: MenuBarDisplayMode) {
        updateSettings { settings in
            settings.menuBarDisplayModeRawValue = mode.rawValue
        }
    }

    func setResetTime(_ minutesFromMidnight: Int) {
        updateSettings { settings in
            settings.dayResetMinutesFromMidnight = (minutesFromMidnight + 1_440) % 1_440
        }
    }

    func setIdleThreshold(_ minutes: Int) {
        updateSettings { settings in
            settings.idleThresholdMinutes = minutes
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        updateSettings { settings in
            settings.notificationsEnabled = enabled
        }

        if enabled {
            notificationService.requestAuthorizationIfNeeded()
        }
    }

    func setReminderInterval(_ minutes: Int) {
        updateSettings { settings in
            settings.overLimitReminderMinutes = minutes
        }
    }

    func clearOnboardingSettings() {
        settingsStore.save(
            PersistedSettings(
                dailyLimitMinutes: nil,
                dayResetMinutesFromMidnight: nil,
                notificationsEnabled: nil,
                idleThresholdMinutes: nil,
                overLimitReminderMinutes: nil,
                menuBarDisplayModeRawValue: persistedSettings.menuBarDisplayModeRawValue
            )
        )
        reloadSettings()
    }

    func markNotificationSentNow() {
        lastNotificationAt = Date()
    }

    func clearNotificationHistory() {
        lastNotificationAt = nil
    }

    func sendNotificationIfAllowed() {
        guard shouldNotify, let worktimeState else {
            return
        }

        notificationService.sendOverLimitNotification(
            message: "Over limit: \(worktimeStateFormatter.displayText(for: worktimeState))"
        )
        lastNotificationAt = Date()
    }

    func applyQAPreset(_ preset: QAPreset) {
        switch preset {
        case .firstRunBlocked:
            settingsStore.save(
                PersistedSettings(
                    dailyLimitMinutes: nil,
                    dayResetMinutesFromMidnight: nil,
                    notificationsEnabled: nil,
                    idleThresholdMinutes: nil,
                    overLimitReminderMinutes: nil,
                    menuBarDisplayModeRawValue: persistedSettings.menuBarDisplayModeRawValue
                )
            )
            prototypeScenario = .underLimit
            previousScenario = .underLimit
            inactivitySeconds = 0
            isSundownActive = false
            hasStartedSundown = false
            setTrackedWorkSeconds(0)
            lastNotificationAt = nil
            dayRecord = nil
            qaStatusMessage = "Applied First Run Blocked: onboarding gate should block usage."

        case .healthyDay:
            settingsStore.save(
                PersistedSettings(
                    dailyLimitMinutes: 480,
                    dayResetMinutesFromMidnight: 240,
                    notificationsEnabled: false,
                    idleThresholdMinutes: 5,
                    overLimitReminderMinutes: 30,
                    menuBarDisplayModeRawValue: persistedSettings.menuBarDisplayModeRawValue
                )
            )
            prototypeScenario = .underLimit
            previousScenario = .underLimit
            inactivitySeconds = 120
            isSundownActive = true
            hasStartedSundown = true
            setTrackedWorkSeconds(240 * 60)
            lastNotificationAt = nil
            seedTodayRecord(workMinutes: 240)
            qaStatusMessage = "Applied Healthy Day: under-limit with balanced ritual distribution."

        case .overworkNow:
            settingsStore.save(
                PersistedSettings(
                    dailyLimitMinutes: 480,
                    dayResetMinutesFromMidnight: 240,
                    notificationsEnabled: true,
                    idleThresholdMinutes: 5,
                    overLimitReminderMinutes: 30,
                    menuBarDisplayModeRawValue: persistedSettings.menuBarDisplayModeRawValue
                )
            )
            previousScenario = .underLimit
            prototypeScenario = .overLimit
            inactivitySeconds = 60
            isSundownActive = true
            hasStartedSundown = true
            setTrackedWorkSeconds(545 * 60)
            lastNotificationAt = nil
            seedTodayRecord(workMinutes: 545)
            qaStatusMessage = "Applied Overwork Now: live overwork and today overwork should both be visible."

        case .idleThreshold:
            settingsStore.save(
                PersistedSettings(
                    dailyLimitMinutes: 480,
                    dayResetMinutesFromMidnight: 240,
                    notificationsEnabled: false,
                    idleThresholdMinutes: 5,
                    overLimitReminderMinutes: 30,
                    menuBarDisplayModeRawValue: persistedSettings.menuBarDisplayModeRawValue
                )
            )
            prototypeScenario = .atLimit
            previousScenario = .atLimit
            inactivitySeconds = 300
            isSundownActive = true
            hasStartedSundown = true
            setTrackedWorkSeconds(410 * 60)
            lastNotificationAt = nil
            seedTodayRecord(workMinutes: 410)
            qaStatusMessage = "Applied Idle Threshold: activity should resolve to Idle at threshold."

        case .invalidConfig:
            settingsStore.save(
                PersistedSettings(
                    dailyLimitMinutes: 0,
                    dayResetMinutesFromMidnight: 1_440,
                    notificationsEnabled: true,
                    idleThresholdMinutes: 5,
                    overLimitReminderMinutes: 30,
                    menuBarDisplayModeRawValue: persistedSettings.menuBarDisplayModeRawValue
                )
            )
            prototypeScenario = .overLimit
            previousScenario = .overLimit
            inactivitySeconds = 0
            isSundownActive = false
            hasStartedSundown = false
            setTrackedWorkSeconds(0)
            lastNotificationAt = nil
            dayRecord = nil
            qaStatusMessage = "Applied Invalid Config: gate should show validation error copy."
        }

        reloadSettings()
        objectWillChange.send()
    }

    func simulateReminderReady() {
        lastNotificationAt = Date().addingTimeInterval(-Double(reminderInterval * 60))
        qaStatusMessage = "Reminder-ready state applied. Policy should move toward Send now if over-limit."
    }

    func simulateReminderBlocked() {
        lastNotificationAt = Date()
        qaStatusMessage = "Reminder-blocked state applied. Policy should stay Hold until interval passes."
    }

    func addMinutesToTodayRecord(minutes: Int) {
        guard var record = resolvedDayRecord(now: Date()) else {
            return
        }

        record.add(activity: activity, minutes: minutes)
        dayRecordStore.save(record)
        dayRecord = record
        objectWillChange.send()
    }

    func resetTodayRecord() {
        guard let dayId = timeEngine.dayId(now: Date(), settings: persistedSettings),
              let limitMinutes = persistedSettings.dailyLimitMinutes else {
            return
        }

        let record = DayRecord(dayId: dayId, limitMinutes: limitMinutes)
        dayRecordStore.save(record)
        dayRecord = record
        objectWillChange.send()
    }

    private func reloadSettings() {
        persistedSettings = settingsStore.load()
        objectWillChange.send()
    }

    private func updateSettings(_ update: (inout MutableSettings) -> Void) {
        var mutable = MutableSettings(from: persistedSettings)
        update(&mutable)
        settingsStore.save(mutable.persisted)
        reloadSettings()
    }

    private func resolvedDayRecord(now: Date) -> DayRecord? {
        guard let dayId = timeEngine.dayId(now: now, settings: persistedSettings),
              let limitMinutes = persistedSettings.dailyLimitMinutes else {
            return nil
        }

        if let dayRecord, dayRecord.dayId == dayId {
            return dayRecord
        }

        if let stored = dayRecordStore.load(dayId: dayId) {
            return stored
        }

        return DayRecord(dayId: dayId, limitMinutes: limitMinutes)
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%dh %02dm %02ds", hours, minutes, remainingSeconds)
    }

    private func setDailyLimitComponents(hours: Int, minutes: Int) {
        let totalMinutes = hours * 60 + minutes
        setDailyLimit(totalMinutes)
    }

    private var trackedWorkSeconds: Int? {
        guard hasStartedSundown else {
            return nil
        }

        return trackedWorkSecondsTotal
    }

    private func setupHeartbeat() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.heartbeatTick(now: now)
            }
    }

    private func setupActivityMonitors() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.markUserInteraction()
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            Task { @MainActor in
                self?.markUserInteraction()
            }
        }
    }

    private func setupWakeObserver() {
        wakeObserver = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                let now = Date()
                self.lastTickAt = now
                self.lastInteractionAt = now
                self.inactivitySeconds = 0
            }
    }

    private func markUserInteraction() {
        lastInteractionAt = Date()
        inactivitySeconds = 0
    }

    private func heartbeatTick(now: Date) {
        guard hasStartedSundown else {
            return
        }

        flushTick(now: now)
    }

    private func flushTick(now: Date) {
        let currentInactivity = max(0, Int(now.timeIntervalSince(lastInteractionAt)))
        inactivitySeconds = currentInactivity

        guard isSundownActive else {
            lastTickAt = now
            return
        }

        guard let lastTickAt else {
            self.lastTickAt = now
            return
        }

        let delta = max(0.0, now.timeIntervalSince(lastTickAt))
        self.lastTickAt = now

        if delta > 300 {
            return
        }

        let idleThresholdSeconds = max(1, (persistedSettings.idleThresholdMinutes ?? 5) * 60)
        if currentInactivity >= idleThresholdSeconds {
            return
        }

        trackedSecondsAccumulator += delta
        let wholeSeconds = Int(trackedSecondsAccumulator.rounded(.down))
        if wholeSeconds != trackedWorkSecondsTotal {
            trackedWorkSecondsTotal = wholeSeconds
        }
    }

    private func setTrackedWorkSeconds(_ seconds: Int) {
        let normalized = max(0, seconds)
        trackedSecondsAccumulator = Double(normalized)
        trackedWorkSecondsTotal = normalized
        let now = Date()
        lastTickAt = now
        lastInteractionAt = now
        inactivitySeconds = 0
    }

    private func seedTodayRecord(workMinutes: Int) {
        guard let dayId = timeEngine.dayId(now: Date(), settings: settingsStore.load()),
              let limitMinutes = settingsStore.load().dailyLimitMinutes else {
            dayRecord = nil
            return
        }

        var record = DayRecord(dayId: dayId, limitMinutes: limitMinutes)
        record.add(activity: .work, minutes: workMinutes)
        dayRecordStore.save(record)
        dayRecord = record
    }
}

private enum QAPreset: CaseIterable {
    case firstRunBlocked
    case healthyDay
    case overworkNow
    case idleThreshold
    case invalidConfig

    var label: String {
        switch self {
        case .firstRunBlocked:
            return "First Run Blocked"
        case .healthyDay:
            return "Healthy Day"
        case .overworkNow:
            return "Overwork Now"
        case .idleThreshold:
            return "Idle Threshold"
        case .invalidConfig:
            return "Invalid Config"
        }
    }

    var summary: String {
        switch self {
        case .firstRunBlocked:
            return "Simulates fresh install with missing onboarding values."
        case .healthyDay:
            return "Under-limit workday with normal Work/Break/Idle split."
        case .overworkNow:
            return "Forces live and cumulative overwork visibility with notifications on."
        case .idleThreshold:
            return "Sets inactivity to threshold so activity classification becomes Idle."
        case .invalidConfig:
            return "Injects invalid limit/reset values to validate onboarding error messages."
        }
    }
}

private enum PrototypeScenario: CaseIterable {
    case underLimit
    case atLimit
    case overLimit

    var elapsedSeconds: Int {
        switch self {
        case .underLimit:
            return 26_415
        case .atLimit:
            return 28_800
        case .overLimit:
            return 31_020
        }
    }

    var label: String {
        switch self {
        case .underLimit:
            return "Under"
        case .atLimit:
            return "At"
        case .overLimit:
            return "Over"
        }
    }
}

private struct MutableSettings {
    var dailyLimitMinutes: Int?
    var dayResetMinutesFromMidnight: Int?
    var notificationsEnabled: Bool?
    var idleThresholdMinutes: Int?
    var overLimitReminderMinutes: Int?
    var menuBarDisplayModeRawValue: Int?

    init(from persisted: PersistedSettings) {
        dailyLimitMinutes = persisted.dailyLimitMinutes
        dayResetMinutesFromMidnight = persisted.dayResetMinutesFromMidnight
        notificationsEnabled = persisted.notificationsEnabled
        idleThresholdMinutes = persisted.idleThresholdMinutes
        overLimitReminderMinutes = persisted.overLimitReminderMinutes
        menuBarDisplayModeRawValue = persisted.menuBarDisplayModeRawValue
    }

    var persisted: PersistedSettings {
        PersistedSettings(
            dailyLimitMinutes: dailyLimitMinutes,
            dayResetMinutesFromMidnight: dayResetMinutesFromMidnight,
            notificationsEnabled: notificationsEnabled,
            idleThresholdMinutes: idleThresholdMinutes,
            overLimitReminderMinutes: overLimitReminderMinutes,
            menuBarDisplayModeRawValue: menuBarDisplayModeRawValue
        )
    }
}

private enum UIStyle {
    static let panelBackground = Color(red: 0.95, green: 0.96, blue: 0.94)
    static let cardBackground = Color.white.opacity(0.94)
    static let heroBackground = LinearGradient(
        colors: [Color(red: 0.93, green: 0.95, blue: 0.89), Color.white.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let primaryText = Color(red: 0.08, green: 0.12, blue: 0.10)
    static let subtleText = Color(red: 0.34, green: 0.40, blue: 0.36)
    static let alertText = Color(red: 0.75, green: 0.10, blue: 0.16)
    static let alertBadge = Color(red: 1.0, green: 0.92, blue: 0.92)
    static let neutralBadge = Color(red: 0.90, green: 0.92, blue: 0.90)
}
