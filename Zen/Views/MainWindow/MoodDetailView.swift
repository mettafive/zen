import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Common emoji palette for icon picker
private let emojiPalette = [
    "🧘", "🌙", "🌆", "🙏", "🪑", "🎯", "🌅", "✨", "🔥", "💧",
    "🌊", "🍃", "🌸", "🌿", "🪷", "🕊️", "🦋", "☀️", "⭐", "🌟",
    "💫", "🌈", "❄️", "🌬️", "🫧", "💎", "🪨", "🏔️", "🌲", "🌻",
    "🍂", "🌾", "🎵", "🎶", "🔔", "🕯️", "🪶", "🐚", "🧿", "☯️",
    "🕉️", "📿", "🪬", "❤️", "🧡", "💛", "💚", "💙", "💜", "🤍",
    "🫀", "🧠", "👁️", "👐", "🤲", "🙌", "💪", "🦶", "👃", "👂",
    "😌", "😊", "🥰", "😇", "🤗", "😮‍💨", "😴", "🥱", "😶", "🫡",
    "☕", "🍵", "🫖", "🌄", "🌇", "🏞️", "🛖", "⛩️", "🗾", "🎑",
    "📖", "📝", "🖊️", "💡", "⏳", "⏰", "🧭", "🪞", "🎭", "🌀",
    "♾️", "🔮", "🪄", "🎪", "🏆", "🎗️", "🧩", "🎲", "🀄", "♟️",
]

struct MoodDetailView: View {
    @ObservedObject private var store = MoodStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mood: Mood
    @State private var selectedTab = 0
    @State private var showDeleteConfirm = false
    @State private var editingNewIndex: Int? = nil
    @State private var editingItemIndex: Int? = nil
    @State private var searchText = ""
    @State private var showSearch = false

    // Header editing states
    @State private var editingIcon = false
    @State private var iconHovered = false
    @State private var showSchedulePopover = false
    @State private var editingName = false
    @State private var editingSubtitle = false

    init(mood: Mood) {
        _mood = State(initialValue: mood)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top row: back + auto-select
            HStack {
                BackButton {
                    HapticService.playGeneric()
                    dismiss()
                }

                Spacer()

                ScheduleButton(count: mood.schedules.count) {
                    HapticService.playGeneric()
                    showSchedulePopover.toggle()
                }
                .popover(isPresented: $showSchedulePopover, arrowEdge: .top) {
                    SchedulePopover(mood: $mood, store: store, onSave: { autoSave() })
                        .frame(width: 360)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Header — centered
            header
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Divider()

            // Tab toggle + search + add — centered
            tabBar
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 4)

            // Expandable search
            if showSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    Button {
                        searchText = ""
                        withAnimation(.easeInOut(duration: 0.2)) { showSearch = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
                .frame(maxWidth: 400)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Item list — constrained width
            itemList
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            if !mood.isDefault {
                MoodActionButton(icon: "trash", color: .red) {
                    showDeleteConfirm = true
                }
                .help("Delete this mood")
                .padding(20)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            MoodActionButton(icon: "square.and.arrow.up", color: .secondary) {
                exportMood()
            }
            .help("Save this mood to send to a friend — they can import it into their Zen app")
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .alert("Delete \"\(mood.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Yes, delete", role: .destructive) {
                HapticService.playLevelChange()
                store.deleteMood(id: mood.id)
                dismiss()
            }
            Button("No, keep it", role: .cancel) {}
        } message: {
            Text("You're about to delete \"\(mood.name)\" and all its quotes and reminders. This cannot be undone.")
        }
    }

    // MARK: - Header (centered)

    private var header: some View {
        VStack(spacing: 8) {
            // Icon
            if editingIcon {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Text(mood.icon)
                            .font(.system(size: 48))
                        Spacer()
                    }

                    // Emoji grid picker with edge fade
                    ZStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: [GridItem(.fixed(36)), GridItem(.fixed(36))], spacing: 4) {
                                ForEach(emojiPalette, id: \.self) { emoji in
                                    Button {
                                        mood.icon = emoji
                                        withAnimation(.easeOut(duration: 0.2)) { editingIcon = false }
                                        autoSave()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 22))
                                            .frame(width: 34, height: 34)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(emoji == mood.icon ? Color.accentColor.opacity(0.15) : .clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Left edge fade
                        HStack {
                            LinearGradient(
                                colors: [Color(.windowBackgroundColor), Color(.windowBackgroundColor).opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 24)
                            .allowsHitTesting(false)
                            Spacer()
                        }
                    }
                    .frame(height: 76)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.3)))

                    // Cancel button
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { editingIcon = false }
                    } label: {
                        Text("Cancel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text(mood.icon)
                    .font(.system(size: 48))
                    .onHover { h in }
                    .overlay(alignment: .topTrailing) {
                        if iconHovered {
                            Button {
                                HapticService.playGeneric()
                                withAnimation(.easeOut(duration: 0.2)) { editingIcon = true }
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(.quaternary))
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                            .offset(x: 6, y: -4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.1)) { iconHovered = h }
                    }
            }

            // Name
            if editingName {
                HStack(spacing: 6) {
                    TextField("Name", text: $mood.name)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                    Button {
                        editingName = false
                        autoSave()
                    } label: {
                        Text("Save")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 300)
            } else {
                HoverEditField(text: mood.name, font: .title2.weight(.semibold)) {
                    editingName = true
                }
            }

            // Subtitle
            if editingSubtitle {
                HStack(spacing: 6) {
                    TextField("Subtitle", text: $mood.subtitle)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.secondary)
                    Button {
                        editingSubtitle = false
                        autoSave()
                    } label: {
                        Text("Save")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 400)
            } else {
                HoverEditField(text: mood.subtitle, font: .callout, color: .secondary) {
                    editingSubtitle = true
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedTab) {
                Text("Quotes (\(mood.quotes.count))").tag(0)
                Text("Reminders (\(mood.reminders.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .help(selectedTab == 0
                ? "Quotes appear on screen when your check-in timer fires."
                : "Reminders show up periodically between check-ins as gentle nudges.")
            .onChange(of: selectedTab) {
                HapticService.playGeneric()
                editingItemIndex = nil
                editingNewIndex = nil
            }

            Button {
                HapticService.playGeneric()
                if showSearch {
                    // Close search when opening +
                    searchText = ""
                    withAnimation(.easeInOut(duration: 0.2)) { showSearch = false }
                }
                withAnimation(.easeInOut(duration: 0.2)) { showSearch.toggle() }
                if !showSearch { searchText = "" }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(showSearch ? .primary : .secondary)
            .help("Search")

            Button {
                // Close search if open
                if showSearch {
                    searchText = ""
                    withAnimation(.easeInOut(duration: 0.2)) { showSearch = false }
                }
                addNewItem()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(editingNewIndex != nil)
            .help(selectedTab == 0 ? "Add quote" : "Add reminder")
        }
    }

    // MARK: - Item list

    private var itemList: some View {
        let items = selectedTab == 0 ? mood.quotes : mood.reminders
        let filtered: [(index: Int, text: String)] = items.enumerated().filter { pair in
            searchText.isEmpty || pair.element.localizedCaseInsensitiveContains(searchText)
        }.map { (index: $0.offset, text: $0.element) }

        return ScrollView {
            if filtered.isEmpty && searchText.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: selectedTab == 0 ? "quote.closing" : "bell")
                        .font(.title)
                        .foregroundStyle(.quaternary)
                    Text(selectedTab == 0
                        ? "No quotes yet. Quotes appear on screen when your check-in timer fires."
                        : "No reminders yet. Reminders show up periodically between check-ins.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Text("Tap + to add one.")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .padding(.top, 60)
                .frame(maxWidth: .infinity)
            }

            LazyVStack(spacing: 0) {
                ForEach(filtered, id: \.index) { item in
                    let index = item.index
                    let text = item.text
                    ItemRow(
                        text: text,
                        isNew: editingNewIndex == index,
                        isEditing: editingItemIndex == index,
                        onEdit: {
                            editingItemIndex = index
                            editingNewIndex = nil
                        },
                        onUpdate: { newText in
                            updateItem(at: index, with: newText)
                            editingNewIndex = nil
                            editingItemIndex = nil
                        },
                        onCancel: {
                            if editingNewIndex == index {
                                deleteItem(at: index)
                            }
                            editingNewIndex = nil
                            editingItemIndex = nil
                        },
                        onDelete: {
                            deleteItem(at: index)
                        }
                    )
                    Divider()
                }
            }
        }
    }

    // MARK: - Actions

    private func addNewItem() {
        HapticService.playGeneric()
        editingItemIndex = nil
        if selectedTab == 0 {
            mood.quotes.insert("", at: 0)
        } else {
            mood.reminders.insert("", at: 0)
        }
        editingNewIndex = 0
        autoSave()
    }

    private func updateItem(at index: Int, with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            deleteItem(at: index)
            return
        }
        if selectedTab == 0 {
            guard index < mood.quotes.count else { return }
            mood.quotes[index] = trimmed
        } else {
            guard index < mood.reminders.count else { return }
            mood.reminders[index] = trimmed
        }
        autoSave()
    }

    private func deleteItem(at index: Int) {
        HapticService.playLevelChange()
        if selectedTab == 0 {
            guard index < mood.quotes.count else { return }
            mood.quotes.remove(at: index)
        } else {
            guard index < mood.reminders.count else { return }
            mood.reminders.remove(at: index)
        }
        if editingNewIndex == index { editingNewIndex = nil }
        autoSave()
    }

    private func autoSave() {
        store.updateMood(mood)
    }

    private func exportMood() {
        HapticService.playGeneric()
        let data = store.exportMood(mood)
        let safeName = mood.name.replacingOccurrences(of: " ", with: "-")

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeName).zenmood"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
                Task { @MainActor in
                    HapticService.playLevelChange()
                }
            }
        }
    }
}

// MARK: - Schedule Button

private struct ScheduleButton: View {
    let count: Int
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                Text("Schedule")
                    .font(.body)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Back Button

private struct BackButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("Back")
                    .font(.body)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Mood Action Button (bottom-right, subtle)

private struct MoodActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            HapticService.playLevelChange()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Hover Edit Field (hover text to reveal pencil)

private struct HoverEditField: View {
    let text: String
    let font: Font
    var color: Color = .primary
    let onEdit: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(font)
                .foregroundStyle(color)
            if isHovered {
                Button {
                    HapticService.playGeneric()
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.quaternary))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = h }
        }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let text: String
    let isNew: Bool
    let isEditing: Bool
    let onEdit: () -> Void
    let onUpdate: (String) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var editText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Text content
            if isEditing || isNew {
                TextField("Type here...", text: $editText, axis: .vertical)
                    .font(.callout)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        HapticService.playLevelChange()
                        onUpdate(editText)
                    }
                    .onAppear {
                        editText = text
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFocused = true
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action buttons — same position, swap content
            HStack(spacing: 6) {
                if isEditing || isNew {
                    // Save (checkmark) in edit position
                    Button {
                        HapticService.playLevelChange()
                        onUpdate(editText)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.quaternary))
                    }
                    .buttonStyle(.plain)

                    // Cancel (X) in trash position
                    Button {
                        HapticService.playGeneric()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                } else if isHovered {
                    // Edit (pencil)
                    Button {
                        HapticService.playGeneric()
                        editText = text
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.quaternary))
                    }
                    .buttonStyle(.plain)

                    // Delete (trash)
                    Button {
                        HapticService.playLevelChange()
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 64, alignment: .trailing)
            .animation(.easeInOut(duration: 0.15), value: isEditing)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered || isEditing ? Color.primary.opacity(0.03) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Schedule Popover

private struct SchedulePopover: View {
    @Binding var mood: Mood
    let store: MoodStore
    let onSave: () -> Void

    @State private var editingSchedule: MoodSchedule = MoodSchedule()
    @State private var editingIndex: Int? = nil

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Schedules")
                    .font(.headline)
                Spacer()
                Button {
                    editingSchedule = MoodSchedule()
                    editingIndex = nil
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add schedule")
            }

            // Existing schedule bubbles
            if !mood.schedules.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(mood.schedules.enumerated()), id: \.element.id) { index, sched in
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue)

                            Text(sched.summary)
                                .font(.system(size: 12, design: .monospaced))

                            Text(daysLabel(for: sched))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                editingSchedule = sched
                                editingIndex = index
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                mood.schedules.remove(at: index)
                                onSave()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
                    }
                }
            }

            Divider()

            // Editor
            VStack(alignment: .leading, spacing: 8) {
                Text(editingIndex != nil ? "Edit schedule" : "New schedule")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                // Time pickers
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Text("Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $editingSchedule.startHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 55)
                        Text(":")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $editingSchedule.startMinute) {
                            Text("00").tag(0)
                            Text("30").tag(30)
                        }
                        .frame(width: 50)
                    }

                    HStack(spacing: 3) {
                        Text("End")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $editingSchedule.endHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 55)
                        Text(":")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $editingSchedule.endMinute) {
                            Text("00").tag(0)
                            Text("30").tag(30)
                        }
                        .frame(width: 50)
                    }
                }

                // Day buttons
                HStack(spacing: 4) {
                    ForEach(1...7, id: \.self) { day in
                        let isOn = editingSchedule.days.contains(day)
                        Button {
                            HapticService.playGeneric()
                            if isOn { editingSchedule.days.remove(day) }
                            else { editingSchedule.days.insert(day) }
                        } label: {
                            Text(dayLabels[day - 1])
                                .font(.system(size: 10, weight: isOn ? .semibold : .regular))
                                .foregroundStyle(isOn ? .white : .secondary)
                                .frame(width: 34, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(isOn ? Color.accentColor : Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Conflict warning
                if let conflict = store.scheduleConflict(for: editingSchedule, excludingMood: mood.id) {
                    let dayNames = conflict.days.sorted().map { dayLabels[$0 - 1] }.joined(separator: ", ")
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("Conflicts with \"\(conflict.mood.name)\" on \(dayNames)")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }

                // Save button
                HStack {
                    Spacer()
                    Button {
                        saveSchedule()
                    } label: {
                        Text(editingIndex != nil ? "Update" : "Add")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(editingSchedule.days.isEmpty || store.scheduleConflict(for: editingSchedule, excludingMood: mood.id) != nil)
                }
            }
        }
        .padding(16)
    }

    private func saveSchedule() {
        if let index = editingIndex, index < mood.schedules.count {
            mood.schedules[index] = editingSchedule
        } else {
            var newSched = editingSchedule
            newSched.id = UUID()
            mood.schedules.append(newSched)
        }
        onSave()
        editingSchedule = MoodSchedule()
        editingIndex = nil
    }

    private func daysLabel(for sched: MoodSchedule) -> String {
        let sorted = sched.days.sorted()
        let abbrev = ["M", "T", "W", "T", "F", "S", "S"]
        if sorted == [1,2,3,4,5] { return "Weekdays" }
        if sorted == [6,7] { return "Weekends" }
        if sorted == [1,2,3,4,5,6,7] { return "Every day" }
        return sorted.map { abbrev[$0 - 1] }.joined(separator: " ")
    }
}
