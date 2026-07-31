import SwiftUI
import SwiftData
import AppCore
import DesignSystem
import UserNotifications

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @Query private var answers: [AnswerRecord]
    @Environment(\.modelContext) private var context
    @Environment(SaveErrorState.self) private var saveError

    @State private var showResetConfirm = false
    @State private var exportData: Data? = nil
    @State private var showExportSheet = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            if let profile {
                goalSection(profile)
                activitySection(profile)
                notificationsSection(profile)
                dataSection
            }
            versionFooter
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears all answers, sessions, and mastery. Your topics stay.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let data = exportData {
                ShareSheet(data: data, filename: "callback-export.json")
            }
        }
    }

    // MARK: Goal section

    @ViewBuilder
    private func goalSection(_ profile: UserProfile) -> some View {
        @Bindable var profile = profile
        Section("Goal") {
            Picker("Target role", selection: $profile.targetRole) {
                ForEach(["iOS Engineer", "Senior iOS Engineer", "Mobile Lead"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            Picker("Level", selection: $profile.level) {
                ForEach(Level.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .pickerStyle(.menu)
            DatePicker("Target date", selection: targetDateBinding(profile),
                       displayedComponents: .date)
            Stepper(
                value: $profile.dailyGoal, in: 5...50, step: 5
            ) {
                HStack {
                    Text("Daily goal")
                    Spacer()
                    Text("\(profile.dailyGoal) questions")
                        .foregroundStyle(DSColor.secondaryLabel)
                        .monospacedDigit()
                }
            }
        }
        .onChange(of: profile.targetRole) { _, _ in trySave() }
        .onChange(of: profile.level) { _, _ in trySave() }
        .onChange(of: profile.dailyGoal) { _, _ in trySave() }
        .onChange(of: profile.targetDate) { _, _ in trySave() }
    }

    private func targetDateBinding(_ profile: UserProfile) -> Binding<Date> {
        Binding(
            get: { profile.targetDate ?? Date() },
            set: { profile.targetDate = $0; trySave() }
        )
    }

    // MARK: Activity section

    @ViewBuilder
    private func activitySection(_ profile: UserProfile) -> some View {
        Section("Activity") {
            WeeklyBarChart(values: profile.weeklyActivity, currentIndex: 11)
                .frame(height: 80)
                .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
            NavigationLink("All sessions") {
                sessionListView
            }
            NavigationLink("Answer history") {
                answerHistoryView
            }
        }
    }

    private var sessionListView: some View {
        List(sessions) { session in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionKindLabel(session.kind))
                        .font(DSFont.body)
                    Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
                Spacer()
                Text("\(session.score)%")
                    .font(DSFont.footnote)
                    .monospacedDigit()
                    .foregroundStyle(DSColor.secondaryLabel)
            }
        }
        .navigationTitle("All sessions")
    }

    private var answerHistoryView: some View {
        List(answers.sorted { $0.answeredAt > $1.answeredAt }.prefix(100), id: \.persistentModelID) { record in
            HStack {
                Image(systemName: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(record.isCorrect ? DSColor.green : DSColor.red)
                Text(record.questionID)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)
                    .lineLimit(1)
                Spacer()
                Text(record.answeredAt.formatted(date: .omitted, time: .shortened))
                    .font(DSFont.badge)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
        }
        .navigationTitle("Answer history")
    }

    private func sessionKindLabel(_ kind: SessionKind) -> String {
        switch kind {
        case .mock: return "Mock Interview"
        case .rapidFire: return "Rapid Fire"
        case .codeReview: return "Code Review"
        case .systemDesign: return "System Design"
        case .behavioral: return "Behavioral"
        }
    }

    // MARK: Notifications section

    @ViewBuilder
    private func notificationsSection(_ profile: UserProfile) -> some View {
        @Bindable var profile = profile
        Section("Notifications") {
            Toggle("Daily reminder", isOn: Binding(
                get: { profile.notificationsEnabled },
                set: { enabled in handleNotificationToggle(enabled, profile: profile) }
            ))
            if profile.notificationsEnabled {
                DatePicker("Reminder time",
                           selection: reminderTimeBinding(profile),
                           displayedComponents: .hourAndMinute)
            }
        }
    }

    private func reminderTimeBinding(_ profile: UserProfile) -> Binding<Date> {
        let defaultTime: Date = {
            var c = Calendar.current.dateComponents([.hour, .minute], from: Date())
            c.hour = 19; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        }()
        return Binding(
            get: { profile.reminderTime ?? defaultTime },
            set: {
                profile.reminderTime = $0
                scheduleNotification(for: profile)
                trySave()
            }
        )
    }

    private func handleNotificationToggle(_ enabled: Bool, profile: UserProfile) {
        if enabled {
            Task {
                let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                if granted {
                    profile.notificationsEnabled = true
                    scheduleNotification(for: profile)
                    trySave()
                } else {
                    profile.notificationsEnabled = false
                }
            }
        } else {
            profile.notificationsEnabled = false
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            trySave()
        }
    }

    private func scheduleNotification(for profile: UserProfile) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard profile.notificationsEnabled, let time = profile.reminderTime else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to prep"
        content.body = "Your \(profile.dailyGoal) questions for today are waiting."
        content.sound = .default
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "callback.daily", content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: Data section

    private var dataSection: some View {
        Section("Data") {
            Button("Export data") {
                do {
                    exportData = try DataExporter.makeJSON(context: context)
                    showExportSheet = true
                } catch {
                    saveError.message = "Couldn't export data. Please try again."
                }
            }
            Button("Reset progress", role: .destructive) {
                showResetConfirm = true
            }
            .foregroundStyle(DSColor.red)
        }
    }

    // MARK: Version footer

    private var versionFooter: some View {
        Section {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? "?"
            HStack {
                Spacer()
                Text("v\(version) (\(build))")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)
                    .monospacedDigit()
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }

    // MARK: Reset

    private func resetProgress() {
        let allAnswers = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let allSessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let allTopics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        allAnswers.forEach { context.delete($0) }
        allSessions.forEach { context.delete($0) }
        allTopics.forEach { $0.mastery = 0; $0.isSaved = false }
        if let p = profiles.first {
            p.readiness = 0; p.readinessDelta = 0; p.streakDays = 0
            p.answeredCount = 0; p.accuracy = 0
            p.weeklyActivity = Array(repeating: 0, count: 12)
            p.hasCompletedPlacement = false
        }
        trySave()
    }

    // MARK: Save helper

    private func trySave() {
        do {
            try context.save()
        } catch {
            saveError.message = "Couldn't save your changes. Please try again."
        }
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
    .environment(SaveErrorState())
}
