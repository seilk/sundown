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
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text("Sundown")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(UIStyle.secondaryText)
                
                Spacer()
                
                Button(action: { model.resetSundownSession() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UIStyle.secondaryText)
                }
                .buttonStyle(HeroGlassButtonStyle())
                .help("Reset Session")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    
                    // MARK: - Status Card
                    VStack(alignment: .leading, spacing: 16) {
                        if model.gateState == .allowed, model.hasStartedSundown, let worktimeState = model.worktimeState {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.worktimeStateFormatter.displayText(for: worktimeState))
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(model.worktimeStateFormatter.isOverLimit(worktimeState) ? UIStyle.alertText : UIStyle.primaryText)
                                    .contentTransition(.numericText())
                                
                                Text(model.isSundownActive ? "Session Active" : "Session Paused")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(model.isSundownActive ? UIStyle.successText : UIStyle.tertiaryText)
                            }
                        } else if model.gateState == .allowed, model.hasStartedSundown, !model.isSundownActive {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Paused")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(UIStyle.secondaryText)
                                
                                Text("Session Paused")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(UIStyle.tertiaryText)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.menuTitle)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(UIStyle.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Session Not Started")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(UIStyle.tertiaryText)
                            }
                        }

                        Divider()
                            .background(UIStyle.borderSubtle)

                        // Controls
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                    Text("WORK LIMIT")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(UIStyle.tertiaryText)
                                        .tracking(0.5)
                                
                                Text(model.limitLabel)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(UIStyle.secondaryText)
                            }
                            
                            Spacer()

                            HStack(spacing: 6) {
                                Button("-30m") {
                                    model.adjustDailyLimit(by: -30)
                                }
                                .buttonStyle(HeroGlassButtonStyle())
                                
                                Button("+30m") {
                                    model.adjustDailyLimit(by: 30)
                                }
                                .buttonStyle(HeroGlassButtonStyle())
                            }
                        }
                        
                        if !model.hasStartedSundown {
                            Button {
                                model.startSundown()
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Sundown")
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(PrimaryButtonStyle())
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
                    .padding(20)
                    .background(UIStyle.heroBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: UIStyle.shadowSubtle, radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(UIStyle.borderSubtle, lineWidth: 1)
                    )

                    // MARK: - Ritual Card
                    VStack(alignment: .center, spacing: 16) {
                        HStack {
                            Text("TODAY'S RITUAL")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(UIStyle.tertiaryText)
                                .tracking(0.5)
                            Spacer()
                        }

                        if model.hasStartedSundown {
                            RitualDonutView(
                                workedSeconds: model.trackedWorkSecondsTotal,
                                limitMinutes: model.currentLimitMinutes
                            )
                            .frame(height: 200)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.system(size: 32))
                                    .foregroundStyle(UIStyle.tertiaryText.opacity(0.5))
                                
                                Text("Complete onboarding in Settings\nto start ritual tracking.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(UIStyle.tertiaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                        }
                    }
                    .padding(20)
                    .background(UIStyle.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: UIStyle.shadowSubtle, radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(UIStyle.borderSubtle, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(UIStyle.panelBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        VStack(alignment: .leading, spacing: 16) {
                            // Quick Presets
                            VStack(alignment: .leading, spacing: 8) {
                                Text("QUICK PRESETS")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(UIStyle.tertiaryText)
                                
                                HStack(spacing: 8) {
                                    Button("6h") { model.setDailyLimit(360) }
                                    Button("8h") { model.setDailyLimit(480) }
                                    Button("10h") { model.setDailyLimit(600) }
                                    Spacer()
                                    Button("Clear") { model.clearOnboardingSettings() }
                                        .foregroundStyle(UIStyle.alertText)
                                }
                                .buttonStyle(HeroGlassButtonStyle())
                            }
                            
                            Divider()
                                .background(UIStyle.borderSubtle)

                            // Manual Time Setting
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("DAILY LIMIT")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(UIStyle.tertiaryText)
                                    Spacer()
                                    Text(model.limitLabel)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(UIStyle.secondaryText)
                                }

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Hours")
                                            .font(.caption)
                                            .foregroundStyle(UIStyle.tertiaryText)
                                        Stepper(value: Binding(
                                            get: { model.dailyLimitHours },
                                            set: { model.setDailyLimitHours($0) }
                                        ), in: 0...23, step: 1) {
                                            Text("\(model.dailyLimitHours)")
                                                .font(.system(.body, design: .rounded))
                                                .monospacedDigit()
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Minutes")
                                            .font(.caption)
                                            .foregroundStyle(UIStyle.tertiaryText)
                                        Stepper(value: Binding(
                                            get: { model.dailyLimitRemainderMinutes },
                                            set: { model.setDailyLimitRemainderMinutes($0) }
                                        ), in: 0...59, step: 1) {
                                            Text("\(model.dailyLimitRemainderMinutes)")
                                                .font(.system(.body, design: .rounded))
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                                .background(UIStyle.borderSubtle)

                            // Other Settings
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("MENU BAR DISPLAY")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(UIStyle.tertiaryText)
                                    
                                    Picker("", selection: Binding(
                                        get: { model.menuBarDisplayMode },
                                        set: { model.setMenuBarDisplayMode($0) }
                                    )) {
                                        ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                                            Text(mode.label).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                }
                                
                                HStack {
                                    Text("Day Reset Time")
                                        .foregroundStyle(UIStyle.secondaryText)
                                    Spacer()
                                    Stepper(value: Binding(
                                        get: { model.persistedSettings.dayResetMinutesFromMidnight ?? 240 },
                                        set: { model.setResetTime($0) }
                                    ), in: 0...1_439, step: 15) {
                                        Text(model.resetLabel)
                                            .monospacedDigit()
                                            .foregroundStyle(UIStyle.primaryText)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .tabItem { Label("Workday", systemImage: "briefcase.fill") }
            .tag(SettingsTab.workday)

            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "Behavior") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("IDLE DETECTION")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(UIStyle.tertiaryText)
                                    Spacer()
                                    Stepper(value: Binding(
                                        get: { model.persistedSettings.idleThresholdMinutes ?? 5 },
                                        set: { model.setIdleThreshold(max(1, $0)) }
                                    ), in: 1...30, step: 1) {
                                        Text("\(model.persistedSettings.idleThresholdMinutes ?? 5) min")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(UIStyle.primaryText)
                                    }
                                    .fixedSize()
                                }
                                
                                Text("Sundown will automatically pause when no activity is detected for this duration.")
                                    .font(.caption)
                                    .foregroundStyle(UIStyle.tertiaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Divider()
                                .background(UIStyle.borderSubtle)
                                
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DEBUG TOOLS")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(UIStyle.tertiaryText)
                                
                                HStack(spacing: 8) {
                                    Button("Set Active Input") { model.setActiveInput() }
                                    Button("Simulate Idle") { model.simulateIdleThresholdCrossing() }
                                }
                                .buttonStyle(HeroGlassButtonStyle())
                                
                                HStack {
                                    Text("Current State:")
                                        .foregroundStyle(UIStyle.secondaryText)
                                    Text(model.activityLabel)
                                        .foregroundStyle(UIStyle.primaryText)
                                        .fontWeight(.medium)
                                }
                                .font(.caption)
                                .padding(.top, 4)
                            }
                        }
                    }

                    SettingsCard(title: "Scenario") {
                        VStack(alignment: .leading, spacing: 12) {
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
                                .monospaced()
                                .foregroundStyle(UIStyle.tertiaryText)
                        }
                    }
                }
            }
            .tabItem { Label("Behavior", systemImage: "figure.walk") }
            .tag(SettingsTab.behavior)

            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "Notifications") {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: Binding(
                                get: { model.persistedSettings.notificationsEnabled ?? false },
                                set: { model.setNotificationsEnabled($0) }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable Notifications")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(UIStyle.primaryText)
                                    Text("Get notified when you exceed your daily limit.")
                                        .font(.caption)
                                        .foregroundStyle(UIStyle.tertiaryText)
                                }
                            }
                            .toggleStyle(.switch)

                            if model.persistedSettings.notificationsEnabled == true {
                                Divider()
                                    .background(UIStyle.borderSubtle)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("REMINDER INTERVAL")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(UIStyle.tertiaryText)
                                        Spacer()
                                        Stepper(value: Binding(
                                            get: { model.persistedSettings.overLimitReminderMinutes ?? 30 },
                                            set: { model.setReminderInterval(max(1, $0)) }
                                        ), in: 1...120, step: 5) {
                                            Text("\(model.reminderInterval) min")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundStyle(UIStyle.primaryText)
                                        }
                                        .fixedSize()
                                    }
                                }
                                
                                Divider()
                                    .background(UIStyle.borderSubtle)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DEBUG")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(UIStyle.tertiaryText)
                                    
                                    HStack(spacing: 8) {
                                        Button("Mark Sent") { model.markNotificationSentNow() }
                                        Button("Clear History") { model.clearNotificationHistory() }
                                    }
                                    .buttonStyle(HeroGlassButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
            .tabItem { Label("Alerts", systemImage: "bell.badge.fill") }
            .tag(SettingsTab.notifications)

            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard(title: "Lab") {
                        Text("Developer mode: quick sandbox for trying edge cases before shipping.")
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
            .tabItem { Label("Lab", systemImage: "testtube.2") }
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
    @State private var isHovering: Bool = false

    private let trackWidth: CGFloat = 64
    private let trackHeight: CGFloat = 34
    private let knobSize: CGFloat = 28

    var body: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)) {
                isPaused.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isPaused ? "Paused" : "Running")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(UIStyle.primaryText)
                    Text(isPaused ? "Session inactive" : "Tracking time")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(UIStyle.tertiaryText)
                }
                
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(isPaused ? UIStyle.borderMedium : UIStyle.successText)
                        .frame(width: trackWidth, height: trackHeight)
                        .shadow(color: isPaused ? Color.clear : UIStyle.successText.opacity(0.3), radius: 6, x: 0, y: 3)

                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                        .offset(x: isPaused ? -(trackWidth - knobSize) / 2 + 3 : (trackWidth - knobSize) / 2 - 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isHovering ? UIStyle.cardBackground.opacity(0.8) : UIStyle.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isHovering ? UIStyle.borderSubtle.opacity(0.8) : UIStyle.borderSubtle, lineWidth: 1)
            )
            .shadow(color: UIStyle.shadowSubtle.opacity(isHovering ? 0.8 : 0.5), radius: isHovering ? 12 : 8, x: 0, y: isHovering ? 4 : 2)
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonView(configuration: configuration)
    }

    private struct PrimaryButtonView: View {
        let configuration: Configuration
        @State private var isHovering: Bool = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(UIStyle.sunsetGradient)
                        .brightness(isHovering ? 0.08 : 0.0)
                        .saturation(isHovering ? 1.1 : 1.0)
                )
                .foregroundStyle(Color.white)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(isHovering && !configuration.isPressed ? 1.02 : (configuration.isPressed ? 0.98 : 1.0))
                .shadow(
                    color: UIStyle.sunsetOrange.opacity(isHovering ? 0.5 : 0.3),
                    radius: isHovering ? 12 : 8,
                    x: 0,
                    y: isHovering ? 6 : 4
                )
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHovering = hovering
                    }
                }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

private struct HeroGlassButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HeroGlassButtonView(configuration: configuration, prominent: prominent)
    }

    private struct HeroGlassButtonView: View {
        let configuration: Configuration
        let prominent: Bool
        @State private var isHovering: Bool = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: isHovering ? 1.5 : 1)
                )
                .foregroundStyle(foregroundColor)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .shadow(
                    color: isHovering ? UIStyle.sunsetOrange.opacity(0.26) : Color.clear,
                    radius: isHovering ? 8 : 0,
                    x: 0,
                    y: isHovering ? 3 : 0
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovering = hovering
                    }
                }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }

        private var backgroundColor: Color {
            if prominent {
                return isHovering ? UIStyle.sunsetPink.opacity(0.28) : UIStyle.sunsetOrange.opacity(0.2)
            } else {
                return isHovering ? UIStyle.sunsetPink.opacity(0.2) : UIStyle.sunsetOrange.opacity(0.12)
            }
        }

        private var borderColor: Color {
            if isHovering {
                return UIStyle.sunsetPink.opacity(0.82)
            } else {
                return UIStyle.sunsetOrange.opacity(0.62)
            }
        }

        private var foregroundColor: Color {
            if prominent {
                return isHovering ? UIStyle.sunsetPink : UIStyle.sunsetOrange
            }

            return isHovering ? UIStyle.sunsetPink : UIStyle.sunsetOrange
        }
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
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(UIStyle.borderSubtle, lineWidth: 1)
        )
        .shadow(color: UIStyle.shadowSubtle, radius: 6, x: 0, y: 2)
    }
}

@MainActor
private final class SundownViewModel: ObservableObject {
    let worktimeStateFormatter = WorktimeStateFormatter()

    private let onboardingGateEvaluator = OnboardingGateEvaluator()
    private let overLimitNotificationPolicy = OverLimitNotificationPolicy()
    private let durationFormatter = WorktimeDurationFormatter()
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

    private let defaultDayResetMinutes = 240

    init(
        notificationService: NotificationService = UserNotificationCenterService(),
        settingsStore: UserDefaultsSettingsStore = UserDefaultsSettingsStore(),
        dayRecordStore: UserDefaultsDayRecordStore = UserDefaultsDayRecordStore()
    ) {
        self.notificationService = notificationService
        self.settingsStore = settingsStore
        self.dayRecordStore = dayRecordStore
        self.persistedSettings = settingsStore.load()

        normalizeOnboardingDefaultsIfNeeded()

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
            return UIStyle.activeBlue
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
            hasStartedSundown: hasStartedSundown,
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
            if settings.dayResetMinutesFromMidnight == nil {
                settings.dayResetMinutesFromMidnight = defaultDayResetMinutes
            }
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
        let current = persistedSettings.notificationsEnabled ?? false
        guard current != enabled else {
            return
        }

        updateSettings { settings in
            settings.notificationsEnabled = enabled
        }

        if enabled {
            Task { @MainActor [notificationService] in
                notificationService.requestAuthorizationIfNeeded()
            }
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

    private func normalizeOnboardingDefaultsIfNeeded() {
        guard persistedSettings.dailyLimitMinutes != nil,
              persistedSettings.dayResetMinutesFromMidnight == nil else {
            return
        }

        updateSettings { settings in
            settings.dayResetMinutesFromMidnight = defaultDayResetMinutes
        }
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
        durationFormatter.detailedDuration(seconds: seconds)
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
        let latestSettings = settingsStore.load()
        guard let dayId = timeEngine.dayId(now: Date(), settings: latestSettings),
              let limitMinutes = latestSettings.dailyLimitMinutes else {
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

enum UIStyle {
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let heroBackground = LinearGradient(
        colors: [
            Color(nsColor: .underPageBackgroundColor),
            Color(nsColor: .controlBackgroundColor)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let subtleText = Color(nsColor: .quaternaryLabelColor)
    
    static let borderSubtle = Color(nsColor: .separatorColor).opacity(0.45)
    static let borderMedium = Color(nsColor: .separatorColor).opacity(0.78)
    
    static let alertText = Color(nsColor: .systemRed)
    static let successText = Color(nsColor: .systemGreen)
    static let activeBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let accentCyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let warningAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    

    // Sunset Palette
    static let sunsetOrange = Color(red: 1.0, green: 0.35, blue: 0.25)
    static let sunsetPink = Color(red: 1.0, green: 0.20, blue: 0.45)
    static let sunsetGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.45, blue: 0.35),
            Color(red: 1.0, green: 0.25, blue: 0.50)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // Shadows
    static let shadowSubtle = Color.black.opacity(0.04)
    static let shadowDeep = Color.black.opacity(0.12)
}
