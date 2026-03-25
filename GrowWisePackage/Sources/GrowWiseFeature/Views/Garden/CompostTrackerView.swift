import GrowWiseModels
import SwiftData
import SwiftUI

// MARK: - CompostTrackerView

/// Dedicated compost batch tracker showing active and completed batches
/// with temperature/moisture logging and readiness indicators.
public struct CompostTrackerView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Query(sort: \CompostBatch.startDate, order: .reverse)
    private var batches: [CompostBatch]

    @State private var showAddBatch = false
    @State private var selectedBatch: CompostBatch?
    @State private var showLogEntry = false
    @State private var batchForLog: CompostBatch?
    @State private var filterActive = true

    public init() {}

    private var filteredBatches: [CompostBatch] {
        batches.filter { filterActive ? !$0.isComplete : $0.isComplete }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                // Header
                header

                // Filter pills
                filterRow

                if filteredBatches.isEmpty {
                    emptyState
                } else {
                    // Batch cards
                    LazyVStack(spacing: 12) {
                        ForEach(filteredBatches, id: \.id) { batch in
                            CompostBatchCard(
                                batch: batch,
                                onTap: { selectedBatch = batch },
                                onLog: {
                                    batchForLog = batch
                                    showLogEntry = true
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 32)
        }
        .background(CultivationTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Compost Tracker")
        .gwNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddBatch = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(CultivationTheme.Gradients.ctaVertical)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("compost_add_button")
            }
        }
        .sheet(isPresented: $showAddBatch, content: {
            AddCompostBatchSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        })
        .sheet(item: $selectedBatch, content: { batch in
            CompostBatchDetailSheet(batch: batch, onLog: {
                selectedBatch = nil
                Task<Void, Never> { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    batchForLog = batch
                    showLogEntry = true
                }
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        })
        .sheet(isPresented: $showLogEntry, content: {
            if let batch = batchForLog {
                CompostLogEntrySheet(batch: batch)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
        })
        .accessibilityIdentifier("compost_list")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("COMPOSTING")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .tracking(0.5)
            Text("Compost Batches")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
        }
        .padding(.top, 16)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(spacing: 8) {
            GlassPill(
                label: "Active",
                isSelected: filterActive,
                accessibilityID: "compost_filter_active"
            ) {
                withAnimation(CultivationTheme.Animation.selection) {
                    filterActive = true
                }
            }
            GlassPill(
                label: "Completed",
                isSelected: !filterActive,
                accessibilityID: "compost_filter_completed"
            ) {
                withAnimation(CultivationTheme.Animation.selection) {
                    filterActive = false
                }
            }
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBubble(
                systemName: "leaf.arrow.circlepath",
                color: CultivationTheme.Colors.brandSage,
                size: 64,
                iconSize: 28
            )
            Text(filterActive ? "No active batches" : "No completed batches")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text(
                filterActive
                    ? "Start composting by adding your first batch"
                    : "Completed batches will appear here"
            )
            .font(.system(.subheadline))
            .foregroundStyle(CultivationTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)

            if filterActive {
                Button("Start a Batch") {
                    showAddBatch = true
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal, 40)
                .accessibilityIdentifier("compost_button_start_first")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - CompostBatchCard

private struct CompostBatchCard: View {
    let batch: CompostBatch
    let onTap: () -> Void
    let onLog: () -> Void

    private var batchID: String {
        batch.id?.uuidString ?? "unknown"
    }

    private var daysActive: Int {
        guard let start = batch.startDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
    }

    private var lastTemperature: Double? {
        batch.temperatures.last
    }

    private var lastMoisture: Double? {
        batch.moistureLevels.last
    }

    private var readiness: CompostReadiness {
        guard daysActive >= 60,
              let temp = lastTemperature, temp < 100,
              let moisture = lastMoisture, moisture >= 40, moisture <= 60
        else {
            if daysActive < 14 {
                return .new
            }
            if let temp = lastTemperature, temp >= 130 {
                return .heating
            }
            return .active
        }
        return .ready
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Top row: name + readiness badge
                HStack {
                    IconBubble(
                        systemName: "leaf.arrow.circlepath",
                        color: readiness.color,
                        size: CultivationTheme.Spacing.iconSize,
                        iconSize: 20
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(batch.name ?? "Unnamed Batch")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)

                        Text("\(daysActive) days active")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }

                    Spacer()

                    readinessBadge
                }

                // Stats row
                HStack(spacing: 14) {
                    if let temp = lastTemperature {
                        statLabel(
                            icon: "thermometer.medium",
                            value: "\(Int(temp))\u{00B0}F",
                            color: temperatureColor(temp)
                        )
                    }
                    if let moisture = lastMoisture {
                        statLabel(
                            icon: "drop.fill",
                            value: "\(Int(moisture))%",
                            color: moistureColor(moisture)
                        )
                    }
                    if !batch.turnDates.isEmpty {
                        let daysSinceTurn = daysSinceLastTurn
                        statLabel(
                            icon: "arrow.triangle.2.circlepath",
                            value: daysSinceTurn == 0 ? "Today" : "\(daysSinceTurn)d ago",
                            color: CultivationTheme.Colors.brandSage
                        )
                    }

                    Spacer()

                    // Log button
                    Button {
                        onLog()
                    } label: {
                        Text("Log")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.08))
                            }
                            .overlay {
                                Capsule()
                                    .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.35), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("compost_log_button_\(batchID)")
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("compost_batch_card_\(batchID)")
    }

    // MARK: - Readiness Badge

    private var readinessBadge: some View {
        Text(readiness.label)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(readiness.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(readiness.color.opacity(0.12))
            }
            .overlay {
                Capsule()
                    .stroke(readiness.color.opacity(0.3), lineWidth: 1)
            }
    }

    // MARK: - Helpers

    private func statLabel(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp >= 130 { return CultivationTheme.Colors.statusAlert }
        if temp >= 100 { return CultivationTheme.Colors.statusWarning }
        return CultivationTheme.Colors.statusHealthy
    }

    private func moistureColor(_ moisture: Double) -> Color {
        if moisture >= 40, moisture <= 60 { return CultivationTheme.Colors.statusHealthy }
        if moisture >= 30, moisture <= 70 { return CultivationTheme.Colors.statusWarning }
        return CultivationTheme.Colors.statusAlert
    }

    private var daysSinceLastTurn: Int {
        guard let lastTurn = batch.turnDates.last else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastTurn, to: Date()).day ?? 0
    }
}

// MARK: - CompostReadiness

private enum CompostReadiness {
    case new, active, heating, ready

    var label: String {
        switch self {
        case .new: "NEW"
        case .active: "ACTIVE"
        case .heating: "HEATING"
        case .ready: "READY"
        }
    }

    var color: Color {
        switch self {
        case .new: CultivationTheme.Colors.statusAlert
        case .active: CultivationTheme.Colors.statusWarning
        case .heating: CultivationTheme.Colors.statusWarning
        case .ready: CultivationTheme.Colors.statusHealthy
        }
    }
}

// MARK: - CompostBatchDetailSheet

private struct CompostBatchDetailSheet: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss)
    private var dismiss

    let batch: CompostBatch
    let onLog: () -> Void

    @State private var showCompleteConfirmation = false

    private var daysActive: Int {
        guard let start = batch.startDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    // Drag handle
                    Capsule()
                        .fill(CultivationTheme.Colors.cardBorder)
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    // Batch info header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IconBubble(
                                systemName: "leaf.arrow.circlepath",
                                color: CultivationTheme.Colors.brandSage,
                                size: 52,
                                iconSize: 24
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(batch.name ?? "Unnamed Batch")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                if let startDate = batch.startDate {
                                    Text("Started \(startDate, style: .date)")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                }
                            }
                            Spacer()
                        }

                        // Stats strip
                        HStack(spacing: 10) {
                            QuickStatCard(
                                value: daysActive,
                                label: "Days",
                                color: CultivationTheme.Colors.brandLeaf
                            )
                            QuickStatCard(
                                value: batch.logDates.count,
                                label: "Logs",
                                color: CultivationTheme.Colors.brandSage
                            )
                            QuickStatCard(
                                value: batch.turnDates.count,
                                label: "Turns",
                                color: CultivationTheme.Colors.brandGold
                            )
                        }
                    }

                    // Materials
                    if !batch.greenMaterials.isEmpty || !batch.brownMaterials.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Materials")
                                .sectionLabelStyle()

                            if !batch.greenMaterials.isEmpty {
                                materialRow(
                                    label: "Greens",
                                    items: batch.greenMaterials,
                                    color: CultivationTheme.Colors.statusHealthy
                                )
                            }
                            if !batch.brownMaterials.isEmpty {
                                materialRow(
                                    label: "Browns",
                                    items: batch.brownMaterials,
                                    color: CultivationTheme.Colors.brandGold
                                )
                            }
                        }
                    }

                    // Notes
                    if let notes = batch.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .sectionLabelStyle()
                            Text(notes)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                .padding(CultivationTheme.Spacing.cardPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard()
                        }
                    }

                    // Log history
                    if !batch.logDates.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Log History")
                                .sectionLabelStyle()

                            ForEach(Array(batch.logDates.enumerated().reversed()), id: \.offset) { index, date in
                                logHistoryRow(index: index, date: date)
                            }
                        }
                    }

                    // Actions
                    VStack(spacing: 10) {
                        Button("Add Log Entry") {
                            dismiss()
                            onLog()
                        }
                        .buttonStyle(GradientButtonStyle())
                        .accessibilityIdentifier("compost_detail_button_log")

                        if !batch.isComplete {
                            Button("Mark as Complete") {
                                showCompleteConfirmation = true
                            }
                            .buttonStyle(OutlineButtonStyle())
                            .accessibilityIdentifier("compost_detail_button_complete")
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.backgroundSecondary.ignoresSafeArea())
            .navigationTitle("Batch Details")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("compost_detail_button_close")
                }
            }
            .alert("Mark as Complete?", isPresented: $showCompleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Complete", role: .destructive) {
                    batch.isComplete = true
                    try? modelContext.save()
                    dismiss()
                }
            } message: {
                Text("This batch will be moved to your completed list.")
            }
        }
    }

    private func materialRow(label: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(color)

            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            Capsule()
                                .fill(color.opacity(0.08))
                        }
                        .overlay {
                            Capsule()
                                .stroke(color.opacity(0.2), lineWidth: 1)
                        }
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func logHistoryRow(index: Int, date: Date) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, style: .date)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text(date, style: .time)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }

            Spacer()

            if index < batch.temperatures.count {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.statusWarning)
                    Text("\(Int(batch.temperatures[index]))\u{00B0}F")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }

            if index < batch.moistureLevels.count {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                    Text("\(Int(batch.moistureLevels[index]))%")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
    }
}

// MARK: - FlowLayout

/// Simple flow layout for material chips that wraps to new lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}
