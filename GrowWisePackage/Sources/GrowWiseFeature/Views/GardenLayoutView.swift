// swiftlint:disable file_length
import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - Layout Data Models

// Stored as JSON in Garden.layout — no additional SwiftData models needed.

struct GardenLayoutData: Codable, Equatable {
    var beds: [GardenBedData] = []

    static func from(garden: Garden) -> GardenLayoutData {
        guard
            let json = garden.layout,
            let data = json.data(using: .utf8),
            let layout = try? JSONDecoder().decode(GardenLayoutData.self, from: data)
        else { return GardenLayoutData() }
        return layout
    }

    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct GardenBedData: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var widthFeet: Int
    var heightFeet: Int
    var slots: [[PlantSlot]]

    init(name: String = "Bed", widthFeet: Int = 4, heightFeet: Int = 8) {
        self.name = name
        self.widthFeet = widthFeet
        self.heightFeet = heightFeet
        slots = Array(repeating: Array(repeating: PlantSlot(), count: widthFeet), count: heightFeet)
    }

    var squareFeet: Int {
        widthFeet * heightFeet
    }

    var dimensionLabel: String {
        "\(widthFeet) × \(heightFeet) feet (\(squareFeet) sq ft)"
    }

    mutating func resize(width: Int, height: Int) {
        let clampedWidth = max(1, min(width, 12))
        let clampedHeight = max(1, min(height, 20))
        var newSlots = Array(repeating: Array(repeating: PlantSlot(), count: clampedWidth), count: clampedHeight)
        for row in 0 ..< min(clampedHeight, slots.count) {
            for col in 0 ..< min(clampedWidth, slots[row].count) {
                newSlots[row][col] = slots[row][col]
            }
        }
        slots = newSlots
        widthFeet = clampedWidth
        heightFeet = clampedHeight
    }

    mutating func setSlot(row: Int, col: Int, plant: PlantSlot) {
        guard row < slots.count, col < slots[row].count else { return }
        slots[row][col] = plant
    }

    func slotAt(row: Int, col: Int) -> PlantSlot {
        guard row < slots.count, col < slots[row].count else { return PlantSlot() }
        return slots[row][col]
    }
}

struct PlantSlot: Codable, Equatable {
    var plantName: String?
    var plantTypeRaw: String?

    var isEmpty: Bool {
        plantName == nil
    }

    var plantType: PlantType? {
        plantTypeRaw.flatMap { PlantType(rawValue: $0) }
    }

    var displayEmoji: String {
        switch plantType {
        case .vegetable: "🥦"
        case .herb: "🌿"
        case .flower: "🌸"
        case .houseplant: "🪴"
        case .fruit: "🍓"
        case .succulent: "🌵"
        case .tree: "🌳"
        case .shrub: "🌾"
        case .none: ""
        }
    }

    var slotColor: Color {
        switch plantType {
        case .vegetable: Color(.systemGreen).opacity(0.25)
        case .herb: Color(.systemMint).opacity(0.25)
        case .flower: Color(.systemPink).opacity(0.25)
        case .houseplant: Color(.systemTeal).opacity(0.25)
        case .fruit: Color(.systemOrange).opacity(0.25)
        case .succulent: Color(.systemYellow).opacity(0.25)
        case .tree: Color(.systemBrown).opacity(0.25)
        case .shrub: Color(.systemIndigo).opacity(0.25)
        case .none: Color.clear
        }
    }
}

// MARK: - GardenLayoutView

struct GardenLayoutView: View {
    let garden: Garden
    // swiftlint:disable:next attributes
    @Environment(DataService.self) private var dataService
    @State private var layoutData: GardenLayoutData
    @State private var showingAddBed = false
    @State private var bedBeingEdited: GardenBedData?
    @State private var selectedSlot: SelectedSlot?
    @State private var showAlert = false
    @State private var alertMessage = ""

    struct SelectedSlot: Identifiable {
        let id = UUID()
        let bedID: UUID
        let row: Int
        let col: Int
    }

    init(garden: Garden) {
        self.garden = garden
        _layoutData = State(initialValue: GardenLayoutData.from(garden: garden))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if layoutData.beds.isEmpty {
                    emptyState
                } else {
                    ForEach(layoutData.beds) { bed in
                        BedCard(
                            bed: bed,
                            onSlotTap: { row, col in
                                selectedSlot = SelectedSlot(bedID: bed.id, row: row, col: col)
                            },
                            onEdit: { bedBeingEdited = bed },
                            onDelete: {
                                withAnimation(.easeInOut) {
                                    layoutData.beds.removeAll { $0.id == bed.id }
                                }
                                saveLayout()
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(garden.name ?? "Garden Layout")
        .gwNavigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingAddBed, onDismiss: saveLayout) {
            AddBedSheet(bedNumber: layoutData.beds.count + 1) { name, width, height in
                let newBed = GardenBedData(name: name, widthFeet: width, heightFeet: height)
                withAnimation(.easeInOut) {
                    layoutData.beds.append(newBed)
                }
            }
        }
        .sheet(item: $bedBeingEdited, onDismiss: saveLayout) { bed in
            EditBedSheet(
                initial: bed,
                onSave: { updated in
                    if let idx = layoutData.beds.firstIndex(where: { $0.id == updated.id }) {
                        layoutData.beds[idx] = updated
                    }
                    bedBeingEdited = nil
                    saveLayout()
                },
                onCancel: { bedBeingEdited = nil }
            )
        }
        .sheet(item: $selectedSlot, onDismiss: saveLayout) { slot in
            if let idx = layoutData.beds.firstIndex(where: { $0.id == slot.bedID }) {
                PlantSlotPickerSheet(
                    current: layoutData.beds[idx].slotAt(row: slot.row, col: slot.col),
                    onPick: { newSlot in
                        layoutData.beds[idx].setSlot(row: slot.row, col: slot.col, plant: newSlot)
                        selectedSlot = nil
                        saveLayout()
                    },
                    onClear: {
                        layoutData.beds[idx].setSlot(row: slot.row, col: slot.col, plant: PlantSlot())
                        selectedSlot = nil
                        saveLayout()
                    }
                )
            }
        }
        .onDisappear { saveLayout() }
        .alert("Error Saving", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddBed = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Bed")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .accessibilityLabel("Add garden bed")
            .accessibilityIdentifier("addBedButton")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Beds Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Tap \"+  Bed\" to design your first raised bed or planting area.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Button {
                showingAddBed = true
            } label: {
                Label("Add First Bed", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityIdentifier("addFirstBedButton")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func saveLayout() {
        garden.layout = layoutData.jsonString()
        do {
            try dataService.gardens.update(garden)
        } catch {
            alertMessage = "Could not save layout: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Bed Card

private struct BedCard: View {
    let bed: GardenBedData
    let onSlotTap: (Int, Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bed.name)
                        .font(.headline)
                    Text(bed.dimensionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5), in: Circle())
                    }
                    .accessibilityLabel("Edit \(bed.name)")
                    .accessibilityIdentifier("editBed_\(bed.name)")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 32, height: 32)
                            .background(Color(.systemRed).opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel("Delete \(bed.name)")
                    .accessibilityIdentifier("deleteBed_\(bed.name)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Grid
            BedGridView(bed: bed, onSlotTap: onSlotTap)
                .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Bed Grid View

private struct BedGridView: View {
    let bed: GardenBedData
    let onSlotTap: (Int, Int) -> Void

    private let spacing: CGFloat = 4
    private let minCellSize: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width - spacing * CGFloat(bed.widthFeet - 1)
            let cellSize = max(minCellSize, availableWidth / CGFloat(bed.widthFeet))

            VStack(spacing: spacing) {
                ForEach(0 ..< bed.heightFeet, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0 ..< bed.widthFeet, id: \.self) { col in
                            SlotCell(slot: bed.slotAt(row: row, col: col), size: cellSize) {
                                onSlotTap(row, col)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: gridHeight)
    }

    private var gridHeight: CGFloat {
        let cellSize = minCellSize
        return cellSize * CGFloat(bed.heightFeet) + spacing * CGFloat(bed.heightFeet - 1)
    }
}

// MARK: - Slot Cell

private struct SlotCell: View {
    let slot: PlantSlot
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background: seeding pattern or plant color
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(slot.isEmpty ? Color(red: 0.96, green: 0.94, blue: 0.90) : slot.slotColor)

                if slot.isEmpty {
                    // Dotted soil pattern
                    SeedingPattern()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    // Planted — show emoji
                    Text(slot.displayEmoji)
                        .font(.system(size: size * 0.52))
                }

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(slot.isEmpty ? "Empty slot" : "Planted: \(slot.plantName ?? slot.plantType?.displayName ?? "")")
        .accessibilityHint("Tap to plant")
    }
}

// MARK: - Seeding Pattern (dotted grid texture)

private struct SeedingPattern: View {
    var body: some View {
        Canvas { context, size in
            let dotRadius: CGFloat = 1.2
            let spacing: CGFloat = 8.0
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    let dot = Path(ellipseIn: dotRect)
                    context.fill(dot, with: .color(Color(red: 0.72, green: 0.68, blue: 0.60).opacity(0.7)))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

// MARK: - Add Bed Sheet

private struct AddBedSheet: View {
    let bedNumber: Int
    let onCreate: (String, Int, Int) -> Void

    // swiftlint:disable:next attributes
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var widthFeet: Int = 4
    @State private var heightFeet: Int = 8

    var body: some View {
        NavigationStack {
            Form {
                Section("Bed Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Bed \(bedNumber)", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("bedNameField")
                    }
                }

                Section {
                    Stepper("Width: \(widthFeet) ft", value: $widthFeet, in: 1 ... 12)
                        .accessibilityIdentifier("bedWidthStepper")
                    Stepper("Length: \(heightFeet) ft", value: $heightFeet, in: 1 ... 20)
                        .accessibilityIdentifier("bedLengthStepper")
                } header: {
                    Text("Dimensions")
                } footer: {
                    Text("\(widthFeet * heightFeet) square feet total")
                }

                Section("Preview") {
                    HStack {
                        Spacer()
                        BedPreviewMini(widthFeet: widthFeet, heightFeet: heightFeet)
                        Spacer()
                    }
                    .listRowBackground(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("New Bed")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Bed \(bedNumber)"
                            : name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(resolvedName, widthFeet, heightFeet)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("addBedConfirmButton")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Bed Sheet

private struct EditBedSheet: View {
    let initial: GardenBedData
    let onSave: (GardenBedData) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var widthFeet: Int
    @State private var heightFeet: Int

    init(initial: GardenBedData, onSave: @escaping (GardenBedData) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _widthFeet = State(initialValue: initial.widthFeet)
        _heightFeet = State(initialValue: initial.heightFeet)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bed Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Bed name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Stepper("Width: \(widthFeet) ft", value: $widthFeet, in: 1 ... 12)
                    Stepper("Length: \(heightFeet) ft", value: $heightFeet, in: 1 ... 20)
                } header: {
                    Text("Dimensions")
                } footer: {
                    Text("\(widthFeet * heightFeet) sq ft — shrinking removes plants from trimmed cells")
                }

                Section("Preview") {
                    HStack {
                        Spacer()
                        BedPreviewMini(widthFeet: widthFeet, heightFeet: heightFeet)
                        Spacer()
                    }
                    .listRowBackground(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Edit Bed")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        var updated = initial
                        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? initial.name : name
                        updated.resize(width: widthFeet, height: heightFeet)
                        onSave(updated)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Bed Preview Mini

private struct BedPreviewMini: View {
    let widthFeet: Int
    let heightFeet: Int

    private let cellSize: CGFloat = 10
    private let spacing: CGFloat = 2

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0 ..< min(heightFeet, 10), id: \.self) { _ in
                HStack(spacing: spacing) {
                    ForEach(0 ..< min(widthFeet, 12), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.94, blue: 0.90))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                            )
                            .frame(width: cellSize, height: cellSize)
                    }
                    if widthFeet > 12 {
                        Text("…").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            }
            if heightFeet > 10 {
                Text("…").font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Plant Slot Picker Sheet

private struct PlantSlotPickerSheet: View {
    let current: PlantSlot
    let onPick: (PlantSlot) -> Void
    let onClear: () -> Void

    // swiftlint:disable:next attributes
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !current.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            onClear()
                            dismiss()
                        } label: {
                            Label("Clear slot", systemImage: "xmark.circle")
                        }
                        .accessibilityIdentifier("clearSlotButton")
                    }
                }

                Section("Choose a plant type") {
                    ForEach(PlantType.allCases, id: \.self) { type in
                        Button {
                            let slot = PlantSlot(plantName: type.displayName, plantTypeRaw: type.rawValue)
                            onPick(slot)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(emojiFor(type))
                                    .font(.title3)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .foregroundStyle(.primary)
                                    Text(descriptionFor(type))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if current.plantType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .accessibilityIdentifier("plantType_\(type.rawValue)")
                    }
                }
            }
            .navigationTitle(current.isEmpty ? "What's here?" : "Change plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func emojiFor(_ type: PlantType) -> String {
        switch type {
        case .vegetable: "🥦"
        case .herb: "🌿"
        case .flower: "🌸"
        case .houseplant: "🪴"
        case .fruit: "🍓"
        case .succulent: "🌵"
        case .tree: "🌳"
        case .shrub: "🌾"
        }
    }

    private func descriptionFor(_ type: PlantType) -> String {
        switch type {
        case .vegetable: "Tomatoes, peppers, squash…"
        case .herb: "Basil, mint, rosemary…"
        case .flower: "Marigolds, sunflowers…"
        case .houseplant: "Pothos, ferns…"
        case .fruit: "Strawberries, blueberries…"
        case .succulent: "Aloe, sedum…"
        case .tree: "Dwarf fruit trees…"
        case .shrub: "Lavender, rosebush…"
        }
    }
}

// MARK: - Preview

#Preview("Garden Layout - Empty") {
    let dataService = DataService.createFallback()
    let garden = Garden(name: "My Backyard Garden", gardenType: .raised)
    NavigationStack {
        GardenLayoutView(garden: garden)
            .environment(dataService)
    }
}

#Preview("Garden Layout - With Beds") {
    let dataService = DataService.createFallback()
    let garden = Garden(name: "Raised Bed Garden", gardenType: .raised)

    var layout = GardenLayoutData()
    var bed1 = GardenBedData(name: "Bed 1", widthFeet: 4, heightFeet: 8)
    bed1.setSlot(row: 0, col: 0, plant: PlantSlot(plantName: "Tomato", plantTypeRaw: PlantType.vegetable.rawValue))
    bed1.setSlot(row: 0, col: 1, plant: PlantSlot(plantName: "Basil", plantTypeRaw: PlantType.herb.rawValue))
    bed1.setSlot(row: 2, col: 3, plant: PlantSlot(plantName: "Marigold", plantTypeRaw: PlantType.flower.rawValue))
    layout.beds = [bed1, GardenBedData(name: "Herb Spiral", widthFeet: 3, heightFeet: 3)]
    garden.layout = layout.jsonString()

    return NavigationStack {
        GardenLayoutView(garden: garden)
            .environment(dataService)
    }
}
