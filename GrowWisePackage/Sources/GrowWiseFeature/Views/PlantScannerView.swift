import GrowWiseServices
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct PlantScannerView: View {
    @Environment(DataService.self)
    private var dataService

    @State private var diagnosticService = PlantDiagnosticService()

    @State private var selectedPhotoItem: PhotosPickerItem?
    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Plant Health Check")
                        .font(.title2)
                        .fontWeight(.semibold)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose Plant Photo", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("scannerChoosePhotoButton")

                    if diagnosticService.isAnalyzing {
                        ProgressView("Checking image...")
                    }

                    if let guidance = diagnosticService.lastDiagnosis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Primary Finding: \(guidance.primaryLabel)")
                                .font(.headline)
                                .accessibilityIdentifier("scannerPrimaryFinding")
                            Text("Severity: \(guidance.severity.rawValue.capitalized)")
                            Text(guidance.recommendation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    await diagnosticService.diagnose(image: image, currentUser: dataService.getCurrentUser())
                }
                #endif
            }
        }
    }
}

#Preview {
    PlantScannerView()
        .environment(DataService.createFallback())
}
