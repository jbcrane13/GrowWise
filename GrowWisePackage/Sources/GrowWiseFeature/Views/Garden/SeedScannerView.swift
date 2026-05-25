#if canImport(UIKit)
import GrowWiseServices
import os
import SwiftUI
import UIKit

// MARK: - SeedScannerView

/// Sheet view for capturing a seed packet photo and running OCR to extract planting data.
struct SeedScannerView: View {
    @Environment(\.dismiss)
    private var dismiss

    let onResult: (SeedScanResult) -> Void

    private let logger = Logger(subsystem: "com.growwise.gardening", category: "SeedScannerView")

    @State private var scannerService = SeedScannerService()
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                Spacer()

                // Icon and description
                VStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                        .accessibilityIdentifier("seed_scanner_icon")

                    Text("Scan Seed Packet")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text("Take a photo or choose an image of your seed packet to automatically extract planting information.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                if isProcessing {
                    processingIndicator
                } else {
                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Take Photo")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(GradientButtonStyle())
                        .accessibilityIdentifier("seed_scanner_button_capture")

                        Button {
                            showLibrary = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Choose from Library")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background {
                                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                                    .fill(CultivationTheme.Colors.cardSurface)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("seed_scanner_button_library")
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                }

                Spacer()
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Scan Packet")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .accessibilityIdentifier("seed_scanner_button_cancel")
                }
            }
            .alert("Scan Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("seed_scanner_button_error_dismiss")
            } message: {
                Text(errorMessage ?? "Could not read the seed packet. Please try again with a clearer image.")
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    processImage(image)
                }
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    processImage(image)
                }
            }
        }
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(CultivationTheme.Colors.accentCoral)

            Text("Reading seed packet...")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .accessibilityIdentifier("seed_scanner_processing")
    }

    // MARK: - Process Image

    private func processImage(_ image: UIImage) {
        isProcessing = true
        Task<Void, Never> {
            do {
                let result = try await scannerService.recognizeText(from: image)
                onResult(result)
                dismiss()
            } catch {
                logger.error("OCR failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - ImagePicker

/// UIImagePickerController wrapper for camera and photo library access.
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#endif
