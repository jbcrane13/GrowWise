import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes file_length identifier_name line_length

public struct ClubEventsView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let club: GardenClub

    @State private var events: [ClubEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var selectedEvent: ClubEvent?

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }

    private var upcomingEvents: [ClubEvent] {
        events.filter { ($0.startDate ?? .distantPast) >= Date() }
    }

    private var pastEvents: [ClubEvent] {
        events.filter { ($0.startDate ?? .distantPast) < Date() }
    }

    public init(club: GardenClub) {
        self.club = club
    }

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            scrollContent
        }
        .navigationTitle("Events")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent }
            .task { await loadEvents() }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
                    .accessibilityIdentifier("club_events_button_error_dismiss")
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateEventSheet(club: club) { newEvent in
                    events.append(newEvent)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event, clubID: club.id ?? UUID()) { updated in
                    if let idx = events.firstIndex(where: { $0.id == updated.id }) {
                        events[idx] = updated
                    }
                }
            }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    upcomingSection
                    if !pastEvents.isEmpty {
                        pastSection
                    }
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Upcoming Events")
                .sectionLabelStyle()

            if upcomingEvents.isEmpty {
                emptyStateCard
            } else {
                ForEach(upcomingEvents, id: \.id) { event in
                    eventCard(event: event)
                        .onTapGesture { selectedEvent = event }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("club_events_card_\(event.id?.uuidString ?? "unknown")")
                }
            }
        }
    }

    // MARK: - Past Section

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Past Events")
                .sectionLabelStyle()

            ForEach(pastEvents, id: \.id) { event in
                eventCard(event: event)
                    .onTapGesture { selectedEvent = event }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("club_events_card_\(event.id?.uuidString ?? "unknown")")
            }
        }
    }

    // MARK: - Event Card

    private func eventCard(event: ClubEvent) -> some View {
        let isPast = (event.startDate ?? .distantPast) < Date()
        let accepted = event.rsvpAccepted ?? []
        let declined = event.rsvpDeclined ?? []
        let maybe = event.rsvpMaybe ?? []

        return VStack(alignment: .leading, spacing: 12) {
            // Title & Date
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title ?? "Untitled Event")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text(formatDateRange(event.startDate, end: event.endDate))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()

                if isPast {
                    Text("Past")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CultivationTheme.Colors.textTertiary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
                }
            }

            // Location
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "location.fill")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            // RSVP Summary
            HStack(spacing: 12) {
                Label("\(accepted.count) going", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                Label("\(maybe.count) maybe", systemImage: "questionmark.circle.fill")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.accentAmber)
                Label("\(declined.count) not going", systemImage: "xmark.circle.fill")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Colors.brandMint.opacity(0.2))
                    .frame(width: 64, height: 64)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }

            Text("No Upcoming Events")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Create a garden meetup, seed swap, or workshop!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showCreateSheet = true
            } label: {
                Text("Create Event")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(CultivationTheme.Gradients.ctaVertical)
                    .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.button))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("club_events_button_create_empty")
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
            }
            .accessibilityIdentifier("club_events_add_button")
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let clubID = club.id else { return }
            events = try dataService.fetchClubEvents(for: clubID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatDateRange(_ start: Date?, end: Date?) -> String {
        guard let start else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short

        if let end, !Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(f.string(from: start)) – \(f.string(from: end))"
        }
        return f.string(from: start)
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let club: GardenClub
    let onCreate: (ClubEvent) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate: Date?
    @State private var showEndDate = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                formContent
            }
            .navigationTitle("New Event")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("club_events_create_button_cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task { await createEvent() }
                        }
                        .disabled(title.isEmpty || isCreating)
                        .accessibilityIdentifier("club_events_create_button_create")
                    }
                }
                .alert("Error", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") { errorMessage = nil }
                        .accessibilityIdentifier("club_events_create_button_error_dismiss")
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    private var formContent: some View {
        Form {
            Section("Details") {
                TextField("Event Title", text: $title)
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
                    .accessibilityIdentifier("club_events_create_textfield_title")
                TextField("Description (optional)", text: $description)
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif
                    .accessibilityIdentifier("club_events_create_textfield_description")
            }

            Section("Location") {
                TextField("Location (optional)", text: $location)
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
                    .accessibilityIdentifier("club_events_create_textfield_location")
            }

            Section("Date & Time") {
                DatePicker("Starts", selection: $startDate)
                    .accessibilityIdentifier("club_events_create_datepicker_starts")
                Toggle("End Date", isOn: $showEndDate)
                    .accessibilityIdentifier("club_events_create_toggle_end_date")
                if showEndDate {
                    DatePicker("Ends", selection: Binding(
                        get: { endDate ?? startDate.addingTimeInterval(3600) },
                        set: { endDate = $0 }
                    ))
                    .accessibilityIdentifier("club_events_create_datepicker_ends")
                }
            }
        }
        .formStyle(.grouped)
    }

    @MainActor
    private func createEvent() async {
        isCreating = true
        defer { isCreating = false }
        do {
            guard let clubID = club.id else { return }
            let event = try dataService.createClubEvent(
                clubID: clubID,
                title: title,
                description: description.isEmpty ? nil : description,
                location: location.isEmpty ? nil : location,
                startDate: startDate,
                endDate: showEndDate ? endDate : nil,
                createdBy: currentUserID
            )
            onCreate(event)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    let event: ClubEvent
    let clubID: UUID
    let onUpdate: (ClubEvent) -> Void

    @State private var rsvpResponse: ClubRSVPResponse?
    @State private var errorMessage: String?

    private var currentUserID: String {
        dataService.getCurrentUser()?.id.uuidString ?? ""
    }

    private var currentRSVP: ClubRSVPResponse? {
        let accepted = event.rsvpAccepted ?? []
        let declined = event.rsvpDeclined ?? []
        let maybe = event.rsvpMaybe ?? []

        if accepted.contains(currentUserID) { return .accepted }
        if declined.contains(currentUserID) { return .declined }
        if maybe.contains(currentUserID) { return .maybe }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                detailContent
            }
            .navigationTitle(event.title ?? "Event")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("club_events_detail_button_done")
                    }
                }
                .alert("Error", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") { errorMessage = nil }
                        .accessibilityIdentifier("club_events_detail_button_error_dismiss")
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title ?? "Untitled Event")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Label(formatDateRange(event.startDate, end: event.endDate), systemImage: "calendar")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()

                // Description
                if let desc = event.eventDescription, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .sectionLabelStyle()
                        Text(desc)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
                }

                // RSVP
                rsvpSection

                // Attendees
                attendeesSection
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
    }

    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Your RSVP")
                .sectionLabelStyle()

            HStack(spacing: 12) {
                rsvpButton(response: .accepted, icon: "checkmark.circle.fill", label: "Going", color: CultivationTheme.Colors.statusHealthy)
                rsvpButton(response: .maybe, icon: "questionmark.circle.fill", label: "Maybe", color: CultivationTheme.Colors.accentAmber)
                rsvpButton(response: .declined, icon: "xmark.circle.fill", label: "Not Going", color: CultivationTheme.Colors.statusAlert)
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    private func rsvpButton(response: ClubRSVPResponse, icon: String, label: String, color: Color) -> some View {
        Button {
            Task { await submitRSVP(response: response) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(currentRSVP == response ? color.opacity(0.2) : CultivationTheme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rsvp_\(response.rawValue)")
    }

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Attendees")
                .sectionLabelStyle()

            let going = event.rsvpAccepted ?? []
            let maybe = event.rsvpMaybe ?? []

            if going.isEmpty, maybe.isEmpty {
                Text("No attendees yet")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            } else {
                if !going.isEmpty {
                    attendeeList(attendees: going, label: "Going")
                }
                if !maybe.isEmpty {
                    attendeeList(attendees: maybe, label: "Maybe")
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }

    private func attendeeList(attendees: [String], label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            ForEach(attendees.prefix(5), id: \.self) { id in
                HStack(spacing: 8) {
                    Circle()
                        .fill(CultivationTheme.Colors.brandMint)
                        .frame(width: 24, height: 24)
                    Text(id.prefix(8) + "…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }

            if attendees.count > 5 {
                Text("+ \(attendees.count - 5) more")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }

    @MainActor
    private func submitRSVP(response: ClubRSVPResponse) async {
        do {
            try dataService.rsvpToEvent(event, memberID: currentUserID, response: response)
            var updated = event
            // Update local state for immediate UI feedback
            switch response {
            case .accepted:
                updated.rsvpAccepted = (updated.rsvpAccepted ?? []) + [currentUserID]

            case .declined:
                updated.rsvpDeclined = (updated.rsvpDeclined ?? []) + [currentUserID]

            case .maybe:
                updated.rsvpMaybe = (updated.rsvpMaybe ?? []) + [currentUserID]
            }
            onUpdate(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatDateRange(_ start: Date?, end: Date?) -> String {
        guard let start else { return "" }
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short

        if let end, !Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(f.string(from: start)) – \(f.string(from: end))"
        }
        return f.string(from: start)
    }
}

#Preview {
    let club = GardenClub(name: "Test Club", ownerID: "user1", inviteCode: "TEST42")
    NavigationStack {
        ClubEventsView(club: club)
    }
}

// swiftlint:enable attributes file_length identifier_name line_length
