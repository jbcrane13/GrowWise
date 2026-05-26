import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct AssignGardenSheet: View {
    let plant: Plant
    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService
    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Garden") {
                    Picker("Garden", selection: $selectedGarden) {
                        Text("None").tag(nil as Garden?)
                        ForEach(gardens, id: \.id) { garden in
                            Text(garden.name ?? "Unnamed").tag(garden as Garden?)
                        }
                    }
                    .accessibilityIdentifier("assigngarden_picker_garden")
                }
            }
            .navigationTitle("Assign Garden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("assigngarden_button_cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveTask = Task { await save() } }
                        .disabled(isSaving)
                        .accessibilityIdentifier("assigngarden_button_save")
                }
            }
            .task { load() }
            .onDisappear { saveTask?.cancel() }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {}
                    .accessibilityIdentifier("assigngarden_button_alert_ok")
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func load() {
        do {
            gardens = try dataService.gardens.fetchAll()
        } catch {
            alertTitle = "Error"
            alertMessage = "Could not load gardens: \(error.localizedDescription)"
            showAlert = true
            gardens = []
        }
        selectedGarden = plant.garden
    }

    @MainActor
    private func save() async {
        isSaving = true
        plant.garden = selectedGarden
        do {
            try dataService.updatePlant(plant)
            dismiss()
        } catch {
            alertTitle = "Action Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
        isSaving = false
    }
}
