import NaturalLanguage
if let embedding = NLEmbedding.wordEmbedding(for: .english) {
    let words = ["wife", "date", "mom"]
    let cats = ["Family", "Personal", "Social", "Love"]
    
    for word in words {
        for cat in cats {
            let dist = embedding.distance(between: word, and: cat)
            print("\(word) -> \(cat): \(dist)")
        }
    }
}
