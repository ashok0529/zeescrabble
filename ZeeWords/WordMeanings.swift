import Foundation

struct WordMeanings: Sendable {
    private var entries: [String: String] = [:]

    init(text: String) {
        for line in text.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let word = line[..<separator].trimmingCharacters(in: .whitespaces).uppercased()
            let meaning = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty, !meaning.isEmpty,
                  !meaning.lowercased().hasPrefix("meaning not available") else { continue }
            entries[word] = meaning
        }
    }

    func meaning(for word: String) -> String? { entries[word] }
}
