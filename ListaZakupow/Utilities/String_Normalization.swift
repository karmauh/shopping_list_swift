import Foundation

extension String {
    var comparisonKey: String {
        let folded = folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let replaced = folded.replacingOccurrences(of: "ł", with: "l")
        return replaced
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
