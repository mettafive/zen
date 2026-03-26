import SwiftUI

// Day starts at 04:00, ends at 04:00 next day
private let dayStartHour = 4
private let totalMinutesInDay = 1440
private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
private let blockColors: [Color] = [
    .blue.opacity(0.7), .green.opacity(0.7), .orange.opacity(0.7),
    .purple.opacity(0.7), .pink.opacity(0.7), .teal.opacity(0.7),
    .indigo.opacity(0.7), .mint.opacity(0.7), .brown.opacity(0.7),
]

/// Convert absolute minutes (0-1440) to display position (offset by 04:00)
private func toDisplayMinutes(_ absoluteMinutes: Int) -> Int {
    (absoluteMinutes - dayStartHour * 60 + totalMinutesInDay) % totalMinutesInDay
}

/// Convert display position back to absolute minutes
private func toAbsoluteMinutes(_ displayMinutes: Int) -> Int {
    (displayMinutes + dayStartHour * 60) % totalMinutesInDay
}

/// Snap to nearest 30-minute increment
private func snap30(_ minutes: Int) -> Int {
    Int(round(Double(minutes) / 30.0)) * 30
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

                // Error toast
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
            // Hour header (04, 06, 08 ... 22, 00, 02, 04)
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 50)

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

            // Day rows
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
                    onDropExit: { dropPreview = nil }
                )
                Divider()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Mood Sidebar

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

    private func handleDrop(moodId: UUID, day: Int, displayMinutes: Int) {
        dropPreview = nil
        let absStart = toAbsoluteMinutes(snap30(displayMinutes))
        let absEnd = toAbsoluteMinutes(snap30(displayMinutes) + 60)

        // Check for overlaps
        let dayBlocks = store.allScheduleBlocks().filter { $0.day == day }
        let conflicts = dayBlocks.filter { overlaps(aStart: absStart, aEnd: absEnd, bStart: $0.startMinutes, bEnd: $0.endMinutes) }

        if conflicts.isEmpty {
            HapticService.playGeneric()
            store.addScheduleBlock(moodId: moodId, day: day,
                                   startHour: absStart / 60, startMinute: absStart % 60,
                                   endHour: absEnd / 60, endMinute: absEnd % 60)
            return
        }

        // Try before the first conflict
        let firstConflict = conflicts.sorted(by: { $0.startMinutes < $1.startMinutes }).first!
        let beforeEnd = firstConflict.startMinutes
        let beforeStart = beforeEnd - 60
        if beforeStart >= dayStartHour * 60 &&
           !dayBlocks.contains(where: { overlaps(aStart: beforeStart, aEnd: beforeEnd, bStart: $0.startMinutes, bEnd: $0.endMinutes) }) {
            HapticService.playGeneric()
            store.addScheduleBlock(moodId: moodId, day: day,
                                   startHour: beforeStart / 60, startMinute: beforeStart % 60,
                                   endHour: beforeEnd / 60, endMinute: beforeEnd % 60)
            return
        }

        // Try after the last conflict
        let lastConflict = conflicts.sorted(by: { $0.endMinutes > $1.endMinutes }).first!
        let afterStart = lastConflict.endMinutes
        let afterEnd = afterStart + 60
        if afterEnd <= (dayStartHour + 24) * 60 &&
           !dayBlocks.contains(where: { overlaps(aStart: afterStart, aEnd: afterEnd, bStart: $0.startMinutes, bEnd: $0.endMinutes) }) {
            HapticService.playGeneric()
            let sh = afterStart >= 1440 ? (afterStart - 1440) / 60 : afterStart / 60
            let sm = afterStart % 60
            let eh = afterEnd >= 1440 ? (afterEnd - 1440) / 60 : afterEnd / 60
            let em = afterEnd % 60
            store.addScheduleBlock(moodId: moodId, day: day,
                                   startHour: sh, startMinute: sm,
                                   endHour: eh, endMinute: em)
            return
        }

        // No room
        withAnimation(.easeOut(duration: 0.2)) { errorMessage = "No room on \(dayLabels[day - 1])" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeIn(duration: 0.3)) { errorMessage = nil }
        }
    }

    private func overlaps(aStart: Int, aEnd: Int, bStart: Int, bEnd: Int) -> Bool {
        aStart < bEnd && bStart < aEnd
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

                // Hour grid lines
                ForEach(0..<25) { hour in
                    Rectangle()
                        .fill(Color.primary.opacity(hour % 6 == 0 ? 0.08 : 0.03))
                        .frame(width: 1, height: geo.size.height)
                        .position(x: CGFloat(hour) * pph, y: geo.size.height / 2)
                }

                // Drop preview ghost
                if let preview = dropPreview {
                    let ghostX = CGFloat(preview.displayStart) / 60.0 * pph
                    let ghostW = pph // 1 hour
                    RoundedRectangle(cornerRadius: 5)
                        .fill(blockColors[preview.moodIndex % blockColors.count].opacity(0.3))
                        .frame(width: ghostW, height: geo.size.height - 8)
                        .position(x: ghostX + ghostW / 2, y: geo.size.height / 2)
                }

                // Schedule blocks
                ForEach(blocks) { block in
                    let displayStart = toDisplayMinutes(block.startMinutes)
                    let displayEnd = toDisplayMinutes(block.endMinutes)
                    let duration = displayEnd > displayStart ? displayEnd - displayStart : totalMinutesInDay - displayStart + displayEnd
                    let blockX = CGFloat(displayStart) / 60.0 * pph
                    let blockW = max(CGFloat(duration) / 60.0 * pph, 20)

                    ScheduleBlockView(
                        block: block,
                        x: blockX,
                        width: blockW,
                        pph: pph,
                        rowHeight: geo.size.height,
                        isSelected: selectedBlockId == block.id,
                        onSelect: { selectedBlockId = block.id },
                        onMove: { newDisplayStart in
                            let absStart = toAbsoluteMinutes(newDisplayStart)
                            let absEnd = toAbsoluteMinutes(newDisplayStart + duration)
                            store.updateScheduleTime(
                                moodId: block.moodId, scheduleId: block.scheduleId,
                                startHour: absStart / 60, startMinute: absStart % 60,
                                endHour: absEnd / 60, endMinute: absEnd % 60
                            )
                        },
                        onResize: { newAbsStart, newAbsEnd in
                            store.updateScheduleTime(
                                moodId: block.moodId, scheduleId: block.scheduleId,
                                startHour: newAbsStart / 60, startMinute: newAbsStart % 60,
                                endHour: newAbsEnd / 60, endMinute: newAbsEnd % 60
                            )
                        },
                        onDelete: {
                            HapticService.playLevelChange()
                            store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: block.day)
                            selectedBlockId = nil
                        }
                    )
                }
            }
            .background(isTargeted ? Color.accentColor.opacity(0.04) : Color.clear)
            .background(GeometryReader { geo in
                Color.clear.onAppear { rowWidth = geo.size.width }
            })
            .dropDestination(for: String.self) { items, location in
                guard let moodIdString = items.first,
                      let moodId = UUID(uuidString: moodIdString) else { return false }
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
    let x: CGFloat
    let width: CGFloat
    let pph: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (Int) -> Void // newDisplayStartMinutes
    let onResize: (Int, Int) -> Void // (newAbsStart, newAbsEnd)
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var bodyDragOffset: CGFloat = 0
    @State private var leftDragOffset: CGFloat = 0
    @State private var rightDragOffset: CGFloat = 0

    private var color: Color {
        blockColors[block.moodIndex % blockColors.count]
    }

    private var effectiveX: CGFloat { x + bodyDragOffset + leftDragOffset }
    private var effectiveW: CGFloat { max(width - leftDragOffset + rightDragOffset, 20) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Block body
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )

            // Content
            HStack(spacing: 3) {
                Text(block.moodIcon)
                    .font(.system(size: 11))
                if effectiveW > 60 {
                    Text(block.moodName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

            // Delete X on hover
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .offset(x: -3, y: 3)
                .transition(.opacity)
            }

            // Resize handles
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                    .gesture(
                        DragGesture()
                            .onChanged { v in leftDragOffset = v.translation.width }
                            .onEnded { v in
                                let delta = snap30(Int(v.translation.width / pph * 60))
                                let newStart = max(0, block.startMinutes + delta)
                                if newStart < block.endMinutes - 29 {
                                    onResize(newStart, block.endMinutes)
                                }
                                leftDragOffset = 0
                            }
                    )

                Spacer()

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                    .gesture(
                        DragGesture()
                            .onChanged { v in rightDragOffset = v.translation.width }
                            .onEnded { v in
                                let delta = snap30(Int(v.translation.width / pph * 60))
                                let newEnd = min(1440, block.endMinutes + delta)
                                if newEnd > block.startMinutes + 29 {
                                    onResize(block.startMinutes, newEnd)
                                }
                                rightDragOffset = 0
                            }
                    )
            }
        }
        .frame(width: effectiveW, height: rowHeight - 8)
        .position(x: effectiveX + effectiveW / 2, y: rowHeight / 2)
        .opacity(isHovered ? 1.0 : 0.85)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
        .onTapGesture { onSelect() }
        .gesture(
            DragGesture()
                .onChanged { v in bodyDragOffset = v.translation.width }
                .onEnded { v in
                    let delta = snap30(Int(v.translation.width / pph * 60))
                    let displayStart = toDisplayMinutes(block.startMinutes)
                    let newDisplayStart = max(0, min(totalMinutesInDay - 30, displayStart + delta))
                    onMove(snap30(newDisplayStart))
                    bodyDragOffset = 0
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
            Text(mood.icon)
                .font(.system(size: 14))
            Text(mood.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(isHovered ? 0.05 : 0))
        )
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
