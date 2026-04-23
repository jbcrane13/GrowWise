import Foundation

// MARK: - Plant Condition Model

/// A single plant disease, pest, or deficiency entry in the knowledge base.
public struct PlantCondition: Sendable, Equatable {
    /// Label matching the ML model output (e.g. "powdery_mildew").
    public let label: String
    /// Human-readable name shown in the UI.
    public let commonName: String
    /// Brief description of the condition.
    public let description: String
    /// Observable visual symptoms.
    public let symptoms: [String]
    /// Recommended treatment steps.
    public let treatments: [String]
    /// Prevention tips for future occurrences.
    public let prevention: [String]
    /// Typical severity when this condition is confirmed.
    public let severity: PlantDiagnosis.Severity

    public init(
        label: String,
        commonName: String,
        description: String,
        symptoms: [String],
        treatments: [String],
        prevention: [String],
        severity: PlantDiagnosis.Severity
    ) {
        self.label = label
        self.commonName = commonName
        self.description = description
        self.symptoms = symptoms
        self.treatments = treatments
        self.prevention = prevention
        self.severity = severity
    }
}

// MARK: - Knowledge Base

/// Static knowledge base mapping ML model output labels to detailed condition information.
public enum PlantDiseaseKnowledge {
    /// All known conditions indexed by their ML label.
    public static let conditions: [String: PlantCondition] = {
        var map: [String: PlantCondition] = [:]
        for condition in allConditions {
            map[condition.label] = condition
        }
        return map
    }()

    /// Look up a condition by its ML label. Returns nil for unknown labels.
    public static func condition(for label: String) -> PlantCondition? {
        conditions[label.lowercased()]
    }

    /// All conditions in the knowledge base.
    public static let allConditions: [PlantCondition] = diseases + pests + deficiencies

    // MARK: - Diseases

    public static let diseases: [PlantCondition] = [
        PlantCondition(
            label: "powdery_mildew",
            commonName: "Powdery Mildew",
            description: "A fungal disease that forms a white, powdery coating on leaf surfaces. Thrives in warm, dry climates with cool nights and high humidity.",
            symptoms: [
                "White or gray powdery spots on leaves and stems",
                "Yellowing and curling of affected leaves",
                "Stunted new growth",
                "Premature leaf drop",
            ],
            treatments: [
                "Remove and destroy heavily infected leaves",
                "Apply neem oil spray (1 tbsp per quart of water) every 7-14 days",
                "Use potassium bicarbonate solution as a fungicide alternative",
                "Improve air circulation around the plant",
            ],
            prevention: [
                "Space plants to allow adequate airflow",
                "Water at the base rather than overhead",
                "Choose mildew-resistant cultivars",
                "Avoid excessive nitrogen fertilization",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "leaf_spot",
            commonName: "Leaf Spot",
            description: "A group of fungal or bacterial diseases causing distinct spots on foliage. Common in warm, humid conditions.",
            symptoms: [
                "Brown or black circular spots on leaves",
                "Yellow halos around spots",
                "Spots may merge into larger blighted areas",
                "Premature defoliation in severe cases",
            ],
            treatments: [
                "Remove and discard infected leaves immediately",
                "Apply copper-based fungicide every 7-10 days",
                "Avoid wetting foliage when watering",
                "Thin dense growth to improve air circulation",
            ],
            prevention: [
                "Water plants at soil level early in the day",
                "Mulch around plants to prevent soil splash",
                "Rotate crops annually",
                "Sanitize pruning tools between plants",
            ],
            severity: .mild
        ),
        PlantCondition(
            label: "early_blight",
            commonName: "Early Blight",
            description: "A fungal disease caused by Alternaria solani, primarily affecting tomatoes and potatoes. Produces characteristic concentric ring patterns.",
            symptoms: [
                "Dark brown spots with concentric rings (target pattern)",
                "Lower leaves affected first, progressing upward",
                "Yellowing tissue around lesions",
                "Stem lesions near soil line",
            ],
            treatments: [
                "Remove infected lower leaves immediately",
                "Apply chlorothalonil or copper fungicide on a 7-day schedule",
                "Stake plants to keep foliage off the ground",
                "Ensure adequate potassium in soil to strengthen plant defenses",
            ],
            prevention: [
                "Use certified disease-free seed or transplants",
                "Practice 3-year crop rotation away from solanaceous crops",
                "Mulch heavily to prevent soil splash onto leaves",
                "Water with drip irrigation to keep foliage dry",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "late_blight",
            commonName: "Late Blight",
            description: "A devastating oomycete disease caused by Phytophthora infestans. Spreads rapidly in cool, wet conditions and can destroy entire crops within days.",
            symptoms: [
                "Water-soaked, dark green to brown lesions on leaves",
                "White fuzzy mold on leaf undersides in humid conditions",
                "Rapid browning and collapse of stems",
                "Brown, firm rot on fruit or tubers",
            ],
            treatments: [
                "Remove and destroy all infected plants immediately — do not compost",
                "Apply mancozeb or chlorothalonil fungicide preventively",
                "Harvest any remaining unaffected fruit promptly",
                "Monitor neighboring plants daily for 2 weeks",
            ],
            prevention: [
                "Plant resistant varieties when available",
                "Avoid overhead irrigation entirely",
                "Ensure excellent air circulation with wide spacing",
                "Destroy volunteer potatoes and tomatoes each spring",
            ],
            severity: .severe
        ),
        PlantCondition(
            label: "root_rot",
            commonName: "Root Rot",
            description: "A soil-borne fungal disease caused by Pythium, Phytophthora, or Fusarium species. Attacks roots in waterlogged or poorly drained soils.",
            symptoms: [
                "Wilting despite adequate soil moisture",
                "Yellowing and dropping of lower leaves",
                "Soft, brown, mushy roots instead of firm white ones",
                "Stunted growth and general decline",
            ],
            treatments: [
                "Unpot the plant and trim all brown, mushy roots with sterile scissors",
                "Repot in fresh, well-draining soil mix",
                "Apply a systemic fungicide drench (e.g., mefenoxam)",
                "Reduce watering frequency and ensure pot has drainage holes",
            ],
            prevention: [
                "Use well-draining potting mix with perlite or pumice",
                "Never let pots sit in standing water",
                "Allow soil to dry slightly between waterings",
                "Sterilize pots and tools before reuse",
            ],
            severity: .severe
        ),
        PlantCondition(
            label: "rust",
            commonName: "Rust",
            description: "A fungal disease producing rust-colored pustules on leaves. Spread by wind and thrives in humid conditions with moderate temperatures.",
            symptoms: [
                "Orange, yellow, or reddish-brown pustules on leaf undersides",
                "Corresponding yellow spots on upper leaf surfaces",
                "Distorted or curled leaves",
                "Premature leaf drop and weakened plants",
            ],
            treatments: [
                "Remove and destroy infected leaves promptly",
                "Apply sulfur-based fungicide or neem oil every 7-10 days",
                "Avoid overhead watering to reduce humidity on foliage",
                "Improve air circulation by pruning dense growth",
            ],
            prevention: [
                "Select rust-resistant varieties",
                "Space plants generously for airflow",
                "Water early in the day at soil level",
                "Clean up fallen leaves and debris each season",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "downy_mildew",
            commonName: "Downy Mildew",
            description: "An oomycete disease that thrives in cool, moist conditions. Produces grayish-purple fuzzy growth on leaf undersides.",
            symptoms: [
                "Angular yellow or pale green patches on upper leaf surfaces",
                "Gray-purple fuzzy growth on corresponding lower surfaces",
                "Leaves turn brown and crispy as lesions expand",
                "Plant stunting and reduced yield",
            ],
            treatments: [
                "Remove infected leaves and improve ventilation immediately",
                "Apply phosphorous acid or copper-based fungicide",
                "Reduce humidity around plants with wider spacing",
                "Avoid working with plants when foliage is wet",
            ],
            prevention: [
                "Choose resistant cultivars whenever possible",
                "Provide morning sun exposure to dry dew quickly",
                "Use drip irrigation instead of overhead sprinklers",
                "Rotate crops on a 2-3 year cycle",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "black_spot",
            commonName: "Black Spot",
            description: "A fungal disease caused by Diplocarpon rosae, primarily affecting roses. Spreads through water splash and persists on fallen leaves.",
            symptoms: [
                "Round black spots with fringed margins on upper leaf surfaces",
                "Yellowing tissue surrounding the spots",
                "Progressive defoliation from the bottom up",
                "Weakened plant with reduced flowering",
            ],
            treatments: [
                "Prune and destroy all infected leaves and canes",
                "Apply fungicide (myclobutanil or chlorothalonil) every 7-14 days",
                "Clean up all fallen leaves around the base",
                "Water at the root zone only",
            ],
            prevention: [
                "Plant black-spot-resistant rose varieties",
                "Ensure 3-4 feet spacing between rose bushes",
                "Apply preventive fungicide in early spring",
                "Mulch to prevent spore splash from soil",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "anthracnose",
            commonName: "Anthracnose",
            description: "A group of fungal diseases causing dark, sunken lesions on leaves, stems, and fruit. Favored by warm, wet weather.",
            symptoms: [
                "Dark, sunken, water-soaked lesions on leaves and stems",
                "Tan to brown irregular dead areas along leaf veins",
                "Curling and distortion of young leaves",
                "Fruit with sunken spots and pink-orange spore masses",
            ],
            treatments: [
                "Remove and destroy all affected plant parts",
                "Apply copper fungicide or chlorothalonil at first sign",
                "Avoid overhead irrigation during active infection",
                "Prune to improve canopy airflow",
            ],
            prevention: [
                "Use disease-free seed and resistant varieties",
                "Practice crop rotation with non-susceptible plants",
                "Remove plant debris at end of season",
                "Avoid working with plants in wet conditions",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "fusarium_wilt",
            commonName: "Fusarium Wilt",
            description: "A soil-borne fungal disease caused by Fusarium oxysporum that blocks the plant's vascular system. Persists in soil for years.",
            symptoms: [
                "Wilting of one side of the plant or individual branches",
                "Yellowing of lower leaves progressing upward",
                "Brown discoloration inside stems when cut",
                "Stunted growth and eventual plant death",
            ],
            treatments: [
                "Remove and destroy infected plants — do not compost",
                "Solarize soil with clear plastic for 4-6 weeks in summer",
                "Apply beneficial Trichoderma fungi to soil as biocontrol",
                "There is no chemical cure once a plant is infected",
            ],
            prevention: [
                "Plant Fusarium-resistant varieties (look for 'F' on labels)",
                "Maintain soil pH between 6.5-7.0",
                "Practice long crop rotation (5+ years for susceptible crops)",
                "Use raised beds with fresh soil if area is contaminated",
            ],
            severity: .severe
        ),
    ]

    // MARK: - Pests

    public static let pests: [PlantCondition] = [
        PlantCondition(
            label: "aphids",
            commonName: "Aphids",
            description: "Small, soft-bodied sap-sucking insects that cluster on new growth and leaf undersides. Reproduce rapidly and excrete sticky honeydew.",
            symptoms: [
                "Clusters of small green, black, or white insects on stems and leaf undersides",
                "Curled, yellowed, or distorted new growth",
                "Sticky honeydew residue on leaves and nearby surfaces",
                "Black sooty mold growing on honeydew deposits",
            ],
            treatments: [
                "Blast with a strong jet of water to dislodge aphids",
                "Apply insecticidal soap or neem oil spray every 3-5 days",
                "Release ladybugs or lacewings as biological control",
                "For severe infestations, use pyrethrin-based insecticide",
            ],
            prevention: [
                "Inspect new plants before introducing them to the garden",
                "Encourage beneficial insects with companion planting",
                "Avoid over-fertilizing with nitrogen (promotes tender growth)",
                "Use reflective mulch to disorient flying aphids",
            ],
            severity: .mild
        ),
        PlantCondition(
            label: "spider_mites",
            commonName: "Spider Mites",
            description: "Tiny arachnids (not insects) that pierce plant cells and suck out contents. Thrive in hot, dry conditions and are often found on leaf undersides.",
            symptoms: [
                "Fine stippling or speckling on upper leaf surfaces",
                "Tiny white or yellow dots visible with magnification",
                "Fine webbing between leaves and stems in heavy infestations",
                "Leaves turning bronze, brown, and dropping prematurely",
            ],
            treatments: [
                "Spray plants thoroughly with water, focusing on leaf undersides",
                "Apply miticide or horticultural oil every 5-7 days for 3 cycles",
                "Introduce predatory mites (Phytoseiulus persimilis) for biocontrol",
                "Increase humidity around affected plants",
            ],
            prevention: [
                "Mist plants regularly in hot, dry weather",
                "Keep plants well-watered — drought-stressed plants are more vulnerable",
                "Inspect leaf undersides weekly with a hand lens",
                "Quarantine new plants for 2 weeks before placement",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "whiteflies",
            commonName: "Whiteflies",
            description: "Small, white-winged insects that feed on plant sap from leaf undersides. Fly up in a cloud when the plant is disturbed.",
            symptoms: [
                "Tiny white moths flying up when plant is touched",
                "Yellowing and wilting of leaves",
                "Sticky honeydew and sooty mold on leaf surfaces",
                "Reduced plant vigor and stunted growth",
            ],
            treatments: [
                "Use yellow sticky traps to capture adult whiteflies",
                "Apply insecticidal soap or neem oil to leaf undersides",
                "Introduce Encarsia formosa parasitic wasps for biocontrol",
                "Vacuum adults off plants in early morning when sluggish",
            ],
            prevention: [
                "Inspect transplants carefully before purchase",
                "Remove weeds that can harbor whitefly populations",
                "Use reflective aluminum mulch to repel adults",
                "Avoid broad-spectrum insecticides that kill beneficial predators",
            ],
            severity: .mild
        ),
        PlantCondition(
            label: "mealybugs",
            commonName: "Mealybugs",
            description: "Soft-bodied, waxy-coated insects that form cottony masses on stems and leaf axils. Suck plant sap and excrete honeydew.",
            symptoms: [
                "White, cottony masses in leaf axils, stem joints, and under leaves",
                "Sticky honeydew and black sooty mold",
                "Yellowing, wilting, and leaf drop",
                "Stunted or distorted new growth",
            ],
            treatments: [
                "Dab individual mealybugs with a cotton swab soaked in rubbing alcohol",
                "Spray with insecticidal soap or neem oil, covering all crevices",
                "Release Cryptolaemus (mealybug destroyer) beetles for biocontrol",
                "For severe cases, apply systemic insecticide as a soil drench",
            ],
            prevention: [
                "Quarantine new plants for at least 2 weeks",
                "Inspect plants regularly, especially hidden crevices",
                "Avoid overwatering and overfertilizing",
                "Wipe leaves with a damp cloth monthly to detect early infestations",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "scale_insects",
            commonName: "Scale Insects",
            description: "Immobile, shell-covered insects that attach to stems and leaves to feed on sap. Hard to detect due to their camouflaged appearance.",
            symptoms: [
                "Small, brown or tan bumps on stems and leaf veins",
                "Sticky honeydew on leaves and surfaces below the plant",
                "Yellowing leaves and branch dieback",
                "Slow decline in overall plant health",
            ],
            treatments: [
                "Scrape off visible scale with a soft brush or fingernail",
                "Apply horticultural oil spray to suffocate crawlers and adults",
                "Use systemic imidacloprid as a soil drench for heavy infestations",
                "Prune and discard heavily infested branches",
            ],
            prevention: [
                "Inspect plants thoroughly before purchase",
                "Encourage natural predators like parasitic wasps and ladybugs",
                "Avoid over-fertilizing which promotes succulent growth",
                "Monitor plants monthly, especially woody stems and leaf undersides",
            ],
            severity: .moderate
        ),
    ]

    // MARK: - Nutrient Deficiencies

    public static let deficiencies: [PlantCondition] = [
        PlantCondition(
            label: "nitrogen_deficiency",
            commonName: "Nitrogen Deficiency",
            description: "A macronutrient deficiency that impairs chlorophyll production and protein synthesis. Most common nutrient deficiency in plants.",
            symptoms: [
                "Uniform yellowing (chlorosis) of older, lower leaves first",
                "Stunted, spindly growth with thin stems",
                "Reduced leaf size and pale green color overall",
                "Premature leaf drop starting from the bottom",
            ],
            treatments: [
                "Apply balanced liquid fertilizer (e.g., 10-10-10) at half strength",
                "Side-dress with composted manure or blood meal",
                "Foliar spray with dilute fish emulsion for quick uptake",
                "Add organic compost to improve long-term soil nitrogen",
            ],
            prevention: [
                "Test soil annually and amend before planting",
                "Incorporate nitrogen-fixing cover crops (clover, legumes)",
                "Mulch with compost to slowly release nutrients",
                "Avoid leaching by watering deeply but less frequently",
            ],
            severity: .moderate
        ),
        PlantCondition(
            label: "iron_chlorosis",
            commonName: "Iron Chlorosis",
            description: "An iron deficiency causing interveinal chlorosis, most common in alkaline soils where iron becomes unavailable despite being present.",
            symptoms: [
                "Yellow leaves with distinctly green veins (interveinal chlorosis)",
                "New growth affected first, unlike nitrogen deficiency",
                "Leaf edges may turn brown and crispy in severe cases",
                "Stunted growth and reduced flowering or fruiting",
            ],
            treatments: [
                "Apply chelated iron (Fe-EDDHA) as a soil drench",
                "Foliar spray with ferrous sulfate solution for quick relief",
                "Lower soil pH with sulfur or acidifying fertilizer",
                "Add iron sulfate granules around the root zone",
            ],
            prevention: [
                "Test soil pH and maintain between 5.5-6.5 for susceptible plants",
                "Use acidifying mulches like pine needles or oak leaves",
                "Choose iron-efficient plant varieties for alkaline soils",
                "Avoid overwatering which can reduce iron availability",
            ],
            severity: .mild
        ),
        PlantCondition(
            label: "potassium_deficiency",
            commonName: "Potassium Deficiency",
            description: "A macronutrient deficiency affecting water regulation, disease resistance, and fruit quality. Common in sandy or heavily cropped soils.",
            symptoms: [
                "Brown scorching and curling of leaf edges (marginal necrosis)",
                "Older leaves affected first, progressing inward",
                "Weak stems prone to lodging",
                "Poor fruit development and reduced disease resistance",
            ],
            treatments: [
                "Apply potassium sulfate (sulfate of potash) as a side dress",
                "Use wood ash sparingly as an organic potassium source",
                "Apply liquid seaweed extract as a foliar feed",
                "Incorporate greensand into the soil for slow release",
            ],
            prevention: [
                "Maintain adequate potassium with annual soil testing",
                "Add compost regularly to improve nutrient retention",
                "Avoid excessive calcium or magnesium which compete with potassium",
                "Mulch to reduce nutrient leaching in sandy soils",
            ],
            severity: .moderate
        ),
    ]
}
