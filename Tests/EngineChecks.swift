import Foundation

@main struct EngineChecks {
    static func main() throws {
        let lex = Lexicon(text: "CAT CATS AT CA ACT TACT TAC SAT AS TO DOG DOGS ATE TEA EAT RAT TAR ART STAR STARS RATE RATES TARE EAR ARE ERA SEA SEAT EAST EATS TEAS TEST TESTS SET SETS IT IS IN ON NO NOT TONE NOTE STONE ONES ONE AN ANT TAN TEN NET TIN SIT ITS SITS TIE TIES TOE TOES OAT OATS SO SOT SODA DO GO GOD GODS GOOD OO AA AE AI OE OI ES ET EN ER RE TA TI OS OR OD DE ED AD DA AB BA BE BO BI")
        var game = Game()
        precondition(game.bag.count == 86 && game.racks.allSatisfy { $0.count == 7 })
        let total = game.bag + game.racks.flatMap { $0 }
        precondition(total.count == 100 && total.filter { $0.letter == "?" }.count == 2)
        game.racks[0] = [Tile("C",3),Tile("A",1),Tile("T",1)]
        let tiles = game.racks[0]
        let move = [112:tiles[0],113:tiles[1],114:tiles[2]]
        precondition(tryScore(game, move, lex) == 10)
        try game.play(move, lexicon: lex)
        precondition(game.scores[0] == 10 && game.turn == 1)
        game.racks[1] = [Tile("S",1)]
        precondition(tryScore(game,[115:game.racks[1][0]],lex) == 6) // center premium not reused
        var blankGame = Game()
        var blank = Tile("?",0); blank.shown = "C"
        blankGame.racks[0] = [blank,Tile("A",1),Tile("T",1)]
        precondition(tryScore(blankGame,[112:blank,113:blankGame.racks[0][1],114:blankGame.racks[0][2]],lex) == 4)
        reject(blankGame,[0:blank,1:blankGame.racks[0][1]],lex)
        reject(blankGame,[112:blank,114:blankGame.racks[0][1]],lex)
        reject(blankGame,[112:blank,128:blankGame.racks[0][1]],lex)
        reject(blankGame,[112:blank,113:blank],lex)
        game.racks[1] = [Tile("A",1),Tile("T",1)]
        precondition(tryScore(game,[127:game.racks[1][0],128:game.racks[1][1]],lex) == 10)
        reject(game,[0:game.racks[1][0],1:game.racks[1][1]],lex)
        var bingo = Game()
        bingo.racks[0] = Array("READING").map { Tile(String($0), $0 == "D" || $0 == "G" ? 2 : 1) }
        let bingoLex = Lexicon(text:"READING")
        let bingoMove = Dictionary(uniqueKeysWithValues: bingo.racks[0].enumerated().map { (112+$0.offset,$0.element) })
        precondition(tryScore(bingo,bingoMove,bingoLex) == 70) // DL at 116, DW center, +50
        var end = Game(); end.bag = []; end.racks = [[Tile("C",3),Tile("A",1),Tile("T",1)],[Tile("Q",10)]]
        try end.play(Dictionary(uniqueKeysWithValues: end.racks[0].enumerated().map { (112+$0.offset,$0.element) }), lexicon: lex)
        precondition(end.finished && end.scores == [20,-10])
        var passed = Game(); for _ in 0..<6 { passed.pass() }; precondition(passed.finished)
        var exchange = Game(); let ids = Set(exchange.racks[0].prefix(3).map(\.id)); try exchange.exchange(ids)
        precondition(exchange.bag.count == 86 && exchange.racks[0].count == 7 && exchange.turn == 1)
        let encoded = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(Game.self,from:encoded)
        precondition(decoded.board == game.board && decoded.racks == game.racks)
        game.racks[1] = [Tile("S",1),Tile("A",1),Tile("T",1),Tile("E",1),Tile("R",1),Tile("N",1),Tile("O",1)]
        guard let computer = Opponent.bestMove(game:game,lexicon:lex,seconds:2) else { fatalError("Computer found no move") }
        precondition(tryScore(game,computer.tiles,lex) == computer.points)
        let full = Lexicon(text: try String(contentsOfFile:"ZeeWords/dictionary.txt",encoding:.utf8))
        precondition(full.contains("CAT") && !full.contains("DEBEIGE"), "Bundled dictionary regression")
        var match = Game()
        for _ in 0..<12 {
            if match.finished { break }
            if let move = Opponent.bestMove(game:match,lexicon:full,seconds:0.5) { try match.play(move.tiles,lexicon:full) }
            else { match.pass() }
            let all = match.bag + match.racks.flatMap { $0 } + match.board.compactMap { $0 }
            precondition(all.count == 100 && Set(all.map(\.id)).count == 100)
        }
        print("PASS: opening, premiums, cross words, blanks, invalid placements, bingo, endgame, passes, exchange, persistence, computer legality, tile conservation")
    }
    static func tryScore(_ game:Game,_ move:[Int:Tile],_ lex:Lexicon) -> Int { try! game.evaluate(move,lexicon:lex).points }
    static func reject(_ game:Game,_ move:[Int:Tile],_ lex:Lexicon) {
        do { _ = try game.evaluate(move,lexicon:lex); fatalError("Invalid move accepted") } catch {}
    }
}
