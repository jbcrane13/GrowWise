import GrowWiseServices
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct PlantScannerView: View {
    @State private var diagnosticService = PlantDiagnosticService()

    @State private var selectedPhotoItem: PhotosPickerItem?
    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Plant Health Scanner")
                        .font(.title2)
                        .fontWeight(.semibold)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose Plant Photo", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("scannerChoosePhotoButton")

                    Button("Run Sample Diagnosis") {
                        diagnosticService.setSampleDiagnosis()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("scannerRunSampleButton")

                    if diagnosticService.isAnalyzing {
                        ProgressView("Analyzing image...")
                    }

                    if let diagnosis = diagnosticService.lastDiagnosis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Primary Finding: \(diagnosis.primaryLabel)")
                                .font(.headline)
                                .accessibilityIdentifier("scannerPrimaryFinding")
                            Text("Confidence: \(Int(diagnosis.confidence * 100))%")
                            Text("Severity: \(diagnosis.severity.rawValue.capitalized)")
                            Text(diagnosis.recommendation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    if let error = diagnosticService.lastError {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Scanner")
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                #if canImport(UIKit)
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)
                {
                    await diagnosticService.diagnose(image: image)
                }
                #endif
            }
        }
    }
}

#Preview {
    PlantScannerView()
}
