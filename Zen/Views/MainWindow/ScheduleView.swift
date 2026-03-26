import SwiftUI

private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
private let blockColors: [Color] = [
    .blue.opacity(0.6), .green.opacity(0.6), .orange.opacity(0.6),
    .purple.opacity(0.6), .pink.opacity(0.6), .teal.opacity(0.6),
    .indigo.opacity(0.6), .mint.opacity(0.6), .brown.opacity(0.6),
]

struct ScheduleView: View {
    @ObservedObject private var store = MoodStore.shared
    @State private var selectedBlockId: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Timeline grid
            VStack(alignment: .leading, spacing: 0) {
                Text("Schedule")
                    .font(.title2.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                timelineGrid
            }

            Divider()

            // Mood sidebar
            moodSidebar
                .frame(width: 150)
        }
        .onDeleteCommand {
            deleteSelectedBlock()
        }
    }

    // MARK: - Timeline Grid

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            // Hour header
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 50)

                GeometryReader { geo in
                    let pph = geo.size.width / 24
                    ForEach(0..<25) { hour in
                        if hour % 3 == 0 {
                            Text(String(format: "%02d", hour == 24 ? 0 : hour))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .position(x: CGFloat(hour) * pph, y: 8)
                        }
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
                    store: store
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

    private func deleteSelectedBlock() {
        guard let blockId = selectedBlockId else { return }
        let blocks = store.allScheduleBlocks()
        guard let block = blocks.first(where: { $0.id == blockId }) else { return }
        HapticService.playLevelChange()
        store.removeScheduleBlock(moodId: block.moodId, scheduleId: block.scheduleId, day: block.day)
        selectedBlockId = nil
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let day: Int
    let blocks: [MoodStore.ScheduleBlock]
    @Binding var selectedBlockId: String?
    let store: MoodStore
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            // Day label
            Text(dayLabels[day - 1])
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            // Timeline
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let pph = totalWidth / 24

                // Hour grid lines
                ForEach(0..<25) { hour in
                    Rectangle()
                        .fill(Color.primary.opacity(hour % 6 == 0 ? 0.08 : 0.03))
                        .frame(width: 1)
                        .position(x: CGFloat(hour) * pph, y: geo.size.height / 2)
                        .frame(height: geo.size.height)
                }

                // Schedule blocks
                ForEach(blocks) { block in
                    ScheduleBlockView(
                        block: block,
                        pph: pph,
                        rowHeight: geo.size.height,
                        isSelected: selectedBlockId == block.id,
                        onSelect: { selectedBlockId = block.id },
                        onResize: { newStart, newEnd in
                            let sh = newStart / 60
                            let sm = newStart % 60
                            let eh = newEnd / 60
                            let em = newEnd % 60
                            store.updateScheduleTime(
                                moodId: block.moodId,
                                scheduleId: block.scheduleId,
                                startHour: sh, startMinute: sm,
                                endHour: eh, endMinute: em
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
            .background(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
            .clipShape(Rectangle())
            .dropDestination(for: String.self) { items, location in
                guard let moodIdString = items.first,
                      let moodId = UUID(uuidString: moodIdString) else { return false }

                let geo = location.x
                // Calculate hour from drop position — we'll estimate based on the view
                // This gets refined after the drop
                HapticService.playGeneric()
                store.addScheduleBlock(moodId: moodId, day: day, startHour: 9, startMinute: 0, endHour: 10, endMinute: 0)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
        }
        .frame(height: 44)
    }
}

// MARK: - Schedule Block

private struct ScheduleBlockView: View {
    let block: MoodStore.ScheduleBlock
    let pph: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onResize: (Int, Int) -> Void // (newStartMinutes, newEndMinutes)
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var dragOffset: CGFloat = 0
    @State private var leftDragOffset: CGFloat = 0
    @State private var rightDragOffset: CGFloat = 0

    private var color: Color {
        blockColors[block.moodIndex % blockColors.count]
    }

    private var x: CGFloat { CGFloat(block.startMinutes) / 60.0 * pph }
    private var width: CGFloat {
        max(CGFloat(block.endMinutes - block.startMinutes) / 60.0 * pph, 20)
    }

    var body: some View {
        ZStack {
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
                if width > 60 {
                    Text(block.moodName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)

            // Resize handles
            HStack(spacing: 0) {
                // Left handle
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                leftDragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let deltaMinutes = Int(round(value.translation.width / pph * 60 / 30)) * 30
                                let newStart = max(0, block.startMinutes + deltaMinutes)
                                if newStart < block.endMinutes - 29 {
                                    onResize(newStart, block.endMinutes)
                                }
                                leftDragOffset = 0
                            }
                    )

                Spacer()

                // Right handle
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .cursor(.resizeLeftRight)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                rightDragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let deltaMinutes = Int(round(value.translation.width / pph * 60 / 30)) * 30
                                let newEnd = min(1440, block.endMinutes + deltaMinutes)
                                if newEnd > block.startMinutes + 29 {
                                    onResize(block.startMinutes, newEnd)
                                }
                                rightDragOffset = 0
                            }
                    )
            }
        }
        .frame(width: width + leftDragOffset + rightDragOffset, height: rowHeight - 8)
        .offset(x: x + leftDragOffset + width / 2, y: 0)
        .position(x: 0, y: rowHeight / 2)
        .offset(x: x + (width + leftDragOffset + rightDragOffset) / 2)
        .opacity(isHovered ? 1.0 : 0.85)
        .onHover { h in isHovered = h }
        .onTapGesture { onSelect() }
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
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
