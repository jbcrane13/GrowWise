import Foundation
import Testing

@Suite("Accessibility identifier coverage")
struct AccessibilityIdentifierCoverageTests {
    @Test("Interactive SwiftUI controls expose accessibility identifiers")
    func interactiveSwiftUIControlsExposeAccessibilityIdentifiers() throws {
        let roots = Self.sourceRoots()

        let missingIdentifiers = try roots.paths.flatMap { sourceRoot in
            try Self.swiftFiles(in: sourceRoot).flatMap { file in
                try Self.violations(in: file, relativeTo: roots.projectRoot)
            }
        }

        let message = """
        Missing accessibilityIdentifier on interactive controls:
        \(missingIdentifiers.prefix(80).joined(separator: "\n"))
        """
        #expect(missingIdentifiers.isEmpty, "\(message)")
    }

    @Test("Accessibility identifiers use snake case")
    func accessibilityIdentifiersUseSnakeCase() throws {
        let roots = Self.sourceRoots()

        let invalidIdentifiers = try roots.paths.flatMap { sourceRoot in
            try Self.swiftFiles(in: sourceRoot).flatMap { file in
                try Self.identifierConventionViolations(in: file, relativeTo: roots.projectRoot)
            }
        }

        let message = """
        accessibilityIdentifier values must use lowercase snake_case fixed text:
        \(invalidIdentifiers.prefix(80).joined(separator: "\n"))
        """
        #expect(invalidIdentifiers.isEmpty, "\(message)")
    }

    private static let interactiveConstructs = [
        "PhotosPicker",
        "ShareLink",
        "NavigationLink",
        "ColorPicker",
        "PasteButton",
        "EditButton",
        "SecureField",
        "TextEditor",
        "TextField",
        "DatePicker",
        "DisclosureGroup",
        "onTapGesture",
        "Stepper",
        "Slider",
        "Picker",
        "Toggle",
        "Button",
        "Menu",
        "Link",
    ]

    private static func sourceRoots() -> (projectRoot: URL, paths: [URL]) {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = packageRoot.deletingLastPathComponent()
        let featurePath = ["Sources", ["Grow", "Wise", "Feature"].joined()].joined(separator: "/")
        let appPath = ["Grow", "Wise"].joined()

        return (
            projectRoot,
            [
                packageRoot.appendingPathComponent(featurePath),
                projectRoot.appendingPathComponent(appPath),
            ]
        )
    }

    private static func accessibilityIdentifierLiteralRegex() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: #"\.accessibilityIdentifier\("((?:\\.|[^"\\])*)"\)"#)
    }

    private static func swiftFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else {
                return nil
            }
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
            return resourceValues.isRegularFile == true ? url : nil
        }
        .sorted { $0.path < $1.path }
    }

    private static func violations(in file: URL, relativeTo root: URL) throws -> [String] {
        let source = try String(contentsOf: file, encoding: .utf8)
        let lines = source.components(separatedBy: .newlines)
        let scanLines = try sourceForConstructScanning(source).components(separatedBy: .newlines)
        let relativePath = file.path.replacingOccurrences(of: root.path + "/", with: "")

        return lines.indices.compactMap { index in
            guard let construct = interactiveConstruct(in: scanLines[index]) else {
                return nil
            }

            let expression = expressionLines(startingAt: index, in: lines)
            guard !hasAccessibilityIdentifier(in: expression, baseIndent: indentation(of: lines[index])) else {
                return nil
            }

            return "\(relativePath):\(index + 1) \(construct)"
        }
    }

    private static func identifierConventionViolations(in file: URL, relativeTo root: URL) throws -> [String] {
        let source = try String(contentsOf: file, encoding: .utf8)
        let lines = source.components(separatedBy: .newlines)
        let relativePath = file.path.replacingOccurrences(of: root.path + "/", with: "")
        let regex = try accessibilityIdentifierLiteralRegex()

        return lines.enumerated().flatMap { lineNumber, line in
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            let matches = regex.matches(in: line, range: range)

            return matches.compactMap { match -> String? in
                guard let identifierRange = Range(match.range(at: 1), in: line) else {
                    return nil
                }

                let identifier = String(line[identifierRange])
                guard !isSnakeCaseAccessibilityIdentifier(identifier) else {
                    return nil
                }

                return "\(relativePath):\(lineNumber + 1) \(identifier)"
            }
        }
    }

    private static func interactiveConstruct(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("//") else {
            return nil
        }

        return interactiveConstructs.first { construct in
            containsStandaloneConstruct(construct, in: line)
        }
    }

    private static func containsStandaloneConstruct(_ construct: String, in line: String) -> Bool {
        ["\(construct)(", "\(construct) {"].contains { marker in
            guard let range = line.range(of: marker) else {
                return false
            }
            guard range.lowerBound > line.startIndex else {
                return true
            }

            let previous = line[line.index(before: range.lowerBound)]
            return !isIdentifierCharacter(previous)
        }
    }

    private static func expressionLines(startingAt index: Int, in lines: [String]) -> [String] {
        let baseIndent = indentation(of: lines[index])
        var expression = [lines[index]]

        for nextIndex in lines.index(after: index) ..< min(lines.count, index + 160) {
            let line = lines[nextIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineIndent = indentation(of: line)

            if !trimmed.isEmpty,
               lineIndent <= baseIndent,
               !trimmed.hasPrefix("."),
               !trimmed.hasPrefix("}"),
               !trimmed.hasPrefix(")"),
               !trimmed.hasPrefix("label:"),
               !trimmed.hasPrefix("actions:"),
               !trimmed.hasPrefix("message:")
            {
                break
            }

            expression.append(line)
        }

        return expression
    }

    private static func hasAccessibilityIdentifier(in lines: [String], baseIndent: Int) -> Bool {
        lines.contains { line in
            guard line.contains(".accessibilityIdentifier(") else {
                return false
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix(".accessibilityIdentifier") && indentation(of: line) <= baseIndent + 8
        }
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func sourceForConstructScanning(_ source: String) throws -> String {
        let patterns = [
            #"(?s)""".*?"""#,
            #""(?:\\.|[^"\\])*""#,
            #"(?s)/\*.*?\*/"#,
            #"//.*"#,
        ]

        return try patterns.reduce(source) { partialResult, pattern in
            try maskingMatches(in: partialResult, pattern: pattern)
        }
    }

    private static func maskingMatches(in source: String, pattern: String) throws -> String {
        let regex = try NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(location: 0, length: (source as NSString).length)
        let matches = regex.matches(in: source, range: fullRange)
        let mutable = NSMutableString(string: source)

        for match in matches.reversed() {
            let matchedText = mutable.substring(with: match.range)
            let replacement = matchedText.map { character in
                character.isNewline ? character : " "
            }
            mutable.replaceCharacters(in: match.range, with: String(replacement))
        }

        return mutable as String
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }

    private static func isSnakeCaseAccessibilityIdentifier(_ identifier: String) -> Bool {
        let fixedText = identifierRemovingInterpolations(identifier)
        guard !fixedText.isEmpty else {
            return false
        }

        return fixedText.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48 ... 57, 95, 97 ... 122:
                true

            default:
                false
            }
        }
    }

    private static func identifierRemovingInterpolations(_ identifier: String) -> String {
        var result = ""
        var index = identifier.startIndex

        while index < identifier.endIndex {
            let nextIndex = identifier.index(after: index)
            if identifier[index] == "\\",
               nextIndex < identifier.endIndex,
               identifier[nextIndex] == "("
            {
                index = identifier.index(nextIndex, offsetBy: 1)
                var depth = 1

                while index < identifier.endIndex, depth > 0 {
                    if identifier[index] == "(" {
                        depth += 1
                    } else if identifier[index] == ")" {
                        depth -= 1
                    }
                    index = identifier.index(after: index)
                }
            } else {
                result.append(identifier[index])
                index = nextIndex
            }
        }

        return result
    }
}
