import GrowWiseModels
import GrowWiseServices
import SwiftUI

// MARK: - AR Garden View (iOS with ARKit)

#if canImport(ARKit) && os(iOS)
import ARKit
import AVFoundation
import RealityKit
import UIKit

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes object_literal

/// AR garden visualization using RealityKit for plant placement in real space.
/// Wraps an ARView via UIViewRepresentable and provides tap-to-place functionality.
struct ARGardenView: View {
    @Environment(DataService.self)
    private var dataService
    @Environment(\.dismiss)
    private var dismiss

    @State private var placedPlants: [ARPlacedPlant] = []
    @State private var selectedPlantForPlacement: Plant?
    @State private var showPlantPicker = false
    @State private var cameraPermissionDenied = false
    @State private var showCameraAlert = false
    @State private var arCoordinator = ARCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                // AR Camera view
                if cameraPermissionDenied {
                    cameraPermissionDeniedView
                } else {
                    ARViewContainer(
                        coordinator: arCoordinator,
                        selectedPlant: $selectedPlantForPlacement,
                        placedPlants: $placedPlants
                    )
                    .ignoresSafeArea()

                    // Overlay controls
                    ARPlantPlacementView(
                        placedPlants: $placedPlants,
                        selectedPlant: $selectedPlantForPlacement,
                        showPlantPicker: $showPlantPicker,
                        onClearAll: {
                            arCoordinator.clearAllAnchors()
                            placedPlants.removeAll()
                        },
                        onDone: { dismiss() }
                    )
                }
            }
            .navigationTitle("AR Garden")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("ar_done_button")
                }
            }
            .sheet(isPresented: $showPlantPicker) {
                ARPlantPickerSheet(
                    dataService: dataService,
                    onSelect: { plant in
                        selectedPlantForPlacement = plant
                        showPlantPicker = false
                    }
                )
            }
            .alert(
                "Camera Access Required",
                isPresented: $showCameraAlert
            ) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .accessibilityIdentifier("ar_button_settings_alert")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("ar_button_settings_cancel")
            } message: {
                Text(ARGardenView.cameraPermissionMessage)
            }
            .task {
                await checkCameraPermission()
            }
        }
        .accessibilityIdentifier("ar_garden_view")
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionDenied = !granted
            if !granted {
                showCameraAlert = true
            }

        case .denied, .restricted:
            cameraPermissionDenied = true
            showCameraAlert = true

        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            Text("Camera Access Denied")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("AR visualization requires camera access.\nPlease enable it in Settings.")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 48)
            .accessibilityIdentifier("ar_button_settings_denied")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CultivationTheme.Colors.background)
    }
}

// MARK: - AR Placed Plant Model

struct ARPlacedPlant: Identifiable {
    let id = UUID()
    let plant: Plant
    let position: SIMD3<Float>
}

// MARK: - AR Coordinator

/// Manages AR session state and anchor placement.
@Observable
@MainActor
final class ARCoordinator {
    var arView: ARView?
    private var plantAnchors: [UUID: AnchorEntity] = [:]

    func setupARView() -> ARView {
        let view = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        view.session.run(config)
        arView = view
        return view
    }

    func placePlant(_ plant: Plant, at position: SIMD3<Float>) {
        guard let arView else { return }

        let anchor = AnchorEntity(world: position)

        // Plant marker sphere — size based on spaceRequirement
        let radius = radiusForSpace(plant.spaceRequirement)
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(
            color: colorForPlantType(plant.plantType),
            isMetallic: false
        )
        let sphere = ModelEntity(mesh: mesh, materials: [material])
        sphere.position = SIMD3<Float>(0, radius, 0)
        anchor.addChild(sphere)

        // Spacing guide circle on the ground
        let spacingRadius = spacingRadiusForSpace(plant.spaceRequirement)
        let spacingMesh = MeshResource.generatePlane(
            width: spacingRadius * 2,
            depth: spacingRadius * 2,
            cornerRadius: spacingRadius
        )
        let spacingMaterial = SimpleMaterial(
            color: colorForPlantType(plant.plantType).withAlphaComponent(0.2),
            isMetallic: false
        )
        let spacingEntity = ModelEntity(mesh: spacingMesh, materials: [spacingMaterial])
        spacingEntity.position = SIMD3<Float>(0, 0.001, 0)
        anchor.addChild(spacingEntity)

        // Plant name label — positioned above the sphere
        let labelMesh = MeshResource.generateText(
            plant.name ?? "Plant",
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.04, weight: .semibold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let labelMaterial = SimpleMaterial(
            color: .white,
            isMetallic: false
        )
        let labelEntity = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
        let labelBounds = labelEntity.visualBounds(relativeTo: nil)
        let labelWidth = labelBounds.extents.x
        labelEntity.position = SIMD3<Float>(
            -labelWidth / 2,
            radius * 2 + 0.08,
            0
        )
        anchor.addChild(labelEntity)

        arView.scene.addAnchor(anchor)

        let plantId = plant.id ?? UUID()
        plantAnchors[plantId] = anchor
    }

    func clearAllAnchors() {
        for (_, anchor) in plantAnchors {
            arView?.scene.removeAnchor(anchor)
        }
        plantAnchors.removeAll()
    }

    // MARK: - Helpers

    private func radiusForSpace(_ space: SpaceRequirement?) -> Float {
        switch space {
        case .small: 0.1
        case .medium: 0.25
        case .large: 0.5
        case .extraLarge: 0.7
        case .none: 0.1
        }
    }

    private func spacingRadiusForSpace(_ space: SpaceRequirement?) -> Float {
        switch space {
        case .small: 0.15
        case .medium: 0.35
        case .large: 0.6
        case .extraLarge: 0.85
        case .none: 0.15
        }
    }

    private func colorForPlantType(_ type: PlantType?) -> UIColor {
        switch type {
        case .vegetable: UIColor(red: 0.18, green: 0.70, blue: 0.35, alpha: 1.0)
        case .herb: UIColor(red: 0.32, green: 0.72, blue: 0.53, alpha: 1.0)
        case .flower: UIColor(red: 0.68, green: 0.32, blue: 0.72, alpha: 1.0)
        case .houseplant: UIColor(red: 0.25, green: 0.65, blue: 0.55, alpha: 1.0)
        case .fruit: UIColor(red: 0.85, green: 0.35, blue: 0.25, alpha: 1.0)
        case .succulent: UIColor(red: 0.55, green: 0.78, blue: 0.45, alpha: 1.0)
        case .tree: UIColor(red: 0.40, green: 0.55, blue: 0.30, alpha: 1.0)
        case .shrub: UIColor(red: 0.35, green: 0.60, blue: 0.40, alpha: 1.0)
        case .none: UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0)
        }
    }
}

// MARK: - ARView UIViewRepresentable

struct ARViewContainer: UIViewRepresentable {
    let coordinator: ARCoordinator
    @Binding var selectedPlant: Plant?
    @Binding var placedPlants: [ARPlacedPlant]

    func makeUIView(context: Context) -> ARView {
        let arView = coordinator.setupARView()
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(ARViewTapHandler.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.selectedPlant = selectedPlant
    }

    func makeCoordinator() -> ARViewTapHandler {
        ARViewTapHandler(
            arCoordinator: coordinator,
            selectedPlant: $selectedPlant,
            placedPlants: $placedPlants
        )
    }

    final class ARViewTapHandler: NSObject {
        let arCoordinator: ARCoordinator
        var selectedPlant: Plant?
        private var selectedPlantBinding: Binding<Plant?>
        private var placedPlantsBinding: Binding<[ARPlacedPlant]>

        init(
            arCoordinator: ARCoordinator,
            selectedPlant: Binding<Plant?>,
            placedPlants: Binding<[ARPlacedPlant]>
        ) {
            self.arCoordinator = arCoordinator
            self.selectedPlant = selectedPlant.wrappedValue
            self.selectedPlantBinding = selectedPlant
            self.placedPlantsBinding = placedPlants
        }

        @MainActor
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let plant = selectedPlant,
                  let arView = arCoordinator.arView
            else { return }

            let location = sender.location(in: arView)

            if let result = arView.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .horizontal
            ).first {
                let position = result.worldTransform.columns.3
                let worldPosition = SIMD3<Float>(position.x, position.y, position.z)

                arCoordinator.placePlant(plant, at: worldPosition)
                placedPlantsBinding.wrappedValue.append(
                    ARPlacedPlant(plant: plant, position: worldPosition)
                )
            }
        }
    }
}

// MARK: - AR Plant Picker Sheet

private struct ARPlantPickerSheet: View {
    let dataService: DataService
    let onSelect: (Plant) -> Void

    @Environment(\.dismiss)
    private var dismiss

    private var plants: [Plant] {
        dataService.fetchPlants(offset: 0, limit: 100)
    }

    var body: some View {
        NavigationStack {
            List {
                if plants.isEmpty {
                    ContentUnavailableView(
                        "No Plants",
                        systemImage: "leaf",
                        description: Text("Add plants to your garden first.")
                    )
                } else {
                    ForEach(plants, id: \.id) { plant in
                        Button {
                            onSelect(plant)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: plant.plantType?.iconName ?? "leaf.fill")
                                    .font(.title3)
                                    .foregroundStyle(plant.plantType?.color ?? .green)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plant.name ?? "Unknown Plant")
                                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                                    if let space = plant.spaceRequirement {
                                        Text(space.displayName)
                                            .font(.caption)
                                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(CultivationTheme.Colors.brandLeaf)
                            }
                        }
                        .accessibilityIdentifier("ar_picker_plant_\(plant.id?.uuidString ?? "unknown")")
                    }
                }
            }
            .navigationTitle("Select Plant")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("ar_plant_picker")
    }
}

#else

// MARK: - Fallback for macOS / unsupported platforms

/// Fallback view displayed when ARKit is not available (macOS, simulators without AR).
struct ARGardenView: View {
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "arkit")
                    .font(.system(size: 64))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)

                Text("AR Not Available")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text("AR visualization requires an iPhone or iPad with ARKit support.")
                    .font(.system(.body))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CultivationTheme.Colors.background)
            .navigationTitle("AR Garden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("ar_done_button")
                }
            }
        }
        .accessibilityIdentifier("ar_garden_view")
    }
}

#endif

extension ARGardenView {
    static let cameraPermissionMessage =
        "Cultivation needs camera access for AR visualization. Please enable it in Settings."
}

// swiftlint:enable attributes object_literal
