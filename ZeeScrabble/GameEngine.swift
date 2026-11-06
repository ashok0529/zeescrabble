import Foundation

struct Tile: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    let letter: String
    let value: Int
    var shown: String
    init(_ letter: String, _ value: Int) { self.letter = letter; self.value = value; shown = letter }
}
struct MoveResult: Sendable { let points: Int; let words: [String] }
struct RuleError: LocalizedError { let message: String; var errorDescription: String? { message } }
struct Game: Codable, Sendable {
    var board: [Tile?] = Array(repeating: nil, count: 225)
    var bag: [Tile] = []
    var racks: [[Tile]] = [[], []]
    var scores = [0, 0]
    var turn = 0
    var scoreless = 0
    var finished = false
    var history: [String] = []
    static let distribution: [(String, Int, Int)] = [
        ("A",1,9),("B",3,2),("C",3,2),("D",2,4),("E",1,12),("F",4,2),("G",2,3),
        ("H",4,2),("I",1,9),("J",8,1),("K",5,1),("L",1,4),("M",3,2),("N",1,6),
        ("O",1,8),("P",3,2),("Q",10,1),("R",1,6),("S",1,4),("T",1,6),("U",1,4),
        ("V",4,2),("W",4,2),("X",8,1),("Y",4,2),("Z",10,1),("?",0,2)]
    init() {
        bag = Self.distribution.flatMap { letter, value, count in (0..<count).map { _ in Tile(letter, value) } }.shuffled()
        fill(0); fill(1)
    }
    mutating func fill(_ player: Int) {
        while racks[player].count < 7, let tile = bag.popLast() { racks[player].append(tile) }
    }
    static func neighbor(_ cell: Int, _ step: Int) -> Int? {
        let next = cell + step
        guard (0..<225).contains(next), abs(step) != 1 || cell / 15 == next / 15 else { return nil }
        return next
    }
    static func premium(_ i: Int) -> (letter: Int, word: Int, label: String) {
        let r = i / 15, c = i % 15
        let tw: Set<Int> = [0,7,14,105,119,210,217,224]
        let tl: Set<Int> = [20,24,76,80,84,88,136,140,144,148,200,204]
        let dl: Set<Int> = [3,11,36,38,45,52,59,92,96,98,102,108,116,122,126,128,132,165,172,179,186,188,213,221]
        if tw.contains(i) { return (1,3,"TW") }
        if (r == c || r + c == 14) && (1...4).contains(min(r,14-r)) || i == 112 { return (1,2,i == 112 ? "★" : "DW") }
        if tl.contains(i) { return (3,1,"TL") }
        if dl.contains(i) { return (2,1,"DL") }
        return (1,1,"")
    }
    func evaluate(_ placed: [Int: Tile], lexicon: Lexicon) throws -> MoveResult {
        guard !finished, !placed.isEmpty, placed.count <= 7 else { throw RuleError(message: "Place tiles before playing.") }
        var remaining = racks[turn].map(\.id)
        for (i,tile) in placed {
            guard (0..<225).contains(i), board[i] == nil,
                  let rackIndex = remaining.firstIndex(of: tile.id),
                  let original = racks[turn].first(where: { $0.id == tile.id }),
                  tile.value == original.value, tile.letter == original.letter,
                  tile.shown.count == 1, tile.shown.utf8.allSatisfy({ (65...90).contains($0) }),
                  tile.letter == "?" || tile.shown == tile.letter else {
                throw RuleError(message: "Use your rack tiles on empty squares. Choose a letter for each blank.")
            }
            remaining.remove(at: rackIndex)
        }
        let cells = placed.keys.sorted()
        let sameRow = Set(cells.map { $0 / 15 }).count == 1
        let sameColumn = Set(cells.map { $0 % 15 }).count == 1
        guard sameRow || sameColumn else { throw RuleError(message: "Tiles must be in a single row or column.") }
        let step = sameRow ? 1 : 15
        func tile(_ i: Int) -> Tile? { placed[i] ?? board[i] }
        if let first = cells.first, let last = cells.last {
            for i in stride(from: first, through: last, by: step) where tile(i) == nil {
                throw RuleError(message: "There’s a gap between your tiles.")
            }
        }
        let empty = board.allSatisfy { $0 == nil }
        if empty {
            guard placed[112] != nil else { throw RuleError(message: "Your first word must cover the center star.") }
        } else {
            guard cells.contains(where: { i in [1,-1,15,-15].contains { d in
                Self.neighbor(i,d).map { board[$0] != nil } ?? false
            } }) else { throw RuleError(message: "Connect your word to a tile already on the board.") }
        }
        var sequences = Set<[Int]>()
        for i in cells {
            for d in [1,15] {
                var start = i
                while let prev = Self.neighbor(start,-d), tile(prev) != nil { start = prev }
                var run = [start]
                var end = start
                while let next = Self.neighbor(end,d), tile(next) != nil { run.append(next); end = next }
                if run.count > 1 { sequences.insert(run) }
            }
        }
        guard !sequences.isEmpty else { throw RuleError(message: "Make a word of at least two letters.") }
        var points = 0, words: [String] = []
        for run in sequences.sorted(by: { $0.lexicographicallyPrecedes($1) }) {
            let word = run.map { tile($0)!.shown }.joined()
            guard lexicon.contains(word) else { throw RuleError(message: "\(word) isn’t in this game’s dictionary.") }
            var total = 0, multiplier = 1
            for i in run {
                let premium = placed[i] == nil ? (letter: 1, word: 1, label: "") : Self.premium(i)
                total += tile(i)!.value * premium.letter
                multiplier *= premium.word
            }
            points += total * multiplier; words.append(word)
        }
        if placed.count == 7 { points += 50 }
        return MoveResult(points: points, words: words)
    }
    mutating func play(_ placed: [Int: Tile], lexicon: Lexicon) throws {
        let result = try evaluate(placed, lexicon: lexicon)
        let player = turn
        for (i,tile) in placed { board[i] = tile }
        let ids = Set(placed.values.map(\.id))
        racks[player].removeAll { ids.contains($0.id) }
        scores[player] += result.points
        history.insert("\(player == 0 ? "You" : "Computer"): \(result.words.joined(separator: ", ")) +\(result.points)", at: 0)
        scoreless = result.points == 0 ? scoreless + 1 : 0
        fill(player)
        finishIfNeeded(); turn = 1-player
    }
    mutating func pass() {
        guard !finished else { return }
        history.insert("\(turn == 0 ? "You" : "Computer") passed", at: 0)
        scoreless += 1; finishIfNeeded(); turn = 1-turn
    }
    mutating func exchange(_ ids: Set<UUID>) throws {
        guard !finished, bag.count >= 7, !ids.isEmpty, ids.isSubset(of: Set(racks[turn].map(\.id))) else {
            throw RuleError(message: "Select rack tiles to exchange. At least seven tiles must remain in the bag.")
        }
        let returned = racks[turn].filter { ids.contains($0.id) }
        racks[turn].removeAll { ids.contains($0.id) }
        fill(turn) // Draw replacements before returning the exchanged tiles.
        bag.append(contentsOf: returned); bag.shuffle()
        history.insert("\(turn == 0 ? "You" : "Computer") exchanged \(returned.count) tiles", at: 0)
        scoreless += 1; finishIfNeeded(); turn = 1-turn
    }
    mutating func finishIfNeeded() {
        let wentOut = bag.isEmpty && racks[turn].isEmpty
        guard wentOut || scoreless >= 6 else { return }
        let penalties = racks.map { $0.reduce(0) { $0 + $1.value } }
        for p in 0...1 { scores[p] -= penalties[p] }
        if wentOut { scores[turn] += penalties[1-turn] }
        finished = true
        history.insert("Game over · rack values deducted", at: 0)
    }
}

final class Lexicon: @unchecked Sendable {
    struct Node { var children: [UInt8: Int] = [:]; var word = false }
    private(set) var nodes = [Node()]
    init(text: String) {
        for word in text.split(whereSeparator: \.isWhitespace) {
            let letters = Array(word.uppercased().utf8)
            guard (2...15).contains(letters.count), letters.allSatisfy({ (65...90).contains($0) }) else { continue }
            var node = 0
            for letter in letters {
                if let next = nodes[node].children[letter] { node = next }
                else {
                    let next = nodes.count
                    nodes.append(Node()); nodes[node].children[letter] = next; node = next
                }
            }
            nodes[node].word = true
        }
    }
    func contains(_ word: String) -> Bool {
        var node = 0
        for letter in word.utf8 {
            guard let next = nodes[node].children[letter] else { return false }
            node = next
        }
        return nodes[node].word
    }
}

struct ComputerMove: Sendable { let tiles: [Int: Tile]; let points: Int }
enum Opponent {
    static func bestMove(game: Game, lexicon: Lexicon, seconds: Double = 5) -> ComputerMove? {
        let deadline = Date().addingTimeInterval(seconds)
        var best: ComputerMove?
        var visits = 0
        let empty = game.board.allSatisfy { $0 == nil }
        let anchors = Set((0..<225).filter { i in
            game.board[i] == nil && (empty ? i == 112 : [1,-1,15,-15].contains { d in
                Game.neighbor(i,d).map { game.board[$0] != nil } ?? false
            })
        })
        // Candidate words grow through a trie; each perpendicular word is checked before branching.
        for step in [1,15] {
            var cross: [Int: Set<UInt8>] = [:]
            let perpendicular = step == 1 ? 15 : 1
            for cell in 0..<225 where game.board[cell] == nil {
                var prefix = "", suffix = "", cursor = cell
                while let prev = Game.neighbor(cursor,-perpendicular), let t = game.board[prev] { prefix = t.shown + prefix; cursor = prev }
                cursor = cell
                while let next = Game.neighbor(cursor,perpendicular), let t = game.board[next] { suffix += t.shown; cursor = next }
                if !prefix.isEmpty || !suffix.isEmpty {
                    cross[cell] = Set((UInt8(65)...UInt8(90)).filter { lexicon.contains(prefix + String(UnicodeScalar($0)) + suffix) })
                }
            }
            for start in 0..<225 {
                if let prev = Game.neighbor(start,-step), game.board[prev] != nil { continue }
                var scan: Int? = start, blanks = 0, canReach = false
                while let cell = scan, blanks <= 7 {
                    if anchors.contains(cell) { canReach = true; break }
                    if game.board[cell] == nil { blanks += 1 }
                    scan = Game.neighbor(cell,step)
                }
                guard canReach else { continue }
                func walk(_ cell: Int?, _ node: Int, _ rack: [Tile], _ placed: [Int: Tile], _ touches: Bool) {
                    visits += 1
                    if visits % 256 == 0 && (Date() >= deadline || Task.isCancelled) { return }
                    if lexicon.nodes[node].word, !placed.isEmpty, touches, cell == nil || game.board[cell!] == nil,
                       let result = try? game.evaluate(placed, lexicon: lexicon), result.points > (best?.points ?? -1) {
                        best = ComputerMove(tiles: placed, points: result.points)
                    }
                    guard let cell, Date() < deadline, !Task.isCancelled else { return }
                    if let tile = game.board[cell] {
                        if let letter = tile.shown.utf8.first, let next = lexicon.nodes[node].children[letter] {
                            walk(Game.neighbor(cell,step), next, rack, placed, touches)
                        }
                    } else {
                        var used = Set<String>()
                        for (index,tile) in rack.enumerated() where used.insert(tile.letter).inserted {
                            for (letter,next) in lexicon.nodes[node].children {
                                guard tile.letter == "?" || tile.letter.utf8.first == letter,
                                      cross[cell] == nil || cross[cell]!.contains(letter) else { continue }
                                var remaining = rack; remaining.remove(at: index)
                                var tiles = placed, assigned = tile
                                assigned.shown = String(UnicodeScalar(letter)); tiles[cell] = assigned
                                walk(Game.neighbor(cell,step), next, remaining, tiles, touches || anchors.contains(cell))
                            }
                        }
                    }
                }
                walk(start, 0, game.racks[game.turn], [:], false)
                if Date() >= deadline || Task.isCancelled { return best }
            }
        }
        return best
    }
}
