import SwiftUI

private let dayStartHour = 4
private let totalMinutesInDay = 1440
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
private func snap30(_ m: Int) -> Int {
    Int(round(Double(m) / 30.0)) * 30
}

struct ScheduleView: View {
    @ObservedObject private var store = MoodStore.shared
    @State private var selectedBlockId: String? = nil
    @State private var errorMessage: String? = nil
    @State private var dropPreview: (day: Int, displayStart: Int, moodIndex: Int)? = nil

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Schedule")
                    .font(.title2.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                timelineGrid

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
            }

            Divider()

            moodSidebar
                .frame(width: 150)
        }
        .onDeleteCommand { deleteSelectedBlock() }
    }

    // MARK: - Timeline Grid

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            // Hour header
            HStack(spacing: 0) {
                Text("").frame(width: 50)
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
            }
            .frame(height: 20)

            ForEach(1...7, id: \.self) { day in
                DayRow(
                    day: day,
                    blocks: store.allScheduleBlocks().filter { $0.day == day },
                    selectedBlockId: $selectedBlockId,
                    dropPreview: dropPreview?.day == day ? (dropPreview!.displayStart, dropPreview!.moodIndex) : nil,
                    store: store,
                    onDrop: { moodId, displayMinutes in handleDrop(moodId: moodId, day: day, displayMinutes: displayMinutes) },
                    onDropPreview: { moodIndex, displayMinutes in
                        dropPreview = (day: day, displayStart: displayMinutes, moodIndex: moodIndex)
                    },
                    onDropExit: { dropPreview = nil },
                    onReceiveBlock: { moodId, scheduleId, fromDay in
                        moveBlockToDay(moodId: moodId, scheduleId: scheduleId, fromDay: fromDay, toDay: day)
                    }
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
            Spacer()
        }
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

    private func handleDrop(moodId: UUID, day: Int, displayMinutes: Int) {
        dropPreview = nil
        let snapped = snap30(displayMinutes)
        let absStart = toAbsoluteMinutes(snapped)
        let absEnd = toAbsoluteMinutes(snapped + 120) // 2 hours default

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
            let beforeStart = beforeEnd - 120
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
            let afterEnd = afterStart + 120
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
    let store: MoodStore
    let onDrop: (UUID, Int) -> Void
    let onDropPreview: (Int, Int) -> Void
    let onDropExit: () -> Void
    let onReceiveBlock: (UUID, UUID, Int) -> Void // moodId, scheduleId, fromDay
    @State private var isTargeted = false
    @State private var rowWidth: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            Text(dayLabels[day - 1])
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let pph = geo.size.width / 24.0

                // Grid lines
                ForEach(0..<25) { hour in
                    Rectangle()
                        .fill(Color.primary.opacity(hour % 6 == 0 ? 0.08 : 0.03))
                        .frame(width: 1, height: geo.size.height)
                        .position(x: CGFloat(hour) * pph, y: geo.size.height / 2)
                }

                // Ghost preview
                if let preview = dropPreview {
                    let ghostX = CGFloat(preview.displayStart) / 60.0 * pph
                    let ghostW = pph * 2 // 2 hours
                    RoundedRectangle(cornerRadius: 5)
                        .fill(blockColors[preview.moodIndex % blockColors.count].opacity(0.3))
                        .frame(width: ghostW, height: geo.size.height - 8)
                        .position(x: ghostX + ghostW / 2, y: geo.size.height / 2)
                }

                // Blocks
                ForEach(blocks) { (block: MoodStore.ScheduleBlock) in
                    let displayStart = toDisplayMinutes(block.startMinutes)
                    let displayEnd = toDisplayMinutes(block.endMinutes)
                    let duration = displayEnd > displayStart ? displayEnd - displayStart : totalMinutesInDay - displayStart + displayEnd
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
                            let absEnd = absStart + dur
                            store.updateScheduleTime(
                                moodId: block.moodId, scheduleId: block.scheduleId,
                                startHour: (absStart % 1440) / 60, startMinute: absStart % 60,
                                endHour: (absEnd % 1440) / 60, endMinute: absEnd % 60
                            )
                            HapticService.playGeneric()
                        },
                        onResize: { newAbsStart, newAbsEnd in
                            store.updateScheduleTime(
                                moodId: block.moodId, scheduleId: block.scheduleId,
                                startHour: newAbsStart / 60, startMinute: newAbsStart % 60,
                                endHour: newAbsEnd / 60, endMinute: newAbsEnd % 60
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
            }
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
                let displayMinutes = snap30(Int(location.x / rowWidth * 24 * 60))
                onDrop(moodId, displayMinutes)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
                if !targeted { onDropExit() }
            }
        }
        .frame(height: 44)
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
    @State private var isDragging = false
    @State private var bodyDragOffset: CGFloat = 0
    @State private var verticalDragOffset: CGFloat = 0
    @State private var leftDragOffset: CGFloat = 0
    @State private var rightDragOffset: CGFloat = 0
    @State private var xHovered = false

    // Snapped offset — jumps in 30-min increments but with damping
    private var snappedBodyOffset: CGFloat {
        let minutesDelta = bodyDragOffset / pph * 60
        let snapped = round(minutesDelta / 30) * 30
        return snapped / 60 * pph
    }

    private var color: Color { blockColors[block.moodIndex % blockColors.count] }
    private var currentW: CGFloat { max(blockW - leftDragOffset + rightDragOffset, 20) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Body
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )

            // Content — ease out while dragging
            HStack(spacing: 3) {
                Text(block.moodIcon).font(.system(size: 11))
                if currentW > 60 {
                    Text(block.moodName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .opacity(isDragging ? 0 : 1)
            .animation(.easeOut(duration: 0.15), value: isDragging)

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

            // Resize handles
            HStack(spacing: 0) {
                // Left
                Rectangle()
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0))
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                isDragging = true
                                leftDragOffset = v.translation.width
                            }
                            .onEnded { v in
                                let delta = snap30(Int(v.translation.width / pph * 60))
                                let newStart = max(0, block.startMinutes + delta)
                                if newStart < block.endMinutes - 29 {
                                    onResize(newStart, block.endMinutes)
                                }
                                leftDragOffset = 0
                                isDragging = false
                            }
                    )

                Spacer()

                // Right
                Rectangle()
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0))
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                isDragging = true
                                rightDragOffset = v.translation.width
                            }
                            .onEnded { v in
                                let delta = snap30(Int(v.translation.width / pph * 60))
                                let newEnd = min(1440, block.endMinutes + delta)
                                if newEnd > block.startMinutes + 29 {
                                    onResize(block.startMinutes, newEnd)
                                }
                                rightDragOffset = 0
                                isDragging = false
                            }
                    )
            }
        }
        .frame(width: currentW, height: rowHeight - 8)
        .offset(x: blockX + snappedBodyOffset + leftDragOffset, y: 4 + verticalDragOffset)
        .animation(.easeOut(duration: 0.08), value: snappedBodyOffset)
        .animation(.easeOut(duration: 0.1), value: verticalDragOffset)
        .opacity(isHovered ? 1.0 : 0.85)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
        .onTapGesture { onSelect() }
        // Body drag — horizontal move + vertical row change
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    isDragging = true
                    bodyDragOffset = v.translation.width

                    // Vertical: resist until 25px threshold, then track
                    let verticalRaw = v.translation.height
                    if abs(verticalRaw) > 25 {
                        verticalDragOffset = (verticalRaw - (verticalRaw > 0 ? 25 : -25)) * 0.6
                    } else {
                        verticalDragOffset = 0
                    }
                }
                .onEnded { v in
                    // Horizontal — commit snapped position
                    let minutesDelta = v.translation.width / pph * 60
                    let delta = Int(round(minutesDelta / 30)) * 30
                    let displayStart = toDisplayMinutes(block.startMinutes)
                    let dur = block.endMinutes - block.startMinutes
                    let newDisplayStart = max(0, min(totalMinutesInDay - dur, displayStart + delta))
                    onMove(snap30(newDisplayStart))

                    // Vertical — if dragged far enough, move to another row
                    let rowShift = Int(round(v.translation.height / rowHeight))
                    if rowShift != 0 {
                        let newDay = block.day + rowShift
                        if newDay >= 1 && newDay <= 7 {
                            onRowChange(newDay)
                        }
                    }

                    bodyDragOffset = 0
                    verticalDragOffset = 0
                    isDragging = false
                }
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(isHovered ? 0.05 : 0)))
        .onHover { h in isHovered = h }
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
