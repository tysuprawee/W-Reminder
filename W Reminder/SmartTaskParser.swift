//
//  SmartTaskParser.swift
//  W Reminder
//
//  Upgraded Smart Parser:
//  - expands shortcuts (tmr, nxt, w/, mins, hrs, 5p -> 5 pm)
//  - supports relative duration: "in 20 mins"
//  - extracts best due date (earliest future if multiple)
//  - removes ALL detected date phrases safely
//  - smarter title vs notes split + universal cleanup
//

import Foundation
import NaturalLanguage

struct SmartTaskParser {

    struct ParsedResult {
        let title: String
        let notes: String?
        let dueDate: Date?
        let recurrenceRule: String?
        let detectedTag: String? // New field
    }

    static func parse(text: String, now: Date = Date(), existingTags: [String] = []) -> ParsedResult { // Signature update
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else {
            return ParsedResult(title: "", notes: nil, dueDate: nil, recurrenceRule: nil, detectedTag: nil)
        }

        // 0) Preprocess
        var working = preprocess(original)
        
        // 0.2) Extract Explicit Tags (#Tag)
        var explicitTag: String? = nil
        extractExplicitTag(&working, foundTag: &explicitTag)
        
        // 0.5) Extract Recurrence (e.g. "every month")
        let recurrence = extractRecurrenceRule(&working)

        // 1) Relative Duration
        var dueDate: Date? = extractRelativeDuration(&working, now: now)

        // 1.5) Handle "on the 1st" manually if not found yet (Common in recurring bills)
        if dueDate == nil {
            dueDate = extractDayOfMonth(&working, now: now)
        }

        // 2) Absolute Date
        if dueDate == nil {
            dueDate = extractBestDateAndRemoveAllMatches(&working, now: now)
        }

        // 3) Clean
        working = cleanString(working)

        // 4) Title/Notes
        let (title, notes) = decideTitleAndNotes(from: working)

        // 5) Final Polish
        let finalTitle = polishTitle(title)
        
        // 6) Smart Tag Detection (Only if no explicit tag)
        var finalTag = explicitTag
        if finalTag == nil && !finalTitle.isEmpty {
             finalTag = SmartClassifier.suggestTag(for: finalTitle, existingTags: existingTags)
        }

        return ParsedResult(
            title: finalTitle,
            notes: notes,
            dueDate: dueDate,
            recurrenceRule: recurrence,
            detectedTag: finalTag
        )
    }
} // Restore missing struct closing brace

// MARK: - Preprocess
private extension SmartTaskParser {

    static func preprocess(_ text: String) -> String {
        var s = text

        // Normalize punctuation
        s = s.replacingOccurrences(of: "—", with: "-")
        s = s.replacingOccurrences(of: "–", with: "-")

        // Expand shortcuts
        s = normalizeShortcuts(s)

        // Collapse whitespace
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeShortcuts(_ text: String) -> String {
        var s = text

        // Regex rules (case-insensitive)
        let rules: [(String, String)] = [
            (#"(?i)\b(tmr|tmrw)\b"#, "tomorrow"),
            (#"(?i)\b(tday|tdy)\b"#, "today"),
            (#"(?i)\b(nxt)\b"#, "next"),
            (#"(?i)\b(wk)\b"#, "week"), // New
            (#"(?i)\b(yr|yrs)\b"#, "year"),
            (#"(?i)\b(min|mins)\b"#, "minutes"),
            (#"(?i)\b(hr|hrs)\b"#, "hours"),
            (#"(?i)\b(sec|secs)\b"#, "seconds"),
            
            // Contextual Time
            (#"(?i)\bEOD\b"#, "5 pm"),
            (#"(?i)\bafter work\b"#, "6 pm"),
            
            // Vague dates -> Concrete dates for Detector
            (#"(?i)\bnext week\b"#, "next Monday"),
            (#"(?i)\bthis weekend\b"#, "Saturday"),
            (#"(?i)\bnext weekend\b"#, "next Saturday"),
            
            // "at 5" -> "at 5:00" (if not followed by : or . or am/pm) to help NSDataDetector
            (#"(?i)\bat (\d{1,2})(?!\s?(:|\.|am|pm))"#, "at $1:00"),
            
            // Normalize "at 8.30" -> "at 8:30"
            (#"(?i)\bat (\d{1,2})\.(\d{2})\b"#, "at $1:$2"),
            
            // Normalize "8.30pm" -> "8:30 pm"
            (#"(?i)\b(\d{1,2})\.(\d{2})(?:\s*)(am|pm)\b"#, "$1:$2 $3"),

            // w/ (slash breaks word boundary, so handle separately)
            (#"(?i)(^|\s)w\s*/\s*"#, " with "),

            // 5p / 5a -> 5 pm / 5 am
            (#"(?i)\b(\d{1,2})p\b"#, "$1 pm"),
            (#"(?i)\b(\d{1,2})a\b"#, "$1 am"),

            // "around 5" -> "at 5:00"
            (#"(?i)\baround (\d{1,2})(?!\s?(:|\.|am|pm))"#, "at $1:00"),
            // "around 5pm" -> "at 5pm" (let subsequent normalizer handle the rest)
            (#"(?i)\baround (\d+)"#, "at $1"),
        ]

        for (pattern, replacement) in rules {
            if let re = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(s.startIndex..<s.endIndex, in: s)
                s = re.stringByReplacingMatches(in: s, range: range, withTemplate: replacement)
            }
        }

        // clean spaces after replacements
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func extractExplicitTag(_ text: inout String, foundTag: inout String?) {
        // Match #TagName (simple alphanumeric)
        let pattern = "#(\\w+)"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = re.firstMatch(in: text, range: range),
           let tagRange = Range(match.range(at: 1), in: text),
           let fullRange = Range(match.range, in: text) {
            
            foundTag = String(text[tagRange])
            
            // Remove from text
            text.removeSubrange(fullRange)
            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - Relative duration ("in 20 minutes")
private extension SmartTaskParser {

    static func extractRelativeDuration(_ text: inout String, now: Date) -> Date? {
        let pattern = #"(?i)\b(in)\s+(\d+)\s*(seconds|second|secs|sec|minutes|minute|mins|min|hours|hour|hrs|hr|days|day)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }

        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, range: full),
              let qtyRange = Range(match.range(at: 2), in: text),
              let unitRange = Range(match.range(at: 3), in: text),
              let wholeRange = Range(match.range, in: text)
        else { return nil }

        let qty = Int(text[qtyRange]) ?? 0
        let unit = text[unitRange].lowercased()

        var seconds: TimeInterval = 0
        if ["second","seconds","sec","secs"].contains(unit) { seconds = TimeInterval(qty) }
        else if ["minute","minutes","min","mins"].contains(unit) { seconds = TimeInterval(qty) * 60 }
        else if ["hour","hours","hr","hrs"].contains(unit) { seconds = TimeInterval(qty) * 3600 }
        else if ["day","days"].contains(unit) { seconds = TimeInterval(qty) * 86400 }

        guard seconds > 0 else { return nil }

        // Remove the phrase from text
        text.removeSubrange(wholeRange)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return now.addingTimeInterval(seconds)
    }
}

// MARK: - Recurrence & Day of Month
private extension SmartTaskParser {

    static func extractRecurrenceRule(_ text: inout String) -> String? {
        let rules = [
            ("daily", ["every day", "daily", "everyday", "each day"]),
            ("weekly", ["every week", "weekly", "each week", "once a week"]),
            ("monthly", ["every month", "monthly", "each month", "once a month"]),
            ("yearly", ["every year", "yearly", "annually", "each year", "once a year"])
        ]
        
        var foundRule: String? = nil
        var longestMatchRange: Range<String.Index>? = nil
        
        // Find longest matching phrase
        for (ruleKey, phrases) in rules {
            for phrase in phrases {
                if let range = text.range(of: "\\b\(phrase)\\b", options: [.caseInsensitive, .regularExpression]) {
                    if longestMatchRange == nil || range.upperBound > longestMatchRange!.upperBound { // Not strict length check but ok
                         foundRule = ruleKey
                         longestMatchRange = range
                    }
                }
            }
        }
        
        // If rule found, standardizing to ONE rule but cleaning ALL detected phrases
        // from the text to prevent repetition in title.
        if let rule = foundRule {
            // Aggressive Cleanup: Remove ALL phrases associated with ANY rule? 
            // Or just the found rule? Usually just the found rule type logic.
            // But if I say "Monthly Weekly", I probably mean one. 
            // Let's remove matches for the Identified Rule.
            
            if let targetPhrases = rules.first(where: { $0.0 == rule })?.1 {
                for phrase in targetPhrases {
                    // Loop to remove ALL instances of this phrase
                    while let range = text.range(of: "\\b\(phrase)\\b", options: [.caseInsensitive, .regularExpression]) {
                         text.removeSubrange(range)
                         // Clean immediate spacing to prevent "  "
                         text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                             .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            return rule
        }
        
        return nil
    }

    static func extractDayOfMonth(_ text: inout String, now: Date) -> Date? {
        // Matches "on the 1st", "on the 2nd", "on the 23rd", "on the 31st"
        // Also supports "on the 1", "on the 2"
        let pattern = #"(?i)\bon the (\d{1,2})(st|nd|rd|th)?\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, range: range),
              let dayRange = Range(match.range(at: 1), in: text) else { return nil }
        
        guard let dayProxy = Int(text[dayRange]), dayProxy >= 1, dayProxy <= 31 else { return nil }
        
        // Determine date: Next occurrence of this day
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.year, .month, .day], from: now)
        var targetComponents = currentComponents
        targetComponents.day = dayProxy
        targetComponents.hour = 9 // Default time for "on the 1st" -> 9am
        targetComponents.minute = 0
        
        var targetDate = calendar.date(from: targetComponents)
        
        // If target date is today or past, move to next month?
        // Actually, if it's "on the 1st" and today is the 5th, we mean NEXT month.
        // If today is the 1st, maybe we mean today? Or next month? Usually today if early, next if late.
        // Let's assume strict future preference.
        if let t = targetDate, t < now {
           if let nextMonth = calendar.date(byAdding: .month, value: 1, to: t) {
               targetDate = nextMonth
           }
        }
        
        if let t = targetDate {
             // Aggressive Cleanup: Remove ALL matches of "on the X"
             let rangeAll = NSRange(text.startIndex..<text.endIndex, in: text)
             let allMatches = re.matches(in: text, range: rangeAll)
             
             // We iterate backwards to remove ranges without invalidating indices
             for match in allMatches.reversed() {
                 if let r = Range(match.range, in: text) {
                     text.removeSubrange(r)
                 }
             }
             
             text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                 .trimmingCharacters(in: .whitespacesAndNewlines)
                 
             return t
        }
        
        return nil
    }
}

// MARK: - Absolute date/time extraction (best match + remove all)
private extension SmartTaskParser {

    static func extractBestDateAndRemoveAllMatches(_ text: inout String, now: Date) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return nil }

        // Gather dates + ranges
        var found: [(date: Date, range: NSRange)] = []
        for m in matches {
            if let d = m.date { found.append((d, m.range)) }
        }
        guard !found.isEmpty else { return nil }

        // Best date:
        // Prefer earliest future date; otherwise most recent past date
        let future = found.filter { $0.date >= now }.sorted { $0.date < $1.date }
        let past = found.filter { $0.date < now }.sorted { $0.date > $1.date }
        let best = future.first?.date ?? past.first?.date

        // Remove ALL matches (must remove from end -> start)
        let rangesToRemove = found.map(\.range).sorted { $0.location > $1.location }
        for r in rangesToRemove {
            if let swiftRange = Range(r, in: text) {
                text.removeSubrange(swiftRange)
            }
        }

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return best
    }
}

// MARK: - Title & Notes
private extension SmartTaskParser {

    static func decideTitleAndNotes(from cleaned: String) -> (String, String?) {
        let s = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return ("", nil) }

        // 1. Explicit Splitters: "Title: details", "Title - details"
        let explicitSeps = [": ", " - ", "\n"]
        for sep in explicitSeps {
            if let r = s.range(of: sep) {
                let left = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let right = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !left.isEmpty, !right.isEmpty {
                    return (left, right)
                }
            }
        }
        
        // 2. Connector Splitters ("about", "because") - Helps summarize "Call bank about..."
        let connectors = [" about ", " because "]
        for conn in connectors {
            if let r = s.range(of: conn, options: .caseInsensitive) {
                let left = String(s[..<r.lowerBound])
                let right = String(s[r.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines) // Keep connector in notes?
                
                // Only split if Left is substantial enough to be a title? (at least 2 words)
                if left.split(separator: " ").count >= 2 {
                     // Normalize the left side (title)
                     let shortTitle = generateShortTitle(from: left)
                     // Combine right side with any stripped part of left? No, just use right as notes.
                     return (shortTitle, right)
                }
            }
        }

        // 3. Long input => notes = full, title = generated
        if s.count > 50 {
            return (generateShortTitle(from: s), s)
        }

        return (s, nil)
    }

    static func generateShortTitle(from text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        if words.count <= 6 { return text }

        // Find first verb OR noun near the start
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var startIndex: String.Index? = nil
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, tokenRange in
            if let t = tag, (t == .verb || t == .noun) {
                if text.distance(from: text.startIndex, to: tokenRange.lowerBound) < 32 {
                    startIndex = tokenRange.lowerBound
                    return false
                }
            }
            return true
        }

        var effective = text
        if let start = startIndex {
            effective = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Take first 5-7 words depending on length
        let ew = effective.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let limit = min(ew.count >= 10 ? 7 : 5, ew.count)
        var truncated = Array(ew.prefix(limit))

        // Remove weak ending tokens
        while let last = truncated.last, isWeakEndingToken(last) {
            truncated.removeLast()
            if truncated.isEmpty { break }
        }

        return truncated.joined(separator: " ")
    }

    static func polishTitle(_ title: String) -> String {
        var s = title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove unfinished trailing punctuation
        while let last = s.last, [":", "-", ",", "—"].contains(last) {
            s.removeLast()
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove weak endings again (just in case)
        var parts = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        while let last = parts.last, isWeakEndingToken(last) {
            parts.removeLast()
        }
        return parts.joined(separator: " ")
    }

    static func isWeakEndingToken(_ token: String) -> Bool {
        let lower = token.lowercased()

        // Fast list covers most awkward endings including pronouns & conjunctions
        let weak: Set<String> = [
            // Prepositions
            "to","with","at","on","by","for","from","of","in","into", "about", "over", "under", "through",
            // Conjunctions
            "and","or","but", "because", "so", "if", "when", "while", "since", "until", "although", "though",
            // Articles / Determiners
            "a","an","the","this","that","these","those",
            // Pronouns / Possessives (Ending a title with "my" or "him" is usually truncated context)
            "my", "your", "his", "her", "its", "our", "their",
            "i", "you", "he", "she", "we", "they",
            "me", "him", "us", "them"
        ]
        if weak.contains(lower) { return true }

        // NL fallback for other function words
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = token
        let (tag, _) = tagger.tag(at: token.startIndex, unit: .word, scheme: .lexicalClass)
        return tag == .preposition || tag == .conjunction || tag == .particle || tag == .determiner || tag == .pronoun
    }
}

// MARK: - Cleaning
private extension SmartTaskParser {

    static func cleanString(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove filler prefixes (case-insensitive)
        let prefixes = [
            "i need to ", "i want to ", "remind me to ", "task to ",
            "schedule ", "plan to ", "have to ", "please "
        ]

        let lower = s.lowercased()
        for p in prefixes {
            if lower.hasPrefix(p) {
                s = String(s.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Remove dangling weak endings (often left after date removal)
        var parts = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        while let last = parts.last, isWeakEndingToken(last) {
            parts.removeLast()
        }

        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
