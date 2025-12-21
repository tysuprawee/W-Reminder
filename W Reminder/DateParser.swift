//
//  DateParser.swift
//  W Reminder
//
//  Created for Smart Date Parsing
//

import Foundation

struct SmartDateResult {
    let date: Date
    let cleanedText: String
}

class DateParser {
    static let shared = DateParser()
    
    private let detector: NSDataDetector?
    
    init() {
        // We look for dates and times
        self.detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }
    
    /// Parses the input string for date/time references.
    /// Returns a SmartDateResult if a date is found found with high confidence.
    /// The cleanedText removes the substring that matched the date.
    func parse(_ text: String) -> SmartDateResult? {
        guard let detector = detector else { return nil }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        
        // We take the first match that looks like a valid future date or time
        for match in matches {
            if match.resultType == .date, let date = match.date {
                // Determine the range of text that matched
                if let range = Range(match.range, in: text) {
                    let prefix = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                    let suffix = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    let cleaned = (prefix + " " + suffix).trimmingCharacters(in: .whitespaces)
                    
                    return SmartDateResult(date: date, cleanedText: cleaned)
                }
            }
        }
        
        return nil
    }
}
