import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum HomeDestination: Hashable {
    case mood(UUID)
    case create
}

struct HomeView: View {
    @ObservedObject private var store = MoodStore.shared
    @State private var importState: ImportState = .idle
    @State private var importError: String? = nil
    @State private var showImportError = false
    @State private var showFeedback = false
    @State private var feedbackSubject = ""
    @State private var feedbackMessage = ""
    @State private var feedbackSent = false

    enum ImportState: Equatable {
        case idle
        case importing
        case success(String) // mood name
    }

    @Environment(\.appDelegate) private var appDelegate

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    HStack {
                        Text("Moods")
                            .font(.title2)
                            .fontWeight(.medium)

                        // Resume button — shows after 3h inactivity
                        if appDelegate?.needsResume == true {
                            ResumeButton {
                                appDelegate?.resumeFromInactivity()
                            }
                        }

                        Spacer()

                        // Import button
                        ImportButton {
                            openImportPanel()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                        ForEach(store.moods) { (mood: Mood) in
                            NavigationLink(value: HomeDestination.mood(mood.id)) {
                                MoodCard(mood: mood, isActive: mood.id == store.activeMoodId) {
                                    HapticService.playLevelChange()
                                    store.setActive(id: mood.id)
                                }
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { HapticService.playGeneric() })
                        }

                        // Add new mood card
                        NavigationLink(value: HomeDestination.create) {
                            AddMoodCard()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)

                    // Feedback button
                    HStack {
                        Spacer()
                        Button {
                            HapticService.playGeneric()
                            showFeedback = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 10))
                                Text("Submit bug or feature request")
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }

                // Import overlay
                if importState != .idle {
                    importOverlay
                }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .mood(let moodId):
                    if let mood = store.moods.first(where: { $0.id == moodId }) {
                        MoodDetailView(mood: mood)
                    }
                case .create:
                    MoodCreateView()
                }
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK") {}
            } message: {
                Text(importError ?? "Could not import this file. Make sure it's a valid .zenmood file.")
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackSheet(
                    subject: $feedbackSubject,
                    message: $feedbackMessage,
                    onSend: { sendFeedback() },
                    onCancel: {
                        showFeedback = false
                        feedbackSubject = ""
                        feedbackMessage = ""
                    }
                )
            }
        }
    }

    // MARK: - Feedback

    private func sendFeedback() {
        let subject = feedbackSubject.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Zen Feedback"
            : "[Zen] \(feedbackSubject.trimmingCharacters(in: .whitespaces))"
        let body = feedbackMessage.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body

        if let url = URL(string: "mailto:lukas@mitthjarta.se?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }

        HapticService.playLevelChange()
        showFeedback = false
        feedbackSubject = ""
        feedbackMessage = ""
    }

    // MARK: - Import Overlay

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                switch importState {
                case .importing:
                    ProgressView()
                        .controlSize(.large)
                    Text("Importing mood...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                case .success(let name):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("\(name) added!")
                        .font(.headline)
                default:
                    EmptyView()
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
            )
        }
        .transition(.opacity)
    }

    // MARK: - Import Actions

    private func openImportPanel() {
        HapticService.playGeneric()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, UTType(filenameExtension: "zenmood") ?? .json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    performImport(from: url)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let ext = url.pathExtension.lowercased()
                guard ext == "zenmood" || ext == "json" else { return }
                Task { @MainActor in
                    performImport(from: url)
                }
            }
        }
    }

    private func performImport(from url: URL) {
        withAnimation(.easeOut(duration: 0.2)) {
            importState = .importing
        }

        // Small delay for the animation to feel intentional
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            do {
                let mood = try store.importMood(from: url)
                HapticService.playLevelChange()
                withAnimation(.easeOut(duration: 0.2)) {
                    importState = .success(mood.name)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        importState = .idle
                    }
                }
            } catch {
                withAnimation(.easeIn(duration: 0.2)) {
                    importState = .idle
                }
                importError = "Could not import this file. Make sure it's a valid .zenmood file."
                showImportError = true
            }
        }
    }
}

// MARK: - Resume Button

private struct ResumeButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var isVisible = true

    var body: some View {
        if isVisible {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isVisible = false
                }
                action()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("Resume")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                )
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1.0 : 0.85)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isHovered)
            .onHover { h in isHovered = h }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Import Button

private struct ImportButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11))
                Text("Import mood")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
        .help("Import a .zenmood file")
    }
}

// MARK: - Feedback Sheet

private struct FeedbackSheet: View {
    @Binding var subject: String
    @Binding var message: String
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Submit Feedback")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Subject")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Bug report, feature request, idea...", text: $subject)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $message)
                    .font(.callout)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Send") {
                    onSend()
                }
                .buttonStyle(.borderedProminent)
                .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .frame(minHeight: 280)
    }
}

// MARK: - Mood Card

struct MoodCard: View {
    let mood: Mood
    let isActive: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(mood.icon)
                    .font(.system(size: 32))
                Spacer()
                if isHovered || isActive {
                    Button {
                        onSelect()
                    } label: {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(isActive ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mood.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(mood.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Label("\(mood.quotes.count)", systemImage: "quote.closing")
                    Label("\(mood.reminders.count)", systemImage: "bell")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if mood.hasActiveSchedules {
                    ForEach(mood.schedules.prefix(2)) { (sched: MoodSchedule) in
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(sched.summary)
                                .font(.system(size: 10, design: .monospaced))
                            Text(scheduleDaysLabel(for: sched))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.blue.opacity(0.7))
                    }
                    if mood.schedules.count > 2 {
                        Text("+\(mood.schedules.count - 2) more")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue.opacity(0.5))
                    }
                } else {
                    Text("No schedule")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(16)
        .frame(minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.02), radius: isHovered ? 8 : 2, y: isHovered ? 4 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: isActive ? 1.5 : 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private let dayAbbrev = ["M", "T", "W", "T", "F", "S", "S"]

    private func scheduleDaysLabel(for sched: MoodSchedule) -> String {
        let sorted = sched.days.sorted()
        if sorted == [1,2,3,4,5] { return "Weekdays" }
        if sorted == [6,7] { return "Weekends" }
        if sorted == [1,2,3,4,5,6,7] { return "Every day" }
        return sorted.map { dayAbbrev[$0 - 1] }.joined(separator: " ")
    }
}

// MARK: - Add Mood Card

struct AddMoodCard: View {
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text("New Mood")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(isHovered ? 0.15 : 0.06), lineWidth: 1)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
