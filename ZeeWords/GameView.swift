import SwiftUI

private enum Palette {
    static let background = Color(red: 0.08, green: 0.14, blue: 0.20)
    static let surface = Color(red: 0.13, green: 0.21, blue: 0.28)
    static let tile = Color(red: 0.98, green: 0.88, blue: 0.66)
    static let accent = Color(red: 0.95, green: 0.70, blue: 0.32)
}

struct GameView: View {
    @State private var store = GameStore()
    @State private var zoomScale: CGFloat = 1
    private var zoomed: Bool { zoomScale > 1.01 }
    @State private var boardCoordinates = BoardCoordinates()
    @State private var focusedCell = 112
    @State private var focusRevision = 0
    private struct TileDrag {
        let id: UUID
        let point: CGPoint
    }
    @GestureState private var dragSession: TileDrag?
    private var draggedID: UUID? { dragSession?.id }
    private var dragPoint: CGPoint { dragSession?.point ?? .zero }
    private var targetedCell: Int? {
        guard let dragSession else { return nil }
        return boardTarget(at: dragSession.point)
    }
    @State private var boardFrame = CGRect.zero
    @State private var rackRowFrame = CGRect.zero
    @State private var rackSlotFrames: [UUID: CGRect] = [:]
    @State private var rackFrame = CGRect.zero
    @State private var blankCell: Int?
    @State private var showingBlank = false
    @State private var showingExchange = false
    @State private var exchangeIDs = Set<UUID>()
    @State private var showingRules = false
    @State private var showingWordLookup = false
    @State private var confirmingNew = false
    @State private var confirmingPass = false
    @State private var showingVictory = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width >= 900 {
                    wideLayout(size: geometry.size)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            breakfastHeader(width: min(geometry.size.width - 32, 600))
                            scores
                            boardHeader
                            boardViewport(size: CGSize(width: min(geometry.size.width, 632), height: geometry.size.height))
                            if store.game.finished { gameResult } else { rackPanel }
                            moveHistory
                        }
                        .frame(maxWidth: 600)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Palette.background)
            .foregroundStyle(.white)
            .navigationTitle("ZeeWords")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showingRules = true } label: { Image(systemName: "questionmark.circle") }
                    Button { showingWordLookup = true } label: { Image(systemName: "book.fill") }
                        .accessibilityLabel("Look up a word and meaning")
                        .disabled(store.lexicon == nil)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("New game") { confirmingNew = true } }
            }
            .task { await store.load() }
            .alert("Can’t play that move", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: { Text(store.message ?? "") }
            .confirmationDialog("Start a new game? This replaces the saved game.", isPresented: $confirmingNew, titleVisibility: .visible) {
                Button("New game", role: .destructive) { newGame() }
            }
            .confirmationDialog("Pass your turn?", isPresented: $confirmingPass, titleVisibility: .visible) { Button("Pass") { store.pass() } }
            .sheet(isPresented: $showingBlank) { blankPicker }
            .sheet(isPresented: $showingExchange) { exchangePicker }
            .sheet(isPresented: $showingRules) { rules }
            .sheet(isPresented: $showingWordLookup) {
                if let lexicon = store.lexicon { WordLookupView(lexicon: lexicon, meanings: store.meanings) }
            }
            .onChange(of: store.game.finished) { _, finished in
                if finished && !store.loading && store.game.scores[0] > store.game.scores[1] {
                    showingVictory = true
                }
            }
            .fullScreenCover(isPresented: $showingVictory) {
                VictoryView(playerScore: store.game.scores[0], computerScore: store.game.scores[1],
                            playAgain: { showingVictory = false; newGame() },
                            viewBoard: { showingVictory = false })
            }
        }
        .overlay {
            GeometryReader { proxy in
                if let id = draggedID, let tile = store.placed.values.first(where: { $0.id == id }) ?? store.game.racks[0].first(where: { $0.id == id }) {
                    TileFace(tile: tile, selected: true)
                        .frame(width: 48, height: 48)
                        .position(x: dragPoint.x - proxy.frame(in: .global).minX,
                                  y: dragPoint.y - proxy.frame(in: .global).minY)
                        .shadow(radius: 8)
                }
            }.allowsHitTesting(false)
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }
    private func wideLayout(size: CGSize) -> some View {
        // On a laptop, use the horizontal space for a large board and a compact control column
        // so scores, rack, and Play remain visible without vertical scrolling.
        let side = min(size.width - 420, 900)
        let contentWidth = side + 380
        return ScrollView {
            VStack(spacing: 16) {
                breakfastHeader(width: contentWidth, height: 72)
                HStack(alignment: .top, spacing: 24) {
                    boardViewport(size: CGSize(width: side + 32, height: side), square: true)
                        .frame(width: side)
                    VStack(spacing: 18) {
                        scores
                        boardHeader
                        if store.game.finished { gameResult } else { rackPanel }
                        moveHistory
                    }
                    .frame(width: 356)
                }
            }
            .frame(width: contentWidth)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }

    private var moveHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAST MOVES").font(.caption.weight(.bold)).tracking(2)
            if store.game.history.isEmpty { Text("Cover the center star to begin.").foregroundStyle(.secondary) }
            ForEach(Array(store.game.history.prefix(12).enumerated()), id: \.offset) { _, text in
                Text(text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func newGame() {
        store.reset()
        zoomOut()
    }
    private var gameResult: some View {
        VStack(spacing: 12) {
            Text(status).font(.title2.bold())
            Text("Final score: You \(store.game.scores[0]) · Computer \(store.game.scores[1])")
            Button("New game") { newGame() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func breakfastHeader(width: CGFloat, height: CGFloat? = nil) -> some View {
        let bannerHeight = height ?? width * 0.108
        return Image("BreakfastHeader")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: bannerHeight, alignment: .top)
            .clipped()
            .overlay {
                Text("ZEEWORDS")
                    .font(.system(size: min(width * 0.043, bannerHeight * 0.4), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: width * 0.36, height: height == nil ? bannerHeight * 0.72 : bannerHeight)
                    .background(Palette.background, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.accent, lineWidth: 1))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("ZeeWords")
    }
    private func boardViewport(size: CGSize, square: Bool = false) -> some View {
        let side = max(270, size.width - 32)
        return ZoomBoard(side: side, scale: zoomScale, focus: focusedCell,
                         revision: focusRevision, enabled: !store.thinking,
                         coordinates: boardCoordinates, onZoomEnd: { zoomScale = $0 }) {
            board(cell: side / 15).frame(width: side, height: side)
        }
        .frame(height: square ? side : min(size.width - 32, size.height * 0.53))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { boardFrame = $0 }
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.9), lineWidth: 2).allowsHitTesting(false))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: store.placed) { old, new in
            if let cell = new.keys.sorted().first(where: { old[$0]?.id != new[$0]?.id }) { focus(on: cell) }
        }
        .onChange(of: store.thinking) { _, thinking in if thinking { zoomOut() } }
    }
    private var rackPanel: some View {
                        VStack(spacing: 12) {
                            HStack {
                                Text("YOUR RACK").font(.caption.weight(.bold)).tracking(2)
                                Spacer()
                                Button { store.game.racks[0].shuffle(); store.save() } label: { Image(systemName: "shuffle") }
                                    .accessibilityLabel("Shuffle your rack")
                            }
                            HStack(spacing: 6) {
                                ForEach(store.game.racks[0]) { tile in
                                    Button { store.selected = tile.id } label: {
                                        TileFace(tile: tile, selected: store.selected == tile.id)
                                            .frame(maxWidth: .infinity).frame(height: 48)
                                    }
                                    .buttonStyle(.plain)
                                    .highPriorityGesture(tileGesture(tile.id))
                                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rackSlotFrames[tile.id] = $0 }
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(rackDropTarget == tile.id ? Color.cyan : .clear, lineWidth: 3).allowsHitTesting(false))
                                    .opacity(store.placed.values.contains(where: { $0.id == tile.id }) ? 0 : 1)
                                    .allowsHitTesting(!store.placed.values.contains(where: { $0.id == tile.id }))
                                    .accessibilityHidden(store.placed.values.contains(where: { $0.id == tile.id }))
                                    .accessibilityLabel("\(tile.letter == "?" ? "Blank" : tile.letter), \(tile.value) points")
                                }
                            }
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rackRowFrame = $0 }
                            Text(store.placed.isEmpty ? "Drag to arrange your rack or place tiles on the board." : "Tap a placed tile to return it to your rack.")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 12) {
                                Button("Recall") { store.recall(); zoomOut() }.disabled(store.placed.isEmpty)
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
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rackFrame = $0 }
                        .allowsHitTesting(store.canPlace)
    }
    private var boardHeader: some View {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(status).font(.headline)
                                Text("\(store.game.bag.count) tiles in bag · \(store.game.racks[1].count) on computer’s rack")
                                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            if store.thinking || store.loading { ProgressView().tint(Palette.accent) }
                            Button { zoomScale = zoomed ? 1 : 2; focusRevision += 1 } label: { Image(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass") }
                                .accessibilityLabel(zoomed ? "Fit board" : "Enlarge board")
                                .disabled(store.thinking)
                        }
    }
    private func focus(on cell: Int) {
        focusedCell = cell
        zoomScale = max(zoomScale, 2)
        focusRevision += 1
    }
    private func zoomOut() {
        zoomScale = 1
        focusedCell = 112
        focusRevision += 1
    }
    private func boardTarget(at point: CGPoint) -> Int? {
        guard store.canPlace, !rackFrame.contains(point), boardFrame.contains(point) else { return nil }
        guard let cell = boardCoordinates.cell(at: point), store.game.board[cell] == nil, store.placed[cell] == nil else { return nil }
        return cell
    }
    private func rackTarget(at point: CGPoint) -> UUID? {
        guard rackRowFrame.insetBy(dx: -8, dy: -12).contains(point) else { return nil }
        return store.game.racks[0].compactMap { tile -> (UUID, CGFloat)? in
            guard let frame = rackSlotFrames[tile.id] else { return nil }
            return (tile.id, abs(frame.midX - point.x))
        }.min(by: { $0.1 < $1.1 })?.0
    }
    private var rackDropTarget: UUID? {
        guard let dragSession else { return nil }
        return rackTarget(at: dragSession.point)
    }
    private func tileGesture(_ id: UUID?) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragSession) { value, state, _ in
                guard store.canPlace, !boardCoordinates.isPinching, let id else { return }
                state = TileDrag(id: id, point: value.location)
            }
            .onEnded { value in
                guard store.canPlace, !boardCoordinates.isPinching, let id else { return }
                if let target = rackTarget(at: value.location) {
                    withAnimation(.easeInOut(duration: 0.18)) { store.arrangeRack(id, at: target) }
                } else if rackFrame.contains(value.location) {
                    _ = store.returnToRack(id)
                } else if let cell = boardTarget(at: value.location) {
                    guard store.game.board[cell] == nil, store.placed[cell] == nil else { return }
                    if store.remainingRack.first(where: { $0.id == id })?.letter == "?" {
                        store.selected = id
                        blankCell = cell; showingBlank = true
                    } else { _ = store.dropTile(id, at: cell) }
                }
            }
    }
    private var status: String {
        if store.loading { return "Preparing the dictionary…" }
        if store.game.finished {
            return store.game.scores[0] == store.game.scores[1] ? "It’s a tie" : store.game.scores[0] > store.game.scores[1] ? "You win!" : "Computer wins"
        }
        if !store.computerPlaced.isEmpty { return "Computer is placing tiles…" }
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
                        let tile = store.placed[i] ?? store.computerPlaced[i] ?? store.game.board[i]
                        Button {
                            guard store.canPlace else { return }
                            if store.placed[i] == nil, store.game.board[i] == nil,
                               store.remainingRack.first(where: { $0.id == store.selected })?.letter == "?" {
                                blankCell = i; showingBlank = true
                            } else { store.place(at: i) }
                        } label: {
                            Group {
                                if let tile {
                                    TileFace(tile: tile, selected: store.placed[i] != nil || store.computerPlaced[i] != nil)
                                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                                }
                                else {
                                    Text(Game.premium(i).label)
                                        .font(.system(size: cell > 30 ? 13 : 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(Game.premium(i).label == "DL" ? Color(red: 0.19, green: 0.34, blue: 0.43) : Game.premium(i).label == "★" ? Color(red: 0.65, green: 0.16, blue: 0.21) : .white)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(
                                            squareColor(i),
                                            in: RoundedRectangle(cornerRadius: 3))
                                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(
                                            LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                                }
                            }
                            .padding(1).frame(width: cell, height: cell)
                        }
                        .buttonStyle(.plain)
                        .highPriorityGesture(tileGesture(store.placed[i]?.id), including: store.placed[i] == nil ? .subviews : .all)
                        .id(i)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(targetedCell == i ? Color.cyan.opacity(0.35) : .clear)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(
                                    targetedCell == i ? Color.cyan : store.computerHighlights.contains(i) ? Color.purple : .clear, lineWidth: 3))
                                .allowsHitTesting(false)
                        }
                        .allowsHitTesting(store.canPlace)
                        .accessibilityLabel("Row \(row+1), column \(column+1), \(tile?.shown ?? Game.premium(i).label)")
                    }
                }
            }
        }
    }
    private func squareColor(_ i: Int) -> Color {
        switch Game.premium(i).label {
        case "TW": Color(red: 0.77, green: 0.12, blue: 0.20)
        case "DW": Color(red: 0.85, green: 0.36, blue: 0.08)
        case "★": Color(red: 1.0, green: 0.79, blue: 0.74)
        case "TL": Color(red: 0.40, green: 0.57, blue: 0.68)
        case "DL": Color(red: 0.87, green: 0.91, blue: 0.93)
        default: Color(red: 1.0, green: 0.96, blue: 0.87)
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
                    Text("Uses the bundled dictionary of 178,691 words for both players and the computer. Invalid moves are rejected automatically; there is no challenge phase.")
                }.padding()
            }.navigationTitle("How to play").toolbar { Button("Done") { showingRules = false } }
        }
    }
}

private struct WordLookupView: View {
    let lexicon: Lexicon
    let meanings: WordMeanings
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var word: String { query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var validInput: Bool {
        (2...15).contains(word.utf8.count) && word.utf8.allSatisfy { (65...90).contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter a word", text: $query)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { focused = false }
                        .accessibilityLabel("Word to look up")
                } footer: {
                    Text("Checks this game’s bundled dictionary. Use 2–15 letters, A–Z.")
                }
                if !word.isEmpty {
                    Section {
                        if !validInput {
                            Label("Enter one word of 2–15 letters, A–Z.", systemImage: "info.circle")
                        } else if lexicon.contains(word) {
                            Label("\(word) is in the game dictionary.", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            if let meaning = meanings.meaning(for: word) {
                                Text(meaning).textSelection(.enabled)
                            } else {
                                Text("Although this is a valid scrabble word, meaning not available. Please check scrabble.merriam.com")
                                Link("Look up \(word) on scrabble.merriam.com",
                                     destination: URL(string: "https://scrabble.merriam.com/finder/")!.appendingPathComponent(word.lowercased()))
                            }
                        } else {
                            Label("\(word) isn’t in the game dictionary.", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Word lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
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
