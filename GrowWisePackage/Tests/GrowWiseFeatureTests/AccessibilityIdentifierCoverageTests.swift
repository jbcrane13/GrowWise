import Foundation
import Testing

struct AccessibilityIdentifierCoverageTests {
    @Test("Interactive SwiftUI controls declare accessibility identifiers")
    func interactiveSwiftUIControlsDeclareAccessibilityIdentifiers() throws {
        let sourceRoot = try Self.featureSourceRoot()
        let swiftFiles = try Self.swiftFiles(in: sourceRoot)
        var missingIdentifiers: [String] = []

        for fileURL in swiftFiles {
            let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = fileContents.components(separatedBy: .newlines)

            for lineIndex in lines.indices {
                let line = lines[lineIndex]
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { continue }

                for occurrence in Self.interactiveOccurrences(in: line) {
                    let segment = Self.sourceSegment(
                        lines: lines,
                        startLine: lineIndex,
                        startColumn: occurrence.column,
                        kind: occurrence.kind
                    )

                    if !segment.contains(".accessibilityIdentifier(") {
                        let relativePath = fileURL.path.replacingOccurrences(of: sourceRoot.path + "/", with: "")
                        missingIdentifiers.append("\(relativePath):\(lineIndex + 1) \(occurrence.kind)")
                    }
                }
            }
        }

        #expect(
            missingIdentifiers.isEmpty,
            "Missing accessibility identifiers:\n\(missingIdentifiers.prefix(60).joined(separator: "\n"))"
        )
    }

    private static func featureSourceRoot() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot.appendingPathComponent("Sources/GrowWiseFeature", isDirectory: true)
    }

    private static func swiftFiles(in root: URL) throws -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        return enumerator.compactMap { entry in
            guard let url = entry as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
        .sorted { $0.path < $1.path }
    }

    private static func interactiveOccurrences(in line: String) -> [(column: Int, kind: String)] {
        let controlNames = [
            "Button",
            "NavigationLink",
            "Toggle",
            "Picker",
            "TextField",
            "SecureField",
            "TextEditor",
            "Slider",
            "Stepper",
            "Menu",
            "Link",
            "DatePicker",
            "ColorPicker",
            "PhotosPicker",
            "ShareLink",
            "DisclosureGroup",
            "PasteButton",
        ]
        let controlsPattern = #"(?<![A-Za-z0-9_])(\#(controlNames.joined(separator: "|")))\s*(?:\(|\{)"#
        let modifierPattern = #"\.(searchable|onTapGesture)\s*(?:\(|\{)"#

        return regexMatches(pattern: controlsPattern, in: line)
            + regexMatches(pattern: modifierPattern, in: line)
    }

    private static func regexMatches(pattern: String, in line: String) -> [(column: Int, kind: String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(line.startIndex ..< line.endIndex, in: line)

        return regex.matches(in: line, range: nsRange).compactMap { match in
            guard
                let range = Range(match.range(at: 1), in: line),
                let fullRange = Range(match.range(at: 0), in: line)
            else {
                return nil
            }

            let column = line.distance(from: line.startIndex, to: fullRange.lowerBound)
            let matchedKind = String(line[range])
            let kind = matchedKind == "searchable" || matchedKind == "onTapGesture"
                ? ".\(matchedKind)"
                : matchedKind
            return (column, kind)
        }
    }

    private static func sourceSegment(
        lines: [String],
        startLine: Int,
        startColumn: Int,
        kind: String
    ) -> String {
        if kind == ".onTapGesture" || kind == ".searchable" {
            let endLine = min(lines.count, startLine + 50)
            return lines[startLine ..< endLine].joined(separator: "\n")
        }

        var segment: [String] = []
        var balance = 0
        var lineIndex = startLine
        let maxInitialLine = min(lines.count, startLine + 220)

        while lineIndex < maxInitialLine {
            let line = lines[lineIndex]
            segment.append(line)

            let scannedText = lineIndex == startLine
                ? String(line.dropFirst(startColumn))
                : line
            balance += delimiterDelta(in: scannedText)
            lineIndex += 1

            if balance <= 0 {
                break
            }
        }

        var chainedModifierBalance = 0
        while lineIndex < lines.count, segment.count < 280 {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if chainedModifierBalance == 0 {
                let isChainLine = trimmed.isEmpty
                    || trimmed.hasPrefix("//")
                    || trimmed.hasPrefix("#")
                    || trimmed.hasPrefix(".")
                guard isChainLine else { break }
            }

            segment.append(line)
            chainedModifierBalance += delimiterDelta(in: line)
            lineIndex += 1
        }

        return segment.joined(separator: "\n")
    }

    private static func delimiterDelta(in text: String) -> Int {
        var delta = 0
        var isInString = false
        var isEscaped = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if isInString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInString = false
                }
                index += 1
                continue
            }

            if character == "\"" {
                isInString = true
            } else if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                break
            } else if character == "(" || character == "[" || character == "{" {
                delta += 1
            } else if character == ")" || character == "]" || character == "}" {
                delta -= 1
            }

            index += 1
        }

        return delta
    }
}
