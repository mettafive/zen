import SwiftUI

private let createEmojiPalette = [
    "✨", "🧘", "🌙", "🌆", "🙏", "🪑", "🎯", "🌅", "🔥", "💧",
    "🌊", "🍃", "🌸", "🌿", "🪷", "🕊️", "🦋", "☀️", "⭐", "🌟",
    "💫", "🌈", "❄️", "🌬️", "🫧", "💎", "🪨", "🏔️", "🌲", "🌻",
    "🍂", "🌾", "🎵", "🎶", "🔔", "🕯️", "🪶", "🐚", "🧿", "☯️",
    "🕉️", "📿", "🪬", "❤️", "🧡", "💛", "💚", "💙", "💜", "🤍",
    "😌", "😊", "🥰", "😇", "🤗", "😮‍💨", "😴", "☕", "🍵", "📖",
]

struct MoodCreateView: View {
    @ObservedObject private var store = MoodStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var icon = ""
    @State private var name = ""
    @State private var subtitle = ""
    @State private var showEmojiPicker = true
    @State private var createdMoodId: UUID? = nil
    @State private var showSavedMessage = false
    @State private var nameHovered = false
    @State private var subtitleHovered = false
    @State private var saveGlow = false
    @State private var activePulse = false

    private var iconPicked: Bool { !icon.isEmpty }
    private var nameFilled: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var subtitleFilled: Bool { !subtitle.trimmingCharacters(in: .whitespaces).isEmpty }
    private var allFilled: Bool { iconPicked && nameFilled && subtitleFilled }

    // Which step is currently active (for the single pulsing dot)
    private var activeStep: Int {
        if !iconPicked { return 0 }
        if !nameFilled { return 1 }
        if !subtitleFilled { return 2 }
        return 3 // all done
    }

    var body: some View {
        if let moodId = createdMoodId, let mood = store.moods.first(where: { $0.id == moodId }) {
            // Saved — go straight to detail view, no wrapper chrome
            MoodDetailView(mood: mood)
        } else {
            VStack(spacing: 0) {
                // Top row
                HStack {
                    CreateBackButton {
                        HapticService.playGeneric()
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)

                identityStep
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            .onAppear {
                // Start pulse
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    activePulse = true
                }
            }
            .onChange(of: allFilled) {
                if allFilled {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        saveGlow = true
                    }
                } else {
                    saveGlow = false
                }
            }
        }
    }

    // MARK: - Identity Step

    private var identityStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Step indicator
            stepIndicator

            // Emoji
            VStack(spacing: 10) {
                if iconPicked && !showEmojiPicker {
                    Text(icon)
                        .font(.system(size: 56))
                        .frame(width: 80, height: 80)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
                        .onTapGesture {
                            HapticService.playGeneric()
                            withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = true }
                        }
                } else if !showEmojiPicker {
                    Button {
                        HapticService.playGeneric()
                        withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = true }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 80, height: 80)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
                    }
                    .buttonStyle(.plain)
                }

                if showEmojiPicker {
                    emojiPicker
                }
            }

            Spacer().frame(height: 28)

            // Title field — fixed frame, overlay for hover indicator
            ZStack {
                // Always-present background to prevent layout shift
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(nameHovered || nameFilled ? 0.04 : 0))
                    .animation(.easeOut(duration: 0.15), value: nameHovered)
                    .animation(.easeOut(duration: 0.15), value: nameFilled)

                TextField("", text: $name, prompt: Text("Title").foregroundStyle(Color.primary.opacity(0.2)))
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: 300)
            .frame(height: 40)
            .contentShape(Rectangle())
            .onHover { h in nameHovered = h }
            .opacity(iconPicked ? 1 : 0.3)
            .disabled(!iconPicked)
            .animation(.easeOut(duration: 0.3), value: iconPicked)

            Spacer().frame(height: 8)

            // Description field — same pattern
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(subtitleHovered || subtitleFilled ? 0.04 : 0))
                    .animation(.easeOut(duration: 0.15), value: subtitleHovered)
                    .animation(.easeOut(duration: 0.15), value: subtitleFilled)

                TextField("", text: $subtitle, prompt: Text("Description").foregroundStyle(Color.primary.opacity(0.2)))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: 400)
            .frame(height: 34)
            .contentShape(Rectangle())
            .onHover { h in subtitleHovered = h }
            .opacity(nameFilled ? 1 : 0.3)
            .disabled(!nameFilled)
            .animation(.easeOut(duration: 0.3), value: nameFilled)

            Spacer().frame(height: 28)

            // Save button
            Button {
                saveMood()
            } label: {
                Text("Save and continue")
                    .font(allFilled ? .body.weight(.medium) : .callout.weight(.medium))
                    .frame(width: allFilled ? 200 : 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(allFilled ? .large : .regular)
            .disabled(!allFilled)
            .shadow(color: saveGlow ? Color.accentColor.opacity(0.4) : Color.clear, radius: saveGlow ? 12 : 0)
            .animation(.easeInOut(duration: 0.3), value: allFilled)

            if showSavedMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Your mood is saved")
                        .foregroundStyle(.green)
                }
                .font(.caption)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 20) {
            stepDot(label: "Icon", step: 0)
            stepLine(done: iconPicked)
            stepDot(label: "Title", step: 1)
            stepLine(done: nameFilled)
            stepDot(label: "Description", step: 2)
        }
        .padding(.bottom, 24)
    }

    private func stepDot(label: String, step: Int) -> some View {
        let done = activeStep > step
        let active = activeStep == step

        return VStack(spacing: 4) {
            Circle()
                .fill(done ? Color.green : active ? Color.accentColor : Color.primary.opacity(0.1))
                .frame(width: 8, height: 8)
                .scaleEffect(active && activePulse ? 1.4 : 1.0)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(done ? .green : active ? .primary : .secondary.opacity(0.4))
        }
    }

    private func stepLine(done: Bool) -> some View {
        Rectangle()
            .fill(done ? Color.green.opacity(0.4) : Color.primary.opacity(0.06))
            .frame(width: 40, height: 1)
            .animation(.easeOut(duration: 0.3), value: done)
    }

    // MARK: - Emoji Picker

    private var emojiPicker: some View {
        VStack(spacing: 8) {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [GridItem(.fixed(36)), GridItem(.fixed(36))], spacing: 4) {
                            ForEach(Array(createEmojiPalette.enumerated()), id: \.element) { index, emoji in
                                Button {
                                    HapticService.playGeneric()
                                    icon = emoji
                                    withAnimation(.easeOut(duration: 0.25)) { showEmojiPicker = false }
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 22))
                                        .frame(width: 34, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(emoji == icon ? Color.accentColor.opacity(0.15) : .clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear {
                        // Smoother scroll hint: ease out then ease back
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.easeOut(duration: 0.7)) {
                                proxy.scrollTo(12, anchor: .leading)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeInOut(duration: 0.7)) {
                                    proxy.scrollTo(0, anchor: .leading)
                                }
                            }
                        }
                    }
                }

                // Right edge fade (scroll indicator)
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color(.windowBackgroundColor).opacity(0), Color(.windowBackgroundColor)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 28)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 76)
            .frame(maxWidth: 400)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

            EmojiCancelButton {
                withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = false }
            }
        }
        .onExitCommand {
            if showEmojiPicker {
                withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = false }
            }
        }
    }

    // MARK: - Actions

}

// MARK: - Back Button

private struct CreateBackButton: View {
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

// MARK: - Emoji Cancel Button

private struct EmojiCancelButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                Text("Cancel")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : 0.6)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
    }
}

private extension MoodCreateView {
    func saveMood() {
        HapticService.playLevelChange()
        let mood = Mood(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            quotes: [],
            reminders: [],
            isDefault: false
        )
        store.addMood(mood)

        withAnimation(.easeOut(duration: 0.3)) {
            showSavedMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                createdMoodId = mood.id
            }
        }
    }
}
