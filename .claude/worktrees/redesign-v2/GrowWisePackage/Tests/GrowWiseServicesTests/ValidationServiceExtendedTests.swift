import Testing
import Foundation
@testable import GrowWiseServices

// The existing ValidationServiceTests.swift (excluded from compilation) already covers:
//   validateEmail, validateText (basic length), validateText (SQL injection),
//   validateName, validateNumber, validatePlantName, validateTag,
//   validateHeight, validateTemperature, validateHumidity,
//   validateSearchQuery, sanitizeInput, validateFields (batch).
//
// This file adds NEW coverage for:
//   - validateText: maxLength exact boundary, minLength=0 edge cases,
//     additional SQL injection keywords, XSS-like patterns via validateSearchQuery
//   - validateSearchQuery: SCRIPT/<script>/</script> patterns, XSS tag detection
//   - sanitizeInput: individual character escaping, HTML tag stripping
//   - validateWidth / validateWaterAmount (untested measurement helpers)
//   - validateTag: boundary at exactly 30 chars
//   - validateName: exact 50-char boundary, custom fieldName in error messages
//   - validatePlantName: 100-char boundary, cultivar names with parentheses
//   - validateFields: mixed valid/invalid results
//   - ValidationResult static members

@Suite("ValidationService Extended Tests")
struct ValidationServiceExtendedTests {

    let sut = ValidationService.shared

    // MARK: - ValidationResult

    @Test("ValidationResult.valid has isValid true and nil errorMessage")
    func testValidationResultValid() {
        let result = ValidationService.ValidationResult.valid
        #expect(result.isValid == true)
        #expect(result.errorMessage == nil)
    }

    @Test("ValidationResult.invalid stores the error message")
    func testValidationResultInvalid() {
        let result = ValidationService.ValidationResult.invalid("Something went wrong")
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Something went wrong")
    }

    // MARK: - validateText: maxLength boundaries

    @Test("validateText passes when text length equals maxLength")
    func testTextAtExactMaxLength() {
        let text = String(repeating: "a", count: 100)
        let result = sut.validateText(text, fieldName: "Notes", maxLength: 100)
        #expect(result.isValid == true)
    }

    @Test("validateText fails when text is one char over maxLength")
    func testTextOneOverMaxLength() {
        let text = String(repeating: "a", count: 101)
        let result = sut.validateText(text, fieldName: "Notes", maxLength: 100)
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Notes must be less than 100 characters")
    }

    @Test("validateText passes empty text when minLength is 0")
    func testTextEmptyWithZeroMinLength() {
        let result = sut.validateText("", fieldName: "Notes", minLength: 0, maxLength: 500)
        #expect(result.isValid == true)
    }

    @Test("validateText reports required error when minLength > 0 and text is empty after trim")
    func testTextRequiredWhenMinLengthPositive() {
        let result = sut.validateText("   ", fieldName: "Title", minLength: 1, maxLength: 500)
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Title is required")
    }

    @Test("validateText uses fieldName in minLength error message")
    func testTextMinLengthErrorUsesFieldName() {
        let result = sut.validateText("ab", fieldName: "Garden Name", minLength: 5, maxLength: 500)
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Garden Name must be at least 5 characters")
    }

    // MARK: - validateText: SQL injection patterns (parameterized)

    @Test("validateText rejects SQL injection patterns", arguments: [
        ("'; DROP TABLE users; --", "DROP TABLE"),
        ("DELETE FROM plants WHERE 1=1", "DELETE FROM"),
        ("INSERT INTO admin VALUES ('x')", "INSERT INTO"),
        ("UPDATE SET password='hacked'", "UPDATE SET"),
        ("admin'; --", "'; --"),
        ("1 UNION SELECT * FROM secrets", "UNION SELECT")
    ])
    func testTextSQLInjectionPatterns(input: String, pattern: String) {
        let result = sut.validateText(input, fieldName: "Test")
        #expect(result.isValid == false, "Should reject SQL pattern '\(pattern)' in: \(input)")
        #expect(result.errorMessage == "Invalid characters detected")
    }

    @Test("validateText accepts normal gardening text")
    func testTextNormalGardeningContent() {
        let inputs = [
            "Watered the tomatoes today",
            "Planted 3 rows of carrots",
            "Added compost to bed #2",
            "pH was 6.5 — looks good!",
        ]
        for input in inputs {
            let result = sut.validateText(input, fieldName: "Notes")
            #expect(result.isValid == true, "Should accept normal text: \(input)")
        }
    }

    // MARK: - validateSearchQuery: XSS and injection patterns (parameterized)

    @Test("validateSearchQuery rejects dangerous keywords", arguments: [
        "DROP plants",
        "DELETE all",
        "INSERT virus",
        "UPDATE records",
        "EXEC code",
        "run SCRIPT here",
        "<script>evil()</script>",
        "end</script>"
    ])
    func testSearchQueryDangerousKeywords(query: String) {
        let result = sut.validateSearchQuery(query)
        #expect(result.isValid == false, "Should reject query: \(query)")
    }

    @Test("validateSearchQuery accepts benign gardening searches")
    func testSearchQueryBenignInputs() {
        let queries = [
            "tomato",
            "indoor ferns",
            "low light plants",
            "zone 5 perennials",
            "how to prune roses",
            ""  // empty is valid (under max length)
        ]
        for query in queries {
            let result = sut.validateSearchQuery(query)
            #expect(result.isValid == true, "Should accept query: '\(query)'")
        }
    }

    @Test("validateSearchQuery rejects queries over 100 characters")
    func testSearchQueryTooLong() {
        let longQuery = String(repeating: "a", count: 101)
        let result = sut.validateSearchQuery(longQuery)
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Search query is too long")
    }

    @Test("validateSearchQuery accepts query of exactly 100 characters")
    func testSearchQueryAtExactMaxLength() {
        let query = String(repeating: "a", count: 100)
        let result = sut.validateSearchQuery(query)
        #expect(result.isValid == true)
    }

    // MARK: - validateName: boundaries and custom fieldName

    @Test("validateName accepts name of exactly 50 characters")
    func testNameAtExactMaxLength() {
        let name = String(repeating: "a", count: 50)
        let result = sut.validateName(name)
        #expect(result.isValid == true)
    }

    @Test("validateName rejects name of 51 characters")
    func testNameOneOverMaxLength() {
        let name = String(repeating: "a", count: 51)
        let result = sut.validateName(name)
        #expect(result.isValid == false)
    }

    @Test("validateName uses custom fieldName in error messages")
    func testNameCustomFieldName() {
        let result = sut.validateName("", fieldName: "Garden Name")
        #expect(result.isValid == false)
        #expect(result.errorMessage == "Garden Name is required")
    }

    @Test("validateName rejects single-character name")
    func testNameSingleChar() {
        let result = sut.validateName("A")
        #expect(result.isValid == false)
    }

    @Test("validateName accepts exactly 2 characters")
    func testNameExactMinLength() {
        let result = sut.validateName("Jo")
        #expect(result.isValid == true)
    }

    // MARK: - validatePlantName: boundaries and cultivar syntax

    @Test("validatePlantName accepts exactly 100 characters")
    func testPlantNameAtExactMaxLength() {
        let name = String(repeating: "a", count: 100)
        let result = sut.validatePlantName(name)
        #expect(result.isValid == true)
    }

    @Test("validatePlantName rejects 101-character name")
    func testPlantNameOverMaxLength() {
        let name = String(repeating: "a", count: 101)
        let result = sut.validatePlantName(name)
        #expect(result.isValid == false)
    }

    @Test("validatePlantName accepts cultivar names with parentheses and dots")
    func testPlantNameCultivarSyntax() {
        let cultivarNames = [
            "Rosa 'Peace'",
            "Hedera helix (English Ivy)",
            "Tomato (Solanum lycopersicum)",
            "Ficus benjamina var. 1.2",
        ]
        for name in cultivarNames {
            let result = sut.validatePlantName(name)
            #expect(result.isValid == true, "Should accept cultivar name: \(name)")
        }
    }

    @Test("validatePlantName accepts alphanumeric plant names")
    func testPlantNameAlphanumeric() {
        let result = sut.validatePlantName("Variety X2")
        #expect(result.isValid == true)
    }

    // MARK: - validateTag: boundary

    @Test("validateTag accepts tag of exactly 30 characters")
    func testTagAtExactMaxLength() {
        let tag = String(repeating: "a", count: 30)
        let result = sut.validateTag(tag)
        #expect(result.isValid == true)
    }

    @Test("validateTag rejects tag of 31 characters")
    func testTagOneOverMaxLength() {
        let tag = String(repeating: "a", count: 31)
        let result = sut.validateTag(tag)
        #expect(result.isValid == false)
    }

    // MARK: - validateWidth (untested in existing suite)

    @Test("validateWidth accepts values within range")
    func testWidthValidRange() {
        #expect(sut.validateWidth("0").isValid == true)
        #expect(sut.validateWidth("100").isValid == true)
        #expect(sut.validateWidth("9999.9").isValid == true)
        #expect(sut.validateWidth("10000").isValid == true)
    }

    @Test("validateWidth rejects negative value")
    func testWidthNegative() {
        let result = sut.validateWidth("-1")
        #expect(result.isValid == false)
    }

    @Test("validateWidth rejects value above 10000")
    func testWidthAboveMax() {
        let result = sut.validateWidth("10001")
        #expect(result.isValid == false)
    }

    @Test("validateWidth accepts empty string (optional field)")
    func testWidthEmpty() {
        #expect(sut.validateWidth("").isValid == true)
    }

    // MARK: - validateWaterAmount (untested in existing suite)

    @Test("validateWaterAmount accepts zero and positive values")
    func testWaterAmountValidRange() {
        #expect(sut.validateWaterAmount("0").isValid == true)
        #expect(sut.validateWaterAmount("500").isValid == true)
        #expect(sut.validateWaterAmount("10000").isValid == true)
    }

    @Test("validateWaterAmount rejects negative value")
    func testWaterAmountNegative() {
        #expect(sut.validateWaterAmount("-0.1").isValid == false)
    }

    @Test("validateWaterAmount rejects value above 10000")
    func testWaterAmountAboveMax() {
        #expect(sut.validateWaterAmount("10001").isValid == false)
    }

    // MARK: - sanitizeInput: character-level escaping

    @Test("sanitizeInput escapes ampersand")
    func testSanitizeAmpersand() {
        let result = sut.sanitizeInput("Tom & Jerry")
        #expect(result.contains("&amp;"))
        #expect(!result.contains(" & "))
    }

    @Test("sanitizeInput escapes double quotes")
    func testSanitizeDoubleQuotes() {
        let result = sut.sanitizeInput("Say \"hello\"")
        #expect(result.contains("&quot;"))
    }

    @Test("sanitizeInput escapes single quotes")
    func testSanitizeSingleQuotes() {
        let result = sut.sanitizeInput("O'Brien")
        #expect(result.contains("&#x27;"))
    }

    @Test("sanitizeInput escapes forward slash")
    func testSanitizeForwardSlash() {
        let result = sut.sanitizeInput("path/to/file")
        #expect(result.contains("&#x2F;"))
    }

    @Test("sanitizeInput strips HTML tags")
    func testSanitizeStripsHTMLTags() {
        let result = sut.sanitizeInput("<b>Bold</b> text")
        #expect(!result.contains("<b>"))
        #expect(!result.contains("</b>"))
    }

    @Test("sanitizeInput trims leading and trailing whitespace")
    func testSanitizeTrimsWhitespace() {
        let result = sut.sanitizeInput("   hello   ")
        #expect(!result.hasPrefix(" "))
        #expect(!result.hasSuffix(" "))
    }

    @Test("sanitizeInput returns empty string for whitespace-only input")
    func testSanitizeWhitespaceOnly() {
        let result = sut.sanitizeInput("   ")
        // After trim, empty; no HTML chars to escape. Result should be empty.
        #expect(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - validateFields batch

    @Test("validateFields returns isValid true when all fields pass")
    func testBatchAllValid() {
        let validations: [(String, ValidationService.ValidationResult)] = [
            ("name", .valid),
            ("email", .valid),
            ("notes", .valid)
        ]
        let (isValid, errors) = sut.validateFields(validations)
        #expect(isValid == true)
        #expect(errors.isEmpty)
    }

    @Test("validateFields returns isValid false when one field fails")
    func testBatchOneInvalid() {
        let validations: [(String, ValidationService.ValidationResult)] = [
            ("name", .valid),
            ("email", .invalid("Bad email"))
        ]
        let (isValid, errors) = sut.validateFields(validations)
        #expect(isValid == false)
        #expect(errors.count == 1)
        #expect(errors["email"] == "Bad email")
        #expect(errors["name"] == nil)
    }

    @Test("validateFields collects all error messages for multiple failures")
    func testBatchMultipleInvalid() {
        let validations: [(String, ValidationService.ValidationResult)] = [
            ("a", .invalid("Error A")),
            ("b", .valid),
            ("c", .invalid("Error C")),
            ("d", .invalid("Error D"))
        ]
        let (isValid, errors) = sut.validateFields(validations)
        #expect(isValid == false)
        #expect(errors.count == 3)
        #expect(errors["a"] == "Error A")
        #expect(errors["c"] == "Error C")
        #expect(errors["d"] == "Error D")
        #expect(errors["b"] == nil)
    }

    @Test("validateFields returns isValid true for empty array")
    func testBatchEmpty() {
        let validations: [(String, ValidationService.ValidationResult)] = []
        let (isValid, errors) = sut.validateFields(validations)
        #expect(isValid == true)
        #expect(errors.isEmpty)
    }

    // MARK: - Email typo detection (extended)

    @Test("validateEmail flags common domain typos", arguments: [
        "user@gmial.com",
        "user@gmai.com",
        "user@yahooo.com",
        "user@outlok.com"
    ])
    func testEmailTypoDetection(email: String) {
        let result = sut.validateEmail(email)
        #expect(result.isValid == false, "Should flag typo domain in: \(email)")
        #expect(result.errorMessage == "Please check your email domain for typos")
    }

    @Test("validateEmail accepts correctly spelled common domains")
    func testEmailCorrectDomains() {
        let emails = [
            "user@gmail.com",
            "user@yahoo.com",
            "user@outlook.com"
        ]
        for email in emails {
            let result = sut.validateEmail(email)
            #expect(result.isValid == true, "Should accept: \(email)")
        }
    }
}
