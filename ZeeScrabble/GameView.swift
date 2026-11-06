import SwiftUI

private enum Palette {
    static let background = Color(red: 0.08, green: 0.14, blue: 0.20)
    static let surface = Color(red: 0.13, green: 0.21, blue: 0.28)
    static let tile = Color(red: 0.98, green: 0.88, blue: 0.66)
    static let accent = Color(red: 0.95, green: 0.70, blue: 0.32)
}

struct GameView: View {
    @State private var store = GameStore()
    @State private var zoomed = false
    @State private var blankCell: Int?
    @State private var showingBlank = false
    @State private var showingExchange = false
    @State private var exchangeIDs = Set<UUID>()
    @State private var showingRules = false
    @State private var confirmingNew = false
    @State private var confirmingPass = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 18) {
                        scores
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(status).font(.headline)
                                Text("\(store.game.bag.count) tiles in bag · \(store.game.racks[1].count) on computer’s rack")
                                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            if store.thinking || store.loading { ProgressView().tint(Palette.accent) }
                            Button { zoomed.toggle() } label: { Image(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass") }
                                .accessibilityLabel(zoomed ? "Fit board" : "Enlarge board")
                        }
                        let cell = zoomed ? CGFloat(42) : max(18, (geometry.size.width - 32) / 15)
                        ScrollView([.horizontal, .vertical]) {
                            board(cell: cell)
                        }
                        .frame(height: min(cell * 15, geometry.size.height * 0.53))
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                        VStack(spacing: 12) {
                            HStack {
                                Text("YOUR RACK").font(.caption.weight(.bold)).tracking(2)
                                Spacer()
                                Button { store.game.racks[0].shuffle(); store.save() } label: { Image(systemName: "shuffle") }
                                    .accessibilityLabel("Shuffle your rack")
                            }
                            HStack(spacing: 6) {
                                ForEach(store.remainingRack) { tile in
                                    Button { store.selected = tile.id } label: {
                                        TileFace(tile: tile, selected: store.selected == tile.id)
                                            .frame(maxWidth: .infinity).frame(height: 48)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(tile.letter == "?" ? "Blank" : tile.letter), \(tile.value) points")
                                }
                            }
                            Text(store.placed.isEmpty ? "Tap a rack tile, then a board square." : "Tap a placed tile to return it to your rack.")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 12) {
                                Button("Recall") { store.recall() }.disabled(store.placed.isEmpty)
                                Spacer()
                                Button(store.preview.map { "Play · \($0) pts" } ?? "Play word") { store.play() }
                                    .buttonStyle(.borderedProminent).tint(Palette.accent).foregroundStyle(Palette.background)
                                    .disabled(store.placed.isEmpty)
                            }
                            HStack {
                                Button("Exchange") { store.recall(); exchangeIDs = []; showingExchange = true }
                                    .disabled(store.game.bag.count < 7)
                                Spacer()
                                Button("Pass") { confirmingPass = true }
                            }
                            .font(.subheadline)
                        }
                        .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                        .disabled(store.game.turn != 0 || store.game.finished || store.loading)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LAST MOVES").font(.caption.weight(.bold)).tracking(2)
                            if store.game.history.isEmpty { Text("Cover the center star to begin.").foregroundStyle(.secondary) }
                            ForEach(Array(store.game.history.prefix(12).enumerated()), id: \.offset) { _, text in
                                Text(text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                }
            }
            .background(Palette.background)
            .foregroundStyle(.white)
            .navigationTitle("ZeeScrabble")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showingRules = true } label: { Image(systemName: "questionmark.circle") } }
                ToolbarItem(placement: .topBarTrailing) { Button("New game") { confirmingNew = true } }
            }
            .task { await store.load() }
            .alert("Can’t play that move", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: { Text(store.message ?? "") }
            .confirmationDialog("Start a new game? This replaces the saved game.", isPresented: $confirmingNew, titleVisibility: .visible) {
                Button("New game", role: .destructive) { store.reset() }
            }
            .confirmationDialog("Pass your turn?", isPresented: $confirmingPass, titleVisibility: .visible) { Button("Pass") { store.pass() } }
            .sheet(isPresented: $showingBlank) { blankPicker }
            .sheet(isPresented: $showingExchange) { exchangePicker }
            .sheet(isPresented: $showingRules) { rules }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }
    private var status: String {
        if store.loading { return "Preparing the dictionary…" }
        if store.game.finished {
            return store.game.scores[0] == store.game.scores[1] ? "It’s a tie" : store.game.scores[0] > store.game.scores[1] ? "You win!" : "Computer wins"
        }
        return store.thinking ? "Computer is thinking…" : "Your move"
    }
    private var scores: some View {
        HStack(spacing: 12) {
            scoreCard("YOU", score: store.game.scores[0], active: store.game.turn == 0)
            scoreCard("COMPUTER", score: store.game.scores[1], active: store.game.turn == 1)
        }
    }
    private func scoreCard(_ title: String, score: Int, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.bold)).tracking(2)
            Text("\(score)").font(.system(size: 34, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(active ? Palette.surface : Palette.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(active ? Palette.accent : .clear, lineWidth: 1))
    }
    private func board(cell: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<15) { row in
                HStack(spacing: 0) {
                    ForEach(0..<15) { column in
                        let i = row*15+column
                        let tile = store.placed[i] ?? store.game.board[i]
                        Button {
                            if store.placed[i] == nil, store.game.board[i] == nil,
                               store.remainingRack.first(where: { $0.id == store.selected })?.letter == "?" {
                                blankCell = i; showingBlank = true
                            } else { store.place(at: i) }
                        } label: {
                            Group {
                                if let tile { TileFace(tile: tile, selected: store.placed[i] != nil) }
                                else {
                                    Text(Game.premium(i).label)
                                        .font(.system(size: cell > 30 ? 10 : 7, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(squareColor(i), in: RoundedRectangle(cornerRadius: 2))
                                }
                            }
                            .padding(1).frame(width: cell, height: cell)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.game.turn != 0 || store.game.finished || store.loading)
                        .accessibilityLabel("Row \(row+1), column \(column+1), \(tile?.shown ?? Game.premium(i).label)")
                    }
                }
            }
        }
    }
    private func squareColor(_ i: Int) -> Color {
        switch Game.premium(i).label {
        case "TW": Color(red: 0.65, green: 0.27, blue: 0.23)
        case "DW", "★": Color(red: 0.51, green: 0.34, blue: 0.39)
        case "TL": Color(red: 0.15, green: 0.39, blue: 0.56)
        case "DL": Color(red: 0.25, green: 0.47, blue: 0.51)
        default: Color(red: 0.24, green: 0.30, blue: 0.32)
        }
    }
    private var blankPicker: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), id: \.self) { letter in
                    Button(String(letter)) {
                        if let i = blankCell { store.place(at: i, blank: String(letter)) }
                        showingBlank = false
                    }.font(.title).frame(height: 44)
                }
            }.padding().navigationTitle("Choose blank letter")
                .toolbar { Button("Cancel") { showingBlank = false } }
        }.presentationDetents([.medium, .large])
    }
    private var exchangePicker: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose tiles to exchange. This uses your turn.")
                HStack {
                    ForEach(store.game.racks[0]) { tile in
                        Button {
                            if exchangeIDs.contains(tile.id) { exchangeIDs.remove(tile.id) } else { exchangeIDs.insert(tile.id) }
                        } label: { TileFace(tile: tile, selected: exchangeIDs.contains(tile.id)).frame(height: 48) }
                    }
                }
                Button("Exchange \(exchangeIDs.count) tiles") { store.exchange(exchangeIDs); showingExchange = false }
                    .buttonStyle(.borderedProminent).disabled(exchangeIDs.isEmpty)
            }.padding().navigationTitle("Exchange tiles")
                .toolbar { Button("Cancel") { showingExchange = false } }
        }.presentationDetents([.medium])
    }
    private var rules: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Classic board rules").font(.title2.bold())
                    Text("Play connected words in one row or column. The first word covers the center star. Every word formed must be valid. Tap a rack tile, then an empty square; tap a staged tile to recall it. Use the magnifier for larger squares.")
                    Text("DL / TL multiply a newly placed letter. DW / TW multiply its word. Bonuses apply only on the turn a tile is placed, including any cross words. Playing all seven tiles earns 50 extra points. Blanks score zero and keep their chosen letter.")
                    Text("Exchange selected tiles when at least seven remain in the bag, or pass. The game ends when a player empties their rack with an empty bag, or after six consecutive scoreless turns. Remaining rack values are deducted; the player who goes out receives the opponent’s remaining value.")
                    Text("The computer uses its own rack and the visible board. It searches for high-scoring legal moves for up to five seconds. Your completed turns save automatically.")
                    Text("Dictionary").font(.headline)
                    Text("Uses the public-domain dwyl English word list, not an official tournament dictionary. It contains uncommon words and may accept or reject words differently from official Scrabble editions. Invalid moves are rejected automatically; there is no challenge phase.")
                    Link("Word list and license", destination: URL(string: "https://github.com/dwyl/english-words")!)
                    Text("Independent personal prototype; not affiliated with or endorsed by the owners of the Scrabble brand.").font(.caption)
                }.padding()
            }.navigationTitle("How to play").toolbar { Button("Done") { showingRules = false } }
        }
    }
}

private struct TileFace: View {
    let tile: Tile
    let selected: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 4).fill(Palette.tile)
                Text(tile.shown == "?" ? "" : tile.shown)
                    .font(.system(size: min(27, geometry.size.height * 0.62), weight: .semibold, design: .serif))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("\(tile.value)").font(.system(size: max(6, min(10, geometry.size.height * 0.22)), weight: .medium)).padding(2)
            }
            .foregroundStyle(Palette.background)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.orange : Color.black.opacity(0.2), lineWidth: selected ? 3 : 1))
        }
    }
}
