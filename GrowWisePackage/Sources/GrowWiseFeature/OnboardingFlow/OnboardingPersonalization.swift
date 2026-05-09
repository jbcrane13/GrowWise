import GrowWiseModels

enum OnboardingPersonalization {
    static func modelGoals(from goals: Set<GardeningGoal>) -> [GrowWiseModels.GardeningGoal] {
        goals
            .map(\.modelGoal)
            .sorted { $0.rawValue < $1.rawValue }
    }

    static func preferredPlantTypes(
        goals: Set<GardeningGoal>,
        interests: Set<PlantType>
    ) -> [PlantType] {
        let goalTypes = goals.flatMap(\.preferredPlantTypes)
        return Array(Set(goalTypes).union(interests))
            .sorted { $0.rawValue < $1.rawValue }
    }
}

extension GardeningGoal {
    var modelGoal: GrowWiseModels.GardeningGoal {
        switch self {
        case .growFood: .growFood
        case .beautifySpace: .beautifySpace
        case .learnSkills: .learnSkills
        case .relaxation: .relaxation
        case .sustainability: .sustainability
        case .healingGarden: .medicinalHerbs
        }
    }

    var preferredPlantTypes: [PlantType] {
        switch self {
        case .growFood: [.vegetable, .herb, .fruit]
        case .beautifySpace: [.flower, .shrub, .tree]
        case .learnSkills: [.vegetable, .herb, .flower, .houseplant]
        case .relaxation: [.houseplant, .flower, .herb]
        case .sustainability: [.vegetable, .herb, .fruit, .tree]
        case .healingGarden: [.herb, .flower]
        }
    }
}
