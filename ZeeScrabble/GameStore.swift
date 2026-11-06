import SwiftUI

@MainActor @Observable final class GameStore {
    var game = Game()
    var placed: [Int: Tile] = [:]
    var selected: UUID?
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
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt") else {
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
        thinking = true
        let snapshot = game, token = generation
        let task = Task.detached(priority: .userInitiated) { Opponent.bestMove(game: snapshot, lexicon: lexicon) }
        worker = task
        Task {
            let move = await task.value
            guard token == generation else { return }
            if let move { try? game.play(move.tiles, lexicon: lexicon) }
            else if game.bag.count >= 7 { try? game.exchange(Set(game.racks[1].map(\.id))) }
            else { game.pass() }
            thinking = false; worker = nil; save()
        }
    }
}
