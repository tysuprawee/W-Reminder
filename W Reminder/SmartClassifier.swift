//
//  SmartClassifier.swift
//  W Reminder
//
//  Created for W Reminder 1.05
//

import Foundation
import NaturalLanguage

struct SmartClassifier {

    /// Finds a smart suggestion for a tag based on the task title using NL embedding.
    /// - Parameters:
    ///   - text: The task title/description.
    ///   - existingTags: List of current tag names in the user's database.
    /// - Returns: A suggested tag name (existing or new), or nil if no good match.
    static func suggestTag(for text: String, existingTags: [String]) -> String? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return nil }
        
        // 1. Extract the "Core" Noun/Verb from the text to vectorize
        // (e.g., "Buy Milk" -> "Milk", "Call Mom" -> "Call")
        let keywords = extractKeywords(from: text)
        guard !keywords.isEmpty else { return "Personal" }
        
        // Manual Keyword Override (Fast Path)
        // Some words are so specific they should bypass embedding lookup
        if let manual = checkManualOverrides(keywords) {
            return manual
        }
        
        
        var bestCandidate: String?
        var bestDistance: Double = 1.0 // 0.0 = identical, 2.0 = opposite
        
        // 2. Check against Existing Tags
        for tag in existingTags {
            // Compare each keyword against the tag name
            for keyword in keywords {
                // Direct string match?
                if tag.localizedCaseInsensitiveContains(keyword) {
                    return tag // Exact match found
                }
                
                // Vector distance
                let dist = embedding.distance(between: keyword.lowercased(), and: tag.lowercased())
                if dist < bestDistance {
                    bestDistance = dist
                    bestCandidate = tag
                }
            }
        }
        
        // Limit: If existing match is very good (< 0.75), trust it to avoid clutter.
        if bestDistance < 0.75 {
            return bestCandidate
        }
        
        // Otherwise, find the BEST Universal Category (even if weak)
        return suggestNewCategory(for: keywords, embedding: embedding)
    }
    
    private static func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            if let tag = tag, (tag == .noun || tag == .verb) {
                keywords.append(String(text[range]))
            }
            return true
        }
        return keywords
    }
    
    private static func suggestNewCategory(for keywords: [String], embedding: NLEmbedding) -> String? {
        // Pre-defined "Universal" Categories to map towards
        let universals = [
            "Work", "Personal", "Family", "Shopping", "Health", "Finance",
            "Home", "Travel", "Study", "Social", "Entertainment", "Chores",
            "Life", "Love" 
        ]
        
        var bestCat: String?
        var bestDist: Double = 1.0
        
        for keyword in keywords {
            for cat in universals {
                let dist = embedding.distance(between: keyword.lowercased(), and: cat.lowercased())
                if dist < bestDist {
                    bestDist = dist
                    bestCat = cat
                }
            }
        }
        
        // Always return the best category found.
        // If nothing matches well (extremely unlikely), default to "Personal"
        return bestCat ?? "Personal"
    }
    private static func checkManualOverrides(_ keywords: [String]) -> String? {
        for word in keywords {
            let lower = word.lowercased()
            if ["gym", "workout", "run", "fitness", "yoga"].contains(lower) { return "Health" }
            if ["bill", "rent", "fee", "tax", "invoice", "bank"].contains(lower) { return "Finance" }
            if ["mom", "dad", "sister", "brother", "wife", "husband"].contains(lower) { return "Family" }
            if ["study", "homework", "exam", "quiz", "class"].contains(lower) { return "Study" }
            if ["groceries", "milk", "bread", "eggs"].contains(lower) { return "Shopping" }
        }
        return nil
    }
}
