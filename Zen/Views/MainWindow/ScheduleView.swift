import SwiftUI

private let dayStartHour = 4
private let totalMinutesInDay = 1440
private let rowPitch: CGFloat = 45 // 44px row + 1px divider
private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
private let blockColors: [Color] = [
    .blue.opacity(0.7), .green.opacity(0.7), .orange.opacity(0.7),
    .purple.opacity(0.7), .pink.opacity(0.7), .teal.opacity(0.7),
    .indigo.opacity(0.7), .mint.opacity(0.7), .brown.opacity(0.7),
]

private func toDisplayMinutes(_ abs: Int) -> Int {
    (abs - dayStartHour * 60 + totalMinutesInDay) % totalMinutesInDay
}
private func toAbsoluteMinutes(_ disp: Int) -> Int {
    (disp + dayStartHour * 60) % totalMinutesInDay
}
private func snapHour(_ m: Int) -> Int {
    Int(round(Double(m) / 60.0)) * 60
}

/// Clipboard entry: mood + time range (day-independent)
private struct ClipboardBlock {
    let moodId: UUID
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}

/// Returns ISO weekday (1=Mon...7=Sun) and display-minutes for right now
private func currentTimeInfo() -> (day: Int, displayMinutes: Int) {
    let cal = Calendar.current
    let now = Date()
    var isoDay = cal.component(.weekday, from: now) - 1 // Sun=0..Sat=6
    if isoDay == 0 { isoDay = 7 } // Sun=7
    let hour = cal.component(.hour, from: now)
    let minute = cal.component(.minute, from: now)
    let absMinutes = hour * 60 + minute
    return (isoDay, toDisplayMinutes(absMinutes))
}

struct ScheduleView: View {
    @ObservedObject private var store = MoodStore.shared
    @State private var selectedBlockId: String? = nil
    @State private var errorMessage: String? = nil
    @State private var toastMessage: String? = nil
    @State private var dropPreview: (day: Int, displayStart: Int, moodIndex: Int)? = nil
    @State private var clipboard: [ClipboardBlock]? = nil
    @State private var hoveredDay: Int? = nil
    @State private var copiedFromDay: Int? = nil
    @State private var now = currentTimeInfo()
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    @ObservedObject private var settings = AppSettings.shared
    @State private var scheduleOnboardingStep = 0
    @State private var showOutsideBlocksHelp = false

    private var showScheduleOnboarding: Bool {
        !settings.scheduleOnboardingComplete
    }

    private var inactiveBehaviorBinding: Binding<String> {
        Binding(
            get: { settings.inactiveBehavior },
            set: { settings.inactiveBehavior = $0 }
        )
    }

    var body: some View {
        ZStack {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .center, spacing: 10) {
                    Text("Schedule")
                        .font(.title2.weight(.medium))

                    Toggle("", isOn: $settings.scheduleEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .tint(Color(red: 0.91, green: 0.57, blue: 0.23))

                    Text(settings.scheduleEnabled ? "activated" : "inactivated")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    // Outside blocks — fades in/out with activation
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Text("Outside blocks")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Button {
                                showOutsideBlocksHelp.toggle()
                            } label: {
                                Text("?")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 14, height: 14)
                                    .background(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        Picker("", selection: inactiveBehaviorBinding) {
                            Text("Pause (nothing)").tag("pause")
                            Divider()
                            ForEach(store.moods) { mood in
                                Text("\(mood.icon) \(mood.name)").tag(mood.id.uuidString)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        .font(.system(size: 11))
                    }
                    .opacity(settings.scheduleEnabled ? 1 : 0)
                    .allowsHitTesting(settings.scheduleEnabled)
                    .animation(.easeInOut(duration: 0.3), value: settings.scheduleEnabled)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                timelineGrid
                    .opacity(settings.scheduleEnabled ? 1 : 0.5)
                    .allowsHitTesting(settings.scheduleEnabled)
                    .animation(.easeInOut(duration: 0.3), value: settings.scheduleEnabled)

                if let error = errorMessage {
                    HStack {
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.red.opacity(0.1)))
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }

                if let toast = toastMessage {
                    HStack {
                        Spacer()
                        Text(toast)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }

            Divider()

            moodSidebar
                .frame(width: 150)
                .opacity(settings.scheduleEnabled ? 1 : 0.5)
                .allowsHitTesting(settings.scheduleEnabled)
                .animation(.easeInOut(duration: 0.3), value: settings.scheduleEnabled)
        }
        .onDeleteCommand { deleteSelectedBlock() }
        .onExitCommand { exitPasteMode(); selectedBlockId = nil }
        .onReceive(minuteTimer) { _ in now = currentTimeInfo() }

            if showScheduleOnboarding {
                scheduleOnboardingOverlay
            }

            // Outside blocks tooltip
            if showOutsideBlocksHelp {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { showOutsideBlocksHelp = false }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Outside blocks")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Button {
                            showOutsideBlocksHelp = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                                .background(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5).frame(width: 16, height: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("This controls what Zen does during hours with no block scheduled. For example, if you have Morning set from 6–10 and Evening from 17–22, what should happen at 14:00?\n\nPick a mood to keep its quotes and reminders active, or choose pause to go quiet.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(width: 280)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.7))
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        } // ZStack
        .animation(.easeOut(duration: 0.2), value: showOutsideBlocksHelp)
    }

    // MARK: - Timeline Grid

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            // Hour header
            HStack(spacing: 0) {
                Text("").frame(width: 30)
                GeometryReader { geo in
                    let pph = geo.size.width / 24.0
                    ForEach(0..<13) { i in
                        let displayHour = i * 2
                        let actualHour = (dayStartHour + displayHour) % 24
                        Text(String(format: "%02d", actualHour))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .position(x: CGFloat(displayHour) * pph, y: 8)
                    }
                }
                Text("").frame(width: 32)
            }
            .frame(height: 20)

            ForEach(1...7, id: \.self) { day in
                let dayBlocks = store.allScheduleBlocks().filter { $0.day == day }
                DayRow(
                    day: day,
                    blocks: dayBlocks,
                    selectedBlockId: $selectedBlockId,
                    dropPreview: dropPreview?.day == day ? (dropPreview!.displayStart, dropPreview!.moodIndex) : nil,
                    isToday: now.day == day,
                    nowDisplayMinutes: now.day == day ? now.displayMinutes : nil,
                    pasteMode: copiedFromDay != nil && copiedFromDay != day,
                    hasBlocks: !dayBlocks.isEmpty,
                    store: store,
                    onDrop: { moodId, displayMinutes in handleDrop(moodId: moodId, day: day, displayMinutes: displayMinutes) },
                    onDropPreview: { moodIndex, displayMinutes in
                        dropPreview = (day: day, displayStart: displayMinutes, moodIndex: moodIndex)
                    },
                    onDropExit: { dropPreview = nil },
                    onReceiveBlock: { moodId, scheduleId, fromDay in
                        moveBlockToDay(moodId: moodId, scheduleId: scheduleId, fromDay: fromDay, toDay: day)
                    },
                    onDeselect: { exitPasteMode(); selectedBlockId = nil },
                    onCopyRow: { copyRow(day: day) },
                    onClearRow: { clearRow(day: day) },
                    onPasteRow: { pasteRow(toDay: day) },
                    hoveredDay: $hoveredDay
                )
                Divider()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Sidebar

    private var moodSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Moods")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(store.moods.enumerated()), id: \.element.id) { idx, mood in
                        SidebarMoodItem(mood: mood, colorIndex: idx)
                    }
                }
                .padding(.horizontal, 8)
            }

            Text("drag into calendar")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            Spacer()
        }
    }

    // MARK: - Schedule Onboarding

    @State private var scheduleOnboardingAppeared = true

    private let schedZenOrange = Color(red: 0.91, green: 0.57, blue: 0.23)
    private let schedZenOrangeBg = Color(red: 0.996, green: 0.953, blue: 0.902)

    private var scheduleOnboardingOverlay: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 0.95))
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Group {
                    switch scheduleOnboardingStep {
                    case 0:
                        VStack(spacing: 14) {
                            schedIconCircle("calendar")
                            Text("Different moods, different times")
                                .font(.system(size: 20, weight: .light, design: .serif))
                                .tracking(-0.5)
                            Text("Set different moods for different\ntimes of day and days of the week.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    case 1:
                        VStack(spacing: 14) {
                            schedIconCircle("hand.draw")
                            Text("Drag and resize")
                                .font(.system(size: 20, weight: .light, design: .serif))
                                .tracking(-0.5)
                            Text("Drag a mood from the sidebar into\nthe calendar. Resize by dragging the edges.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    case 2:
                        VStack(spacing: 14) {
                            schedIconCircle("doc.on.doc")
                            Text("Copy and paste")
                                .font(.system(size: 20, weight: .light, design: .serif))
                                .tracking(-0.5)
                            Text("Use the copy button on each day row\nto duplicate blocks to another day.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    case 3:
                        VStack(spacing: 14) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(schedZenOrange)
                                .frame(width: 48, height: 48)
                                .background(schedZenOrangeBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("That's it")
                                .font(.system(size: 20, weight: .light, design: .serif))
                                .tracking(-0.5)
                            Text("Enable the toggle when you're ready.\nZen handles the rest.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    default: EmptyView()
                    }
                }
                .opacity(scheduleOnboardingAppeared ? 1 : 0)
                .blur(radius: scheduleOnboardingAppeared ? 0 : 3)
                .offset(y: scheduleOnboardingAppeared ? 0 : 8)

                if scheduleOnboardingStep < 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { scheduleOnboardingAppeared = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scheduleOnboardingStep += 1
                            withAnimation(.easeOut(duration: 0.5).delay(0.05)) { scheduleOnboardingAppeared = true }
                        }
                    } label: {
                        Text("Next")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            settings.scheduleOnboardingComplete = true
                        }
                    } label: {
                        Text("Got it")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.04, green: 0.04, blue: 0.04)))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i == scheduleOnboardingStep ? schedZenOrange.opacity(0.8) : Color.primary.opacity(0.08))
                            .frame(width: i == scheduleOnboardingStep ? 6 : 5, height: i == scheduleOnboardingStep ? 6 : 5)
                            .animation(.easeInOut(duration: 0.4), value: scheduleOnboardingStep)
                    }
                }
                .padding(.top, 2)
            }
        }
        .transition(.opacity)
    }

    private func schedTagPill(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func schedIconCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .light))
            .foregroundStyle(schedZenOrange)
            .frame(width: 48, height: 48)
            .background(schedZenOrangeBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func deleteSelectedBlock() {
        guard let blockId = selectedBlockId,
              let block = store.allScheduleBlocks().first(where: { $0.id == blockId }) else { return }
        HapticService.playLevelChange()
        store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: block.day)
        selectedBlockId = nil
    }

    private func moveBlockToDay(moodId: UUID, scheduleId: UUID, fromDay: Int, toDay: Int) {
        guard fromDay != toDay else { return }
        guard let moodIdx = store.moods.firstIndex(where: { $0.id == moodId }),
              let schedIdx = store.moods[moodIdx].schedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        let sched = store.moods[moodIdx].schedules[schedIdx]
        // Add to new day
        store.addScheduleBlock(moodId: moodId, day: toDay,
                               startHour: sched.startHour, startMinute: sched.startMinute,
                               endHour: sched.endHour, endMinute: sched.endMinute)
        // Remove from old day
        store.removeScheduleBlock(moodId: moodId, scheduleId: scheduleId, day: fromDay)
        HapticService.playLevelChange()
    }

    private func exitPasteMode() {
        copiedFromDay = nil
        clipboard = nil
    }

    private func copyRow(day: Int) {
        let blocks = store.allScheduleBlocks().filter { $0.day == day }
        guard !blocks.isEmpty else { return }
        clipboard = blocks.map { b in
            ClipboardBlock(
                moodId: b.moodId,
                startHour: b.startMinutes / 60,
                startMinute: b.startMinutes % 60,
                endHour: b.endMinutes / 60,
                endMinute: b.endMinutes % 60
            )
        }
        copiedFromDay = day
        selectedBlockId = nil
        HapticService.playGeneric()
        withAnimation(.easeOut(duration: 0.2)) { toastMessage = "Copied \(dayLabels[day - 1]) — tap a row to paste" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.3)) { toastMessage = nil }
        }
    }

    private func clearRow(day: Int) {
        let blocks = store.allScheduleBlocks().filter { $0.day == day }
        for block in blocks {
            store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: block.day)
        }
        selectedBlockId = nil
        HapticService.playLevelChange()
        withAnimation(.easeOut(duration: 0.2)) { toastMessage = "Cleared \(dayLabels[day - 1])" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) { toastMessage = nil }
        }
    }

    private func pasteRow(toDay: Int) {
        guard let entries = clipboard else { return }
        // Clear existing blocks on target day
        let existing = store.allScheduleBlocks().filter { $0.day == toDay }
        for block in existing {
            store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: block.day)
        }
        // Add clipboard blocks
        for entry in entries {
            store.addScheduleBlock(
                moodId: entry.moodId, day: toDay,
                startHour: entry.startHour, startMinute: entry.startMinute,
                endHour: entry.endHour, endMinute: entry.endMinute
            )
        }
        HapticService.playGeneric()
        withAnimation(.easeOut(duration: 0.2)) { toastMessage = "Pasted to \(dayLabels[toDay - 1])" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) { toastMessage = nil }
        }
    }

    private func handleDrop(moodId: UUID, day: Int, displayMinutes: Int) {
        dropPreview = nil
        let snapped = snapHour(displayMinutes)
        let absStart = toAbsoluteMinutes(snapped)
        let absEnd = toAbsoluteMinutes(snapped + 180) // 3 hours default

        let dayBlocks = store.allScheduleBlocks().filter { $0.day == day }
        let hasConflict = dayBlocks.contains { $0.startMinutes < absEnd && absStart < $0.endMinutes }

        if !hasConflict {
            HapticService.playGeneric()
            store.addScheduleBlock(moodId: moodId, day: day,
                                   startHour: absStart / 60, startMinute: absStart % 60,
                                   endHour: absEnd / 60, endMinute: absEnd % 60)
            return
        }

        // Try before first conflict
        let sorted = dayBlocks.sorted { $0.startMinutes < $1.startMinutes }
        if let first = sorted.first(where: { $0.startMinutes < absEnd && absStart < $0.endMinutes }) {
            let beforeEnd = first.startMinutes
            let beforeStart = beforeEnd - 180
            if beforeStart >= dayStartHour * 60 &&
               !dayBlocks.contains(where: { $0.startMinutes < beforeEnd && beforeStart < $0.endMinutes }) {
                HapticService.playGeneric()
                store.addScheduleBlock(moodId: moodId, day: day,
                                       startHour: beforeStart / 60, startMinute: beforeStart % 60,
                                       endHour: beforeEnd / 60, endMinute: beforeEnd % 60)
                return
            }
        }

        // Try after last conflict
        if let last = sorted.last(where: { $0.startMinutes < absEnd && absStart < $0.endMinutes }) {
            let afterStart = last.endMinutes
            let afterEnd = afterStart + 180
            if afterEnd <= (dayStartHour + 24) * 60 &&
               !dayBlocks.contains(where: { $0.startMinutes < afterEnd && afterStart < $0.endMinutes }) {
                HapticService.playGeneric()
                store.addScheduleBlock(moodId: moodId, day: day,
                                       startHour: (afterStart % 1440) / 60, startMinute: afterStart % 60,
                                       endHour: (afterEnd % 1440) / 60, endMinute: afterEnd % 60)
                return
            }
        }

        withAnimation(.easeOut(duration: 0.2)) { errorMessage = "No room on \(dayLabels[day - 1])" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeIn(duration: 0.3)) { errorMessage = nil }
        }
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let day: Int
    let blocks: [MoodStore.ScheduleBlock]
    @Binding var selectedBlockId: String?
    let dropPreview: (displayStart: Int, moodIndex: Int)?
    let isToday: Bool
    let nowDisplayMinutes: Int?
    let pasteMode: Bool
    let hasBlocks: Bool
    let store: MoodStore
    let onDrop: (UUID, Int) -> Void
    let onDropPreview: (Int, Int) -> Void
    let onDropExit: () -> Void
    let onReceiveBlock: (UUID, UUID, Int) -> Void // moodId, scheduleId, fromDay
    let onDeselect: () -> Void
    let onCopyRow: () -> Void
    let onClearRow: () -> Void
    let onPasteRow: () -> Void
    @Binding var hoveredDay: Int?
    @State private var isTargeted = false
    @State private var isRowHovered = false
    @State private var rowWidth: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            // Day label
            Text(dayLabels[day - 1])
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? .primary : .secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                let pph = geo.size.width / 24.0

                // Today background highlight
                if isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.04))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Grid lines
                ForEach(0..<25) { hour in
                    Rectangle()
                        .fill(Color.primary.opacity(hour % 6 == 0 ? 0.08 : 0.03))
                        .frame(width: 1, height: geo.size.height)
                        .position(x: CGFloat(hour) * pph, y: geo.size.height / 2)
                }

                // Current time indicator
                if let nowMin = nowDisplayMinutes {
                    let nowX = CGFloat(nowMin) / 60.0 * pph
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 1.5, height: geo.size.height)
                        .position(x: nowX, y: geo.size.height / 2)
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .position(x: nowX, y: 2.5)
                }

                // Ghost preview
                if let preview = dropPreview {
                    let ghostX = CGFloat(preview.displayStart) / 60.0 * pph
                    let ghostW = pph * 3 // 3 hours
                    RoundedRectangle(cornerRadius: 5)
                        .fill(blockColors[preview.moodIndex % blockColors.count].opacity(0.3))
                        .frame(width: ghostW, height: geo.size.height - 8)
                        .position(x: ghostX + ghostW / 2, y: geo.size.height / 2)
                }

                // Blocks
                ForEach(blocks) { (block: MoodStore.ScheduleBlock) in
                    let displayStart = toDisplayMinutes(block.startMinutes)
                    let duration = block.endMinutes - block.startMinutes // always positive
                    let blockX = CGFloat(displayStart) / 60.0 * pph
                    let blockW = max(CGFloat(duration) / 60.0 * pph, 20)

                    ScheduleBlockView(
                        block: block,
                        blockX: blockX,
                        blockW: blockW,
                        pph: pph,
                        rowHeight: geo.size.height,
                        isSelected: selectedBlockId == block.id,
                        onSelect: { selectedBlockId = block.id },
                        onMove: { newDisplayStart in
                            let dur = block.endMinutes - block.startMinutes
                            let absStart = toAbsoluteMinutes(newDisplayStart)
                            let absEndNorm = (absStart + dur) % 1440
                            store.updateScheduleTime(
                                moodId: block.moodId, scheduleId: block.scheduleId,
                                startHour: absStart / 60, startMinute: absStart % 60,
                                endHour: absEndNorm / 60, endMinute: absEndNorm % 60
                            )
                            HapticService.playGeneric()
                        },
                        onResize: { newAbsStart, newAbsEnd in
                            let s = newAbsStart % 1440
                            let e = newAbsEnd % 1440
                            store.updateScheduleTime(
                                moodId: block.moodId, scheduleId: block.scheduleId,
                                startHour: s / 60, startMinute: s % 60,
                                endHour: e / 60, endMinute: e % 60
                            )
                            HapticService.playGeneric()
                        },
                        onDelete: {
                            HapticService.playLevelChange()
                            store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: block.day)
                            if selectedBlockId == block.id { selectedBlockId = nil }
                        },
                        onRowChange: { newDay in
                            guard newDay >= 1 && newDay <= 7 && newDay != day else { return }
                            // Move block from this day to newDay
                            let sched = store.moods.first(where: { $0.id == block.moodId })?
                                .schedules.first(where: { $0.id == block.scheduleId })
                            guard let s = sched else { return }
                            store.addScheduleBlock(moodId: block.moodId, day: newDay,
                                                   startHour: s.startHour, startMinute: s.startMinute,
                                                   endHour: s.endHour, endMinute: s.endMinute)
                            store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: day)
                            HapticService.playLevelChange()
                        }
                    )
                }

                if pasteMode {
                    pasteOverlay(geo: geo)
                }
            }
            .coordinateSpace(name: "dayRow")
            .background(Color.clear.contentShape(Rectangle()).onTapGesture { onDeselect() })
            .background(isTargeted ? Color.accentColor.opacity(0.04) : Color.clear)
            .background(GeometryReader { geo in Color.clear.onAppear { rowWidth = geo.size.width } })
            .dropDestination(for: String.self) { items, location in
                guard let payload = items.first else { return false }

                // Check if it's a cross-row move (format: "move:moodId:scheduleId:fromDay")
                if payload.hasPrefix("move:") {
                    let parts = payload.split(separator: ":")
                    guard parts.count == 4,
                          let moodId = UUID(uuidString: String(parts[1])),
                          let scheduleId = UUID(uuidString: String(parts[2])),
                          let fromDay = Int(parts[3]) else { return false }
                    onReceiveBlock(moodId, scheduleId, fromDay)
                    return true
                }

                // Normal sidebar drop
                guard let moodId = UUID(uuidString: payload) else { return false }
                let displayMinutes = snapHour(Int(location.x / rowWidth * 24 * 60))
                onDrop(moodId, displayMinutes)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
                if !targeted { onDropExit() }
            }

            // Row menu — always visible
            RowMenuButton(
                hasBlocks: hasBlocks,
                onCopy: onCopyRow,
                onClear: onClearRow
            )
        }
        .frame(height: 44)
        .onHover { h in
            isRowHovered = h
            hoveredDay = h ? day : nil
        }
    }

    @ViewBuilder
    private func pasteOverlay(geo: GeometryProxy) -> some View {
        let label = hasBlocks ? "Clear & paste" : "Paste here"
        // Tappable background — dismisses paste mode
        Color.clear
            .contentShape(Rectangle())
            .frame(width: geo.size.width, height: geo.size.height)
            .onTapGesture { onDeselect() }
            .overlay(
                Button { onPasteRow() } label: {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            )
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.04)))
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
    }
}

// MARK: - Row Menu Button

private struct RowMenuButton: View {
    let hasBlocks: Bool
    let onCopy: () -> Void
    let onClear: () -> Void
    @State private var isHovered = false

    var body: some View {
        Menu {
            if hasBlocks {
                Button {
                    HapticService.playGeneric()
                    onCopy()
                } label: {
                    Label("Copy row", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    HapticService.playLevelChange()
                    onClear()
                } label: {
                    Label("Clear row", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHovered ? .secondary : .tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onHover { h in isHovered = h }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, 6)
        .frame(width: 32)
    }
}

// MARK: - Schedule Block

private struct ScheduleBlockView: View {
    let block: MoodStore.ScheduleBlock
    let blockX: CGFloat
    let blockW: CGFloat
    let pph: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (Int) -> Void
    let onResize: (Int, Int) -> Void
    let onDelete: () -> Void
    let onRowChange: (Int) -> Void // newDay

    @State private var isHovered = false
    @State private var xHovered = false

    private struct DragState: Equatable {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var mode: Mode = .body
        enum Mode: Equatable { case body, leftResize, rightResize }
    }
    @GestureState private var drag = DragState()

    private var isDragging: Bool { drag.dx != 0 || drag.dy != 0 }

    private var color: Color { blockColors[block.moodIndex % blockColors.count] }

    private static let edgeZone: CGFloat = 7

    /// Minimum width (in px) to show text content — roughly 2 hours
    private var showsContent: Bool { liveW > pph * 2 - 5 }

    private var liveX: CGFloat {
        switch drag.mode {
        case .body, .leftResize: return blockX + drag.dx
        case .rightResize: return blockX
        }
    }
    private var liveW: CGFloat {
        switch drag.mode {
        case .body: return blockW
        case .leftResize: return max(blockW - drag.dx, 20)
        case .rightResize: return max(blockW + drag.dx, 20)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Body
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )

            // Content
            if showsContent {
                if isDragging && drag.mode == .body {
                    Text("drop it like it's hot")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 3) {
                        Text(block.moodIcon).font(.system(size: 11))
                        Text(block.moodName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                }
            }

            // Delete X
            if isHovered && !isDragging {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Color.black.opacity(xHovered ? 0.6 : 0.35)))
                }
                .buttonStyle(.plain)
                .onHover { h in xHovered = h }
                .offset(x: -3, y: 3)
                .transition(.opacity)
                .zIndex(10)
            }

            // Resize handle highlights (visual only — gesture is unified below)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0))
                    .frame(width: Self.edgeZone)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0))
                    .frame(width: Self.edgeZone)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
            }
        }
        .frame(width: liveW, height: rowHeight - 8)
        .contentShape(Rectangle())
        .opacity(isHovered ? 1.0 : 0.85)
        .onHover { h in isHovered = h }
        .onTapGesture { onSelect() }
        // Unified gesture — detects edge vs body from start location
        .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("dayRow"))
                .updating($drag) { v, state, _ in
                    let mode: DragState.Mode
                    if state.dx == 0 && state.dy == 0 {
                        // First update — determine mode from start position + drag direction
                        let relX = v.startLocation.x - blockX
                        let horizontal = abs(v.translation.width) > abs(v.translation.height)
                        if relX < Self.edgeZone && horizontal {
                            mode = .leftResize
                        } else if relX > blockW - Self.edgeZone && horizontal {
                            mode = .rightResize
                        } else {
                            mode = .body
                        }
                    } else {
                        mode = state.mode
                    }
                    state = DragState(dx: v.translation.width, dy: v.translation.height, mode: mode)
                }
                .onEnded { v in
                    let relX = v.startLocation.x - blockX
                    let horizontal = abs(v.translation.width) > abs(v.translation.height)
                    let mode: DragState.Mode
                    if relX < Self.edgeZone && horizontal { mode = .leftResize }
                    else if relX > blockW - Self.edgeZone && horizontal { mode = .rightResize }
                    else { mode = .body }

                    // All operations work in display minutes (0–1440 relative to dayStartHour)
                    let dispStart = toDisplayMinutes(block.startMinutes)
                    let dur = block.endMinutes - block.startMinutes // always positive

                    switch mode {
                    case .body:
                        let delta = snapHour(Int(v.translation.width / pph * 60))
                        let snapped = snapHour(dispStart + delta)
                        let clampedStart = max(0, min(totalMinutesInDay - dur, snapped))
                        onMove(clampedStart)
                        HapticService.playAlignment()
                        let rowShift = Int(round(v.translation.height / rowPitch))
                        if rowShift != 0 {
                            let newDay = block.day + rowShift
                            if newDay >= 1 && newDay <= 7 { onRowChange(newDay) }
                        }
                    case .leftResize:
                        let delta = snapHour(Int(v.translation.width / pph * 60))
                        let newDispStart = max(0, snapHour(dispStart + delta))
                        let newDispEnd = dispStart + dur // keep original end
                        if newDispStart < newDispEnd - 59 {
                            let absS = toAbsoluteMinutes(newDispStart)
                            let absE = toAbsoluteMinutes(newDispEnd)
                            onResize(absS, absE)
                        }
                        HapticService.playAlignment()
                    case .rightResize:
                        let delta = snapHour(Int(v.translation.width / pph * 60))
                        let dispEnd = dispStart + dur
                        let newDispEnd = min(totalMinutesInDay, snapHour(dispEnd + delta))
                        if newDispEnd > dispStart + 59 {
                            let absS = toAbsoluteMinutes(dispStart)
                            let absE = toAbsoluteMinutes(newDispEnd)
                            onResize(absS, absE)
                        }
                        HapticService.playAlignment()
                    }
                }
        )
        .position(
            x: liveX + liveW / 2,
            y: rowHeight / 2 + (drag.mode == .body ? round(drag.dy / rowPitch) * rowPitch : 0)
        )
        .contextMenu {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Sidebar Mood Item

private struct SidebarMoodItem: View {
    let mood: Mood
    let colorIndex: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(blockColors[colorIndex % blockColors.count])
                .frame(width: 8, height: 8)
            Text(mood.icon).font(.system(size: 14))
            Text(mood.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Text("⠿")
                .font(.system(size: 14))
                .foregroundStyle(isHovered ? .secondary : .quaternary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(isHovered ? 0.05 : 0)))
        .onHover { h in isHovered = h }
        .cursor(isHovered ? .openHand : .arrow)
        .draggable(mood.id.uuidString)
    }
}

// MARK: - Cursor Helper

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering { cursor.push() }
            else { NSCursor.pop() }
        }
    }
}
