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
        guard !keywords.isEmpty else { return nil }
        
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
        
        // Threshold: If existing match is good (< 0.5), return it.
        // Otherwise, suggest a NEW generic category based on the keyword.
        if bestDistance < 0.6 {
            return bestCandidate
        } else {
            // No good existing tag. Suggest a generic one based on the keyword's category.
            // Map keywords to "Base Categories"
            return suggestNewCategory(for: keywords, embedding: embedding)
        }
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
        
        // Relaxed threshold to 0.85 to suggest categories even more aggressively
        return bestDist < 0.85 ? bestCat : nil
    }
}
