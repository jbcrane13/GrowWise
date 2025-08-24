import XCTest
@testable import GrowWiseServices

final class ValidationServiceTests: XCTestCase {
    
    let validationService = ValidationService.shared
    
    // MARK: - Email Validation Tests
    
    func testValidEmail() {
        let emails = [
            "user@example.com",
            "john.doe@company.co.uk",
            "test+tag@gmail.com",
            "user123@test-domain.org"
        ]
        
        for email in emails {
            let result = validationService.validateEmail(email)
            XCTAssertTrue(result.isValid, "Email '\(email)' should be valid")
        }
    }
    
    func testInvalidEmail() {
        let emails = [
            "",
            "notanemail",
            "user@",
            "@example.com",
            "user@.com",
            "user@domain",
            "user space@example.com",
            "user@gmial.com" // Common typo
        ]
        
        for email in emails {
            let result = validationService.validateEmail(email)
            XCTAssertFalse(result.isValid, "Email '\(email)' should be invalid")
            XCTAssertNotNil(result.errorMessage)
        }
    }
    
    // MARK: - Text Validation Tests
    
    func testValidText() {
        let result = validationService.validateText("Valid text", fieldName: "Test", minLength: 5, maxLength: 20)
        XCTAssertTrue(result.isValid)
    }
    
    func testTextTooShort() {
        let result = validationService.validateText("Hi", fieldName: "Test", minLength: 5, maxLength: 20)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Test must be at least 5 characters")
    }
    
    func testTextTooLong() {
        let longText = String(repeating: "a", count: 101)
        let result = validationService.validateText(longText, fieldName: "Test", minLength: 0, maxLength: 100)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Test must be less than 100 characters")
    }
    
    func testTextWithSQLInjection() {
        let dangerousTexts = [
            "'; DROP TABLE users; --",
            "1' OR '1'='1",
            "admin' UNION SELECT * FROM passwords"
        ]
        
        for text in dangerousTexts {
            let result = validationService.validateText(text, fieldName: "Test")
            XCTAssertFalse(result.isValid)
            XCTAssertEqual(result.errorMessage, "Invalid characters detected")
        }
    }
    
    // MARK: - Name Validation Tests
    
    func testValidNames() {
        let names = [
            "John",
            "Mary Jane",
            "Jean-Claude",
            "O'Brien",
            "Anne-Marie"
        ]
        
        for name in names {
            let result = validationService.validateName(name)
            XCTAssertTrue(result.isValid, "Name '\(name)' should be valid")
        }
    }
    
    func testInvalidNames() {
        let names = [
            "",
            "J",
            "John123",
            "User@Name",
            String(repeating: "a", count: 51)
        ]
        
        for name in names {
            let result = validationService.validateName(name)
            XCTAssertFalse(result.isValid, "Name '\(name)' should be invalid")
        }
    }
    
    // MARK: - Number Validation Tests
    
    func testValidNumbers() {
        let result1 = validationService.validateNumber("42", fieldName: "Test", min: 0, max: 100)
        XCTAssertTrue(result1.isValid)
        
        let result2 = validationService.validateNumber("3.14", fieldName: "Test", allowDecimals: true)
        XCTAssertTrue(result2.isValid)
        
        let result3 = validationService.validateNumber("", fieldName: "Test") // Empty is valid for optional
        XCTAssertTrue(result3.isValid)
    }
    
    func testInvalidNumbers() {
        let result1 = validationService.validateNumber("abc", fieldName: "Test")
        XCTAssertFalse(result1.isValid)
        
        let result2 = validationService.validateNumber("3.14", fieldName: "Test", allowDecimals: false)
        XCTAssertFalse(result2.isValid)
        
        let result3 = validationService.validateNumber("150", fieldName: "Test", max: 100)
        XCTAssertFalse(result3.isValid)
        
        let result4 = validationService.validateNumber("-10", fieldName: "Test", min: 0)
        XCTAssertFalse(result4.isValid)
    }
    
    // MARK: - Plant Name Validation Tests
    
    func testValidPlantNames() {
        let names = [
            "Rose",
            "Blue Hydrangea",
            "Tomato 'Cherry'",
            "Snake Plant (Sansevieria)",
            "Peace Lily 2.0"
        ]
        
        for name in names {
            let result = validationService.validatePlantName(name)
            XCTAssertTrue(result.isValid, "Plant name '\(name)' should be valid")
        }
    }
    
    func testInvalidPlantNames() {
        let names = [
            "",
            "A",
            String(repeating: "a", count: 101),
            "Plant@#$%"
        ]
        
        for name in names {
            let result = validationService.validatePlantName(name)
            XCTAssertFalse(result.isValid, "Plant name '\(name)' should be invalid")
        }
    }
    
    // MARK: - Tag Validation Tests
    
    func testValidTags() {
        let tags = [
            "indoor",
            "low-light",
            "easy_care",
            "Zone 5"
        ]
        
        for tag in tags {
            let result = validationService.validateTag(tag)
            XCTAssertTrue(result.isValid, "Tag '\(tag)' should be valid")
        }
    }
    
    func testInvalidTags() {
        let tags = [
            "",
            String(repeating: "a", count: 31),
            "tag@#$",
            "tag/with/slashes"
        ]
        
        for tag in tags {
            let result = validationService.validateTag(tag)
            XCTAssertFalse(result.isValid, "Tag '\(tag)' should be invalid")
        }
    }
    
    // MARK: - Measurement Validation Tests
    
    func testHeightValidation() {
        XCTAssertTrue(validationService.validateHeight("10").isValid)
        XCTAssertTrue(validationService.validateHeight("5.5").isValid)
        XCTAssertFalse(validationService.validateHeight("-5").isValid)
        XCTAssertFalse(validationService.validateHeight("20000").isValid)
    }
    
    func testTemperatureValidation() {
        XCTAssertTrue(validationService.validateTemperature("72").isValid)
        XCTAssertTrue(validationService.validateTemperature("-10").isValid)
        XCTAssertFalse(validationService.validateTemperature("-100").isValid)
        XCTAssertFalse(validationService.validateTemperature("200").isValid)
    }
    
    func testHumidityValidation() {
        XCTAssertTrue(validationService.validateHumidity("50").isValid)
        XCTAssertTrue(validationService.validateHumidity("0").isValid)
        XCTAssertTrue(validationService.validateHumidity("100").isValid)
        XCTAssertFalse(validationService.validateHumidity("-10").isValid)
        XCTAssertFalse(validationService.validateHumidity("150").isValid)
    }
    
    // MARK: - Search Query Validation Tests
    
    func testValidSearchQueries() {
        let queries = [
            "tomato",
            "indoor plants",
            "low light flowers"
        ]
        
        for query in queries {
            let result = validationService.validateSearchQuery(query)
            XCTAssertTrue(result.isValid, "Query '\(query)' should be valid")
        }
    }
    
    func testInvalidSearchQueries() {
        let queries = [
            String(repeating: "a", count: 101),
            "DROP TABLE plants",
            "<script>alert('xss')</script>"
        ]
        
        for query in queries {
            let result = validationService.validateSearchQuery(query)
            XCTAssertFalse(result.isValid, "Query '\(query)' should be invalid")
        }
    }
    
    // MARK: - Sanitization Tests
    
    func testSanitization() {
        let input = "<script>alert('xss')</script> & \"test\" 'string'"
        let sanitized = validationService.sanitizeInput(input)
        
        XCTAssertFalse(sanitized.contains("<script>"))
        XCTAssertFalse(sanitized.contains("</script>"))
        XCTAssertTrue(sanitized.contains("&amp;"))
        XCTAssertTrue(sanitized.contains("&quot;"))
    }
    
    // MARK: - Batch Validation Tests
    
    func testBatchValidation() {
        let validations = [
            ("email", validationService.validateEmail("user@example.com")),
            ("name", validationService.validateName("John Doe")),
            ("age", validationService.validateNumber("25", fieldName: "Age", min: 0, max: 120))
        ]
        
        let (isValid, errors) = validationService.validateFields(validations)
        XCTAssertTrue(isValid)
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testBatchValidationWithErrors() {
        let validations = [
            ("email", validationService.validateEmail("invalid")),
            ("name", validationService.validateName("")),
            ("age", validationService.validateNumber("200", fieldName: "Age", max: 120))
        ]
        
        let (isValid, errors) = validationService.validateFields(validations)
        XCTAssertFalse(isValid)
        XCTAssertEqual(errors.count, 3)
        XCTAssertNotNil(errors["email"])
        XCTAssertNotNil(errors["name"])
        XCTAssertNotNil(errors["age"])
    }
}