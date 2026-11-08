import SwiftUI

@MainActor @Observable final class GameStore {
    var game = Game()
    var placed: [Int: Tile] = [:]
    var selected: UUID?
    var computerPlaced: [Int: Tile] = [:]
    var computerHighlights = Set<Int>()
    private var highlightTask: Task<Void, Never>?
    var thinking = false
    var loading = true
    var message: String?
    var lexicon: Lexicon?
    private var worker: Task<ComputerMove?, Never>?
    private var generation = UUID()
    private var saveURL: URL {
        URL.documentsDirectory.appendingPathComponent("game-v1.json")
    }
    var remainingRack: [Tile] { game.racks[0].filter { t in !placed.values.contains { $0.id == t.id } } }
    var preview: Int? {
        guard let lexicon else { return nil }
        return try? game.evaluate(placed, lexicon: lexicon).points
    }
    func load() async {
        guard lexicon == nil else { return }
        if let data = try? Data(contentsOf: saveURL), let saved = try? JSONDecoder().decode(Game.self, from: data),
           saved.board.count == 225, saved.racks.count == 2, saved.scores.count == 2, (0...1).contains(saved.turn) {
            game = saved
        }
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "txt") else {
            message = "The dictionary is missing. Please reinstall the app."; return
        }
        let loaded = await Task.detached(priority: .userInitiated) {
            (try? String(contentsOf: url, encoding: .utf8)).map { Lexicon(text: $0) }
        }.value
        guard let loaded else { message = "Couldn’t load the dictionary."; return }
        lexicon = loaded; loading = false
        startComputer()
    }
    func save() {
        do { try JSONEncoder().encode(game).write(to: saveURL, options: .atomic) }
        catch { message = "The game could not be saved on this device." }
    }
    func reset() {
        generation = UUID(); worker?.cancel(); worker = nil
        computerPlaced = [:]
        highlightTask?.cancel(); computerHighlights = []
        thinking = false; placed = [:]; selected = nil; game = Game(); save()
    }
    func place(at cell: Int, blank: String? = nil) {
        guard game.turn == 0, !game.finished, !loading else { return }
        if let tile = placed.removeValue(forKey: cell) { selected = tile.id; return }
        guard game.board[cell] == nil, let selected,
              var tile = remainingRack.first(where: { $0.id == selected }) else { return }
        if tile.letter == "?" {
            guard let blank else { return }
            tile.shown = blank
        }
        placed[cell] = tile; self.selected = nil
    }
    var canPlace: Bool { game.turn == 0 && !game.finished && !loading && !thinking }
    func dropTile(_ id: UUID, at cell: Int) -> Bool {
        guard canPlace, game.board.indices.contains(cell), game.board[cell] == nil,
              placed[cell] == nil, let tile = game.racks[0].first(where: { $0.id == id }) else { return false }
        if let source = placed.first(where: { $0.value.id == id }) {
            placed[cell] = source.value
            placed.removeValue(forKey: source.key)
            selected = nil
        } else {
            guard tile.letter != "?" else { return false }
            selected = id
            place(at: cell)
        }
        return true
    }
    func returnToRack(_ id: UUID) -> Bool {
        guard canPlace, let source = placed.first(where: { $0.value.id == id }) else { return false }
        placed.removeValue(forKey: source.key)
        selected = id
        return true
    }
    func arrangeRack(_ id: UUID, at targetID: UUID) {
        guard canPlace,
              let source = game.racks[0].firstIndex(where: { $0.id == id }),
              let target = game.racks[0].firstIndex(where: { $0.id == targetID }) else { return }
        _ = returnToRack(id)
        let tile = game.racks[0].remove(at: source)
        game.racks[0].insert(tile, at: target)
        selected = id
        save()
    }
    private func highlightComputerMove(_ cells: Set<Int>) {
        highlightTask?.cancel()
        computerHighlights = cells
        highlightTask = Task {
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            computerHighlights = []
        }
    }
    func recall() { placed = [:]; selected = nil }
    func play() {
        guard game.turn == 0, let lexicon else { return }
        do {
            try game.play(placed, lexicon: lexicon)
            recall(); save(); startComputer()
        } catch { message = error.localizedDescription }
    }
    func pass() {
        guard game.turn == 0 else { return }
        recall(); game.pass(); save(); startComputer()
    }
    func exchange(_ ids: Set<UUID>) {
        guard game.turn == 0 else { return }
        do { try game.exchange(ids); recall(); save(); startComputer() }
        catch { message = error.localizedDescription }
    }
    func startComputer() {
        guard game.turn == 1, !game.finished, !thinking, let lexicon else { return }
        highlightTask?.cancel(); computerHighlights = []
        thinking = true
        let snapshot = game, token = generation
        let task = Task.detached(priority: .userInitiated) { Opponent.bestMove(game: snapshot, lexicon: lexicon) }
        worker = task
        Task {
            // Run the thinking pause alongside search, rather than adding to a slow search.
            async let pause: Void = Task.sleep(for: .seconds(2))
            let move = await task.value
            _ = try? await pause
            guard token == generation else { return }
            if let move {
                // Display a preview; commit the complete legal move only after the animation.
                for cell in move.tiles.keys.sorted() {
                    guard token == generation else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        computerPlaced[cell] = move.tiles[cell]
                    }
                    try? await Task.sleep(for: .milliseconds(450))
                }
                guard token == generation else { return }
                do {
                    try game.play(move.tiles, lexicon: lexicon)
                    highlightComputerMove(Set(move.tiles.keys))
                }
                catch { message = error.localizedDescription }
                computerPlaced = [:]
            }
            else if game.bag.count >= 7 { try? game.exchange(Set(game.racks[1].map(\.id))) }
            else { game.pass() }
            thinking = false; worker = nil; save()
        }
    }
}
