//
//  UtilityTests.swift
//  W Reminder Tests
//
//  Tests for utility functions and extensions
//

import XCTest
import SwiftUI
@testable import W_Reminder

final class UtilityTests: XCTestCase {
    
    // MARK: - Color Extension Tests
    
    func testColorFromHex() {
        // Given
        let redHex = "#FF0000"
        let greenHex = "#00FF00"
        let blueHex = "#0000FF"
        
        // When
        let redColor = Color(hex: redHex)
        let greenColor = Color(hex: greenHex)
        let blueColor = Color(hex: blueHex)
        
        // Then - Should create colors without crashing
        XCTAssertNotNil(redColor)
        XCTAssertNotNil(greenColor)
        XCTAssertNotNil(blueColor)
    }
    
    func testColorToHex() {
        // Given
        let red = Color.red
        let green = Color.green
        let blue = Color.blue
        
        // When
        let redHex = red.toHex()
        let greenHex = green.toHex()
        let blueHex = blue.toHex()
        
        // Then - Should produce valid hex strings
        XCTAssertTrue(redHex.hasPrefix("#"))
        XCTAssertEqual(redHex.count, 7) // #RRGGBB
        XCTAssertTrue(greenHex.hasPrefix("#"))
        XCTAssertEqual(greenHex.count, 7)
        XCTAssertTrue(blueHex.hasPrefix("#"))
        XCTAssertEqual(blueHex.count, 7)
    }
    
    func testInvalidHexColor() {
        // Given
        let invalidHex = "INVALID"
        
        // When
        let color = Color(hex: invalidHex)
        
        // Then - Should still create a color (fallback behavior)
        XCTAssertNotNil(color)
    }
    
    // MARK: - Theme Tests
    
    func testDefaultTheme() {
        // Given
        let theme = Theme.default
        
        // Then
        XCTAssertEqual(theme.name, "Classic Calm")
        XCTAssertEqual(theme.id, "classic")
        XCTAssertNotNil(theme.primary)
        XCTAssertNotNil(theme.secondary)
        XCTAssertNotNil(theme.accent)
        XCTAssertNotNil(theme.background)
    }
    
    func testAllThemes() {
        // When
        let themes = Theme.all
        
        // Then
        XCTAssertGreaterThan(themes.count, 0, "Should have at least one theme")
        XCTAssertTrue(themes.contains(where: { $0.id == "classic" }), "Should contain the classic theme")
    }
    
    func testThemeIdentifiable() {
        // Given
        let theme = Theme.default
        
        // Then - Verify theme conforms to Identifiable
        XCTAssertEqual(theme.id, "classic")
    }
}
