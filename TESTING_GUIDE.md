# Testing Guide for W Reminder

This guide will help you understand and use the tests in the W Reminder app.

## What are Unit Tests?

Unit tests are automated tests that verify individual components (units) of your code work correctly. They help:
- **Catch bugs early** before they reach production
- **Document behavior** - tests serve as examples of how code should work
- **Enable confident refactoring** - you can change code knowing tests will catch breakage
- **Speed up development** - automated tests are faster than manual testing

## Test Structure

The W Reminder app has three unit test files and one UI test file:

### Unit Tests

#### 1. `ModelTests.swift`
Tests the core SwiftData models:
- **Tag**: Creation, color conversion
- **ChecklistItem**: Creation, toggling completion
- **Checklist**: Creation with items, tags, completion status
- **SimpleChecklist**: Creation and toggling
- **Relationships**: Parent-child relationships between models
- **SwiftData operations**: Fetching and filtering data

#### 2. `UtilityTests.swift`
Tests utility functions and extensions:
- **Color conversions**: Hex to Color and Color to Hex
- **Dark color detection**: Determining if colors are dark
- **Theme**: Default theme configuration

#### 3. `TimelineTests.swift`
Tests time-related functionality and TimelineView synchronization:
- **Time remaining calculations**: Accurate time interval calculations
- **Time display formatting**: Proper display strings for different time ranges
- **Minute boundary alignment**: Ensures updates sync with clock
- **Refresh state management**: UUID-based view refresh mechanism
- **Overdue task handling**: Correct formatting for past-due times

### UI Tests

#### 4. `TimelineUITests.swift`
Tests user interface and TimelineView automatic updates:
- **Time display visibility**: Verifies time remaining text appears
- **Pull-to-refresh**: Tests manual refresh gesture
- **Tab navigation**: Ensures smooth navigation between views
- **Settings integration**: Checks silent mode info display
- **Performance**: Measures scroll and interaction performance

## How to Set Up Tests

### Step 1: Add Test Target to Xcode

1. Open `W Reminder.xcodeproj` in Xcode
2. Go to **File → New → Target...**
3. Select **Unit Testing Bundle**
4. Name it: `W ReminderTests`
5. Ensure "Target to be Tested" is set to `W Reminder`
6. Click **Finish**

### Step 2: Add Test Files

1. In Xcode's Project Navigator, find the `W ReminderTests` folder
2. Delete the default test file created by Xcode
3. Add the test files you created:
   - Right-click on `W ReminderTests` folder
   - Select **Add Files to "W Reminder"...**
   - Navigate to and select:
     - `ModelTests.swift`
     - `UtilityTests.swift`
   - Ensure they're added to the `W ReminderTests` target

### Step 3: Configure Test Target

1. Select the project in the navigator
2. Select the `W ReminderTests` target
3. Go to **Build Phases → Link Binary With Libraries**
4. If SwiftData isn't listed, click **+** and add it
5. Go to **Build Settings**
6. Search for "Module Name" and ensure it's set correctly

## How to Run Tests

### Running All Tests

**Method 1: Keyboard Shortcut**
- Press `⌘ + U` (Command + U)

**Method 2: Menu**
- Go to **Product → Test**

**Method 3: Test Navigator**
- Press `⌘ + 6` (Command + 6) to open Test Navigator
- Click the play button next to "W ReminderTests"

### Running Individual Test Files

In the Test Navigator (`⌘ + 6`):
- Click the play button next to `ModelTests` or `UtilityTests`

### Running Individual Test Methods

In the Test Navigator:
- Expand a test file
- Click the play button next to any specific test (e.g., `testTagCreation()`)

**Or** in the code editor:
- Look for the diamond icon in the gutter next to each test method
- Click it to run that specific test

### Running UI Tests

**Method 1: Using Test Navigator**
- Press `⌘ + 6` to open Test Navigator
- Expand `W ReminderUITests`
- Click the play button next to `TimelineUITests`

**Method 2: Run All UI Tests**
- Select the `W ReminderUITests` scheme in Xcode
- Press `⌘ + U`

**Note**: UI tests will launch the app in the simulator and interact with it automatically. They take longer than unit tests.

## Understanding Test Results

### ✅ Green Checkmark
- Test passed successfully
- The code behaves as expected

### ❌ Red X
- Test failed
- Click on the failed test to see the assertion that failed
- The error message will show what was expected vs. what actually happened

### Example Failed Test Output
```
XCTAssertEqual failed: ("Work") is not equal to ("Personal")
```
This means the test expected "Work" but got "Personal"

## Reading a Test

Tests follow the **Arrange-Act-Assert** pattern:

```swift
func testTagCreation() throws {
    // ARRANGE (Given) - Set up test conditions
    let tagName = "Work"
    let colorHex = "#FF5733"
    
    // ACT (When) - Perform the action being tested
    let tag = Tag(name: tagName, colorHex: colorHex)
    modelContext.insert(tag)
    
    // ASSERT (Then) - Verify the results
    XCTAssertEqual(tag.name, tagName)
    XCTAssertEqual(tag.colorHex, colorHex)
    XCTAssertNotNil(tag.id)
}
```

## Common XCTest Assertions

- `XCTAssertEqual(a, b)` - Verifies `a` equals `b`
- `XCTAssertNotEqual(a, b)` - Verifies `a` does not equal `b`
- `XCTAssertTrue(condition)` - Verifies condition is true
- `XCTAssertFalse(condition)` - Verifies condition is false
- `XCTAssertNil(value)` - Verifies value is nil
- `XCTAssertNotNil(value)` - Verifies value is not nil
- `XCTAssertThrowsError(expression)` - Verifies expression throws an error
- `XCTAssertNoThrow(expression)` - Verifies expression doesn't throw

## Writing Your Own Tests

### Template for a New Test

```swift
func testYourFeature() throws {
    // Given - Set up the conditions
    let input = "test data"
    
    // When - Execute the code you're testing
    let result = functionToTest(input)
    
    // Then - Verify the outcome
    XCTAssertEqual(result, expectedValue)
}
```

### Best Practices

1. **One assertion per test** (ideally) - Makes it clear what failed
2. **Descriptive test names** - `testUserCannotDeleteCompletedTask` is better than `testDelete`
3. **Test edge cases** - Empty strings, nil values, maximum values
4. **Keep tests independent** - Tests shouldn't depend on each other
5. **Use setUp/tearDown** - Initialize common test data in `setUp()`, clean up in `tearDown()`

### Example: Adding a New Test

Let's say you want to test that a checklist can't have more than 3 tags:

```swift
func testChecklistMaxThreeTags() throws {
    // Given
    let tag1 = Tag(name: "Tag1", colorHex: "#FF0000")
    let tag2 = Tag(name: "Tag2", colorHex: "#00FF00")
    let tag3 = Tag(name: "Tag3", colorHex: "#0000FF")
    let tag4 = Tag(name: "Tag4", colorHex: "#FFFF00")
    
    // When
    let checklist = Checklist(
        title: "Test",
        notes: nil,
        dueDate: nil,
        remind: false,
        items: [],
        tags: [tag1, tag2, tag3, tag4]
    )
    
    // Then
    XCTAssertLessThanOrEqual(checklist.tags.count, 3, 
                             "Checklist should not have more than 3 tags")
}
```

## Test Coverage

To see how much of your code is covered by tests:

1. **Enable Code Coverage**:
   - Go to **Product → Scheme → Edit Scheme...**
   - Select **Test** in the left sidebar
   - Check **Code Coverage** under Options
   - Click **Close**

2. **View Coverage Report**:
   - Run tests (`⌘ + U`)
   - Open the **Report Navigator** (`⌘ + 9`)
   - Select the latest test run
   - Click the **Coverage** tab
   - Expand files to see which lines are covered

**Good Coverage**: Aim for 70-80% coverage for core business logic

## Continuous Testing

### While Coding
- Keep the Test Navigator (`⌘ + 6`) open
- Run related tests frequently as you code
- Fix failing tests immediately

### Before Committing
- Run all tests (`⌘ + U`)
- Ensure all tests pass before committing code
- Add new tests for new features

## Troubleshooting

### Tests Won't Run
- **Check scheme**: Ensure test target is included in the scheme
- **Clean build**: `⌘ + Shift + K`, then rebuild
- **Check target membership**: Ensure test files are in the test target

### Tests Fail Unexpectedly
- **Check test isolation**: Tests might be affecting each other
- **Review setUp/tearDown**: Ensure clean state for each test
- **Check for timing issues**: Add `XCTestExpectation` for async code

### "Module Not Found" Error
- Ensure `@testable import W_Reminder` matches your module name
- Check test target's **Build Settings → Packaging → Product Module Name**

## Next Steps

1. **Add more tests** as you develop new features
2. **Practice TDD** (Test-Driven Development):
   - Write test first (it will fail - "Red")
   - Write minimal code to pass test ("Green")
   - Refactor code while keeping tests passing ("Refactor")
3. **Set up CI/CD** to run tests automatically on commits
4. **Add UI tests** for testing user interactions

## Resources

- [Apple's XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing in Xcode - WWDC Videos](https://developer.apple.com/videos/play/wwdc2019/413/)
- [Test-Driven Development (TDD) Guide](https://www.agilealliance.org/glossary/tdd/)

---

**Remember**: Good tests give you confidence to ship great code! 🚀
