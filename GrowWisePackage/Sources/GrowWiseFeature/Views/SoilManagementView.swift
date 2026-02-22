import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices

/// View for managing and displaying soil conditions
public struct SoilManagementView: View {
    let garden: Garden?
    let plant: Plant?
    
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var soilLogs: [SoilLog] = []
    @State private var showingAddLog = false
    @State private var selectedLog: SoilLog?
    
    public init(garden: Garden? = nil, plant: Plant? = nil) {
        self.garden = garden
        self.plant = plant
    }
    
    public var body: some View {
        List {
            if let latestLog = soilLogs.first {
                CurrentSoilConditionsSection(log: latestLog)
            }
            
            if !soilLogs.isEmpty {
                SoilHistorySection(logs: soilLogs, selectedLog: $selectedLog)
            } else {
                Section {
                    ContentUnavailableView {
                        Label("No Soil Data", systemImage: "testtube.2")
                    } description: {
                        Text("Add your first soil test to track pH, N-P-K levels, and fertilizer history.")
                    } actions: {
                        Button("Add Soil Test") {
                            showingAddLog = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Soil Management")
        .gwNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Test") {
                    showingAddLog = true
                }
            }
        }
        .sheet(isPresented: $showingAddLog) {
            AddSoilLogSheet(garden: garden, plant: plant)
        }
        .sheet(item: $selectedLog) { log in
            SoilLogDetailSheet(log: log)
        }
        .task {
            await loadSoilLogs()
        }
        .refreshable {
            await loadSoilLogs()
        }
    }
    
    private func loadSoilLogs() async {
        let descriptor = FetchDescriptor<SoilLog>(
            sortBy: [SortDescriptor(\.logDate, order: .reverse)]
        )
        
        do {
            let allLogs = try modelContext.fetch(descriptor)
            
            // Filter by garden or plant if specified
            if let garden = garden {
                soilLogs = allLogs.filter { $0.garden?.id == garden.id }
            } else if let plant = plant {
                soilLogs = allLogs.filter { $0.plant?.id == plant.id }
            } else {
                soilLogs = allLogs
            }
        } catch {
            print("Failed to load soil logs: \(error)")
        }
    }
}

// MARK: - Current Soil Conditions Section

struct CurrentSoilConditionsSection: View {
    let log: SoilLog
    
    var body: some View {
        Section("Current Soil Conditions") {
            VStack(spacing: 16) {
                if let ph = log.phLevel {
                    PHGaugeView(ph: ph)
                }
                
                if let npk = log.npkDisplay {
                    NPKCardView(npk: npk)
                }
                
                if let fertilizer = log.fertilizerApplied {
                    FertilizerCardView(
                        fertilizer: fertilizer,
                        amount: log.fertilizerAmount,
                        type: log.fertilizerType
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - pH Gauge View

struct PHGaugeView: View {
    let ph: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("pH Level")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f", ph))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(phColor)
            }
            
            // pH Scale visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background gradient from acidic (red) to alkaline (blue)
                    LinearGradient(
                        colors: [
                            Color.red,
                            Color.orange,
                            Color.yellow,
                            Color.green,
                            Color.blue
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 12)
                    .cornerRadius(6)
                    
                    // Indicator
                    let position = (ph / 14.0) * geometry.size.width
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .overlay(
                            Circle()
                                .stroke(phColor, lineWidth: 3)
                        )
                        .position(x: min(max(position, 10), geometry.size.width - 10), y: 6)
                }
            }
            .frame(height: 20)
            
            HStack {
                Text("Acidic (0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(phStatus)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(phColor)
                Spacer()
                Text("Alkaline (14)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var phColor: Color {
        if ph < 5.5 { return .red }
        if ph < 6.0 { return .orange }
        if ph <= 7.0 { return .green }
        if ph <= 7.5 { return .yellow }
        return .blue
    }
    
    private var phStatus: String {
        if ph < 5.5 { return "Very Acidic" }
        if ph < 6.0 { return "Acidic" }
        if ph <= 7.0 { return "Optimal" }
        if ph <= 7.5 { return "Slightly Alkaline" }
        return "Alkaline"
    }
}

// MARK: - NPK Card View

struct NPKCardView: View {
    let npk: String
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("N-P-K Levels")
                    .font(.headline)
                Text("Nutrient concentration in ppm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(npk)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Fertilizer Card View

struct FertilizerCardView: View {
    let fertilizer: String
    let amount: String?
    let type: FertilizerType?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type?.iconName ?? "flask.fill")
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Last Fertilizer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(fertilizer)
                    .font(.headline)
                if let amount = amount {
                    Text(amount)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let type = type {
                Text(type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Soil History Section

struct SoilHistorySection: View {
    let logs: [SoilLog]
    @Binding var selectedLog: SoilLog?
    
    var body: some View {
        Section("Soil Test History") {
            ForEach(logs) { log in
                Button {
                    selectedLog = log
                } label: {
                    SoilLogRow(log: log)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Soil Log Row

struct SoilLogRow: View {
    let log: SoilLog
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let date = log.logDate {
                    Text(date, style: .date)
                        .font(.headline)
                }
                
                HStack(spacing: 12) {
                    if let ph = log.phLevel {
                        Label(String(format: "pH %.1f", ph), systemImage: "testtube.2")
                            .font(.caption)
                            .foregroundColor(phColor(ph))
                    }
                    
                    if let npk = log.npkDisplay {
                        Label(npk, systemImage: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if log.fertilizerApplied != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func phColor(_ ph: Double) -> Color {
        if ph < 6.0 { return .orange }
        if ph > 7.0 { return .yellow }
        return .green
    }
}

// MARK: - Add Soil Log Sheet

struct AddSoilLogSheet: View {
    let garden: Garden?
    let plant: Plant?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var logDate = Date()
    @State private var phLevel: String = ""
    @State private var nitrogenLevel: String = ""
    @State private var phosphorusLevel: String = ""
    @State private var potassiumLevel: String = ""
    @State private var organicMatter: String = ""
    
    @State private var fertilizerApplied = ""
    @State private var fertilizerAmount = ""
    @State private var selectedFertilizerType: FertilizerType?
    @State private var notes = ""
    
    @State private var showFertilizerSection = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Test Date") {
                    DatePicker("Date", selection: $logDate, displayedComponents: .date)
                }
                
                Section("pH Level") {
                    HStack {
                        TextField("pH (0-14)", text: $phLevel)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        if let ph = Double(phLevel), ph >= 0, ph <= 14 {
                            Text(phStatus(ph))
                                .font(.caption)
                                .foregroundColor(phColor(ph))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(phColor(ph).opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Section("N-P-K Levels (ppm)") {
                    HStack {
                        TextField("N", text: $nitrogenLevel)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        TextField("P", text: $phosphorusLevel)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        TextField("K", text: $potassiumLevel)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    
                    if let n = Double(nitrogenLevel),
                       let p = Double(phosphorusLevel),
                       let k = Double(potassiumLevel) {
                        HStack {
                            NutrientStatusBadge(
                                label: "N",
                                status: SoilTestRanges.nitrogenStatus(n)
                            )
                            NutrientStatusBadge(
                                label: "P",
                                status: SoilTestRanges.phosphorusStatus(p)
                            )
                            NutrientStatusBadge(
                                label: "K",
                                status: SoilTestRanges.potassiumStatus(k)
                            )
                        }
                    }
                }
                
                Section("Organic Matter") {
                    HStack {
                        TextField("Percentage", text: $organicMatter)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Toggle("Add Fertilizer", isOn: $showFertilizerSection)
                }
                
                if showFertilizerSection {
                    Section("Fertilizer Application") {
                        TextField("Fertilizer Name", text: $fertilizerApplied)
                        
                        TextField("Amount Applied", text: $fertilizerAmount)
                        
                        Picker("Type", selection: $selectedFertilizerType) {
                            Text("Select Type").tag(nil as FertilizerType?)
                            ForEach(FertilizerType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.iconName)
                                    .tag(type as FertilizerType?)
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Soil Test")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLog() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        phLevel.isEmpty == false || nitrogenLevel.isEmpty == false
    }
    
    private func saveLog() {
        let log = SoilLog(logDate: logDate)
        
        log.phLevel = Double(phLevel)
        log.nitrogenLevel = Double(nitrogenLevel)
        log.phosphorusLevel = Double(phosphorusLevel)
        log.potassiumLevel = Double(potassiumLevel)
        log.organicMatter = Double(organicMatter)
        
        if showFertilizerSection {
            log.fertilizerApplied = fertilizerApplied.isEmpty ? nil : fertilizerApplied
            log.fertilizerAmount = fertilizerAmount.isEmpty ? nil : fertilizerAmount
            log.fertilizerType = selectedFertilizerType
        }
        
        log.notes = notes.isEmpty ? nil : notes
        log.garden = garden
        log.plant = plant
        
        modelContext.insert(log)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save soil log: \(error)")
        }
    }
    
    private func phStatus(_ ph: Double) -> String {
        if ph < 5.5 { return "Very Acidic" }
        if ph < 6.0 { return "Acidic" }
        if ph <= 7.0 { return "Optimal" }
        if ph <= 7.5 { return "Slightly Alkaline" }
        return "Alkaline"
    }
    
    private func phColor(_ ph: Double) -> Color {
        if ph < 5.5 { return .red }
        if ph < 6.0 { return .orange }
        if ph <= 7.0 { return .green }
        if ph <= 7.5 { return .yellow }
        return .blue
    }
}

// MARK: - Nutrient Status Badge

struct NutrientStatusBadge: View {
    let label: String
    let status: SoilNutrientStatus
    
    var body: some View {
        Text("\(label): \(status.displayName)")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .low: return Color.orange.opacity(0.2)
        case .optimal: return Color.green.opacity(0.2)
        case .high: return Color.yellow.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .low: return .orange
        case .optimal: return .green
        case .high: return .yellow
        }
    }
}

// MARK: - Soil Log Detail Sheet

struct SoilLogDetailSheet: View {
    let log: SoilLog
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Test Date") {
                    if let date = log.logDate {
                        Text(date, style: .date)
                    }
                }
                
                if let ph = log.phLevel {
                    Section("pH Level") {
                        HStack {
                            Text(String(format: "%.1f", ph))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(phColor(ph))
                            Spacer()
                            Text(phStatus(ph))
                                .font(.headline)
                                .foregroundColor(phColor(ph))
                        }
                    }
                }
                
                Section("N-P-K Levels") {
                    NutrientRow(label: "Nitrogen (N)", value: log.nitrogenLevel, optimalRange: 20...40)
                    NutrientRow(label: "Phosphorus (P)", value: log.phosphorusLevel, optimalRange: 10...25)
                    NutrientRow(label: "Potassium (K)", value: log.potassiumLevel, optimalRange: 100...200)
                }
                
                if let organic = log.organicMatter {
                    Section("Organic Matter") {
                        Text(String(format: "%.1f%%", organic))
                            .font(.headline)
                    }
                }
                
                if let fertilizer = log.fertilizerApplied {
                    Section("Fertilizer Applied") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fertilizer)
                                .font(.headline)
                            if let amount = log.fertilizerAmount {
                                Text(amount)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let type = log.fertilizerType {
                                Label(type.displayName, systemImage: type.iconName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let notes = log.notes {
                    Section("Notes") {
                        Text(notes)
                    }
                }
            }
            .navigationTitle("Soil Test Details")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func phStatus(_ ph: Double) -> String {
        if ph < 5.5 { return "Very Acidic" }
        if ph < 6.0 { return "Acidic" }
        if ph <= 7.0 { return "Optimal" }
        if ph <= 7.5 { return "Slightly Alkaline" }
        return "Alkaline"
    }
    
    private func phColor(_ ph: Double) -> Color {
        if ph < 5.5 { return .red }
        if ph < 6.0 { return .orange }
        if ph <= 7.0 { return .green }
        if ph <= 7.5 { return .yellow }
        return .blue
    }
}

// MARK: - Nutrient Row

struct NutrientRow: View {
    let label: String
    let value: Double?
    let optimalRange: ClosedRange<Double>
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if let value = value {
                Text(String(format: "%.0f ppm", value))
                    .fontWeight(.medium)
                + Text(" (")
                + Text(status(for: value))
                    .foregroundColor(statusColor(for: value))
                + Text(")")
            } else {
                Text("Not measured")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private func status(for value: Double) -> String {
        if value < optimalRange.lowerBound { return "Low" }
        if value > optimalRange.upperBound { return "High" }
        return "Optimal"
    }
    
    private func statusColor(for value: Double) -> Color {
        if value < optimalRange.lowerBound { return .orange }
        if value > optimalRange.upperBound { return .yellow }
        return .green
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SoilManagementView()
    }
}
