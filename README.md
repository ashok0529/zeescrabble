# ZeeScrabble

Native SwiftUI iPhone game against an offline computer opponent. Open `ZeeScrabble.xcodeproj`, select the ZeeScrabble scheme and an iPhone simulator, and Run. Device signing uses team X35PT5T5BN and bundle ID com.zeesrinivasan.zeescrabble; change the team for your own account.

## Playing
Tap a rack tile, then an empty board square. Choose a letter when placing a blank. Tap a staged tile to return it, or Recall to return all. Play commits the turn after validating every word. The magnifier enlarges the scrollable board. Exchange requires at least seven tiles in the bag. Games save locally after each committed turn.

The engine implements the classic 15-by-15 board, English 100-tile distribution, seven-tile racks, connected straight-line moves, cross-word scoring, fresh-square premiums, 50-point seven-tile bonus, blank tiles, passing, exchanging, and endgame rack deductions. Six consecutive scoreless turns end a game. Invalid words are rejected automatically; there is no challenge phase.

The computer searches a trie using its own rack and the visible board, checking cross words and scoring legal candidates. It searches for up to five seconds and chooses its highest-scoring candidate; it is not guaranteed to find the globally best move. If no move is found it exchanges or passes.

## Dictionary
Bundled words come from https://github.com/dwyl/english-words (`words_alpha.txt`), filtered at load time to ASCII words of 2–15 letters. The source's Unlicense is included as `ZeeScrabble/WordListLicense.txt`. This is a general English dictionary, **not an official Scrabble lexicon**; accepted words differ. This independent project is not an official or endorsed Scrabble product.

## Verification
Run from the project root:

```sh
xcrun swiftc -g ZeeScrabble/GameEngine.swift Tests/EngineChecks.swift -o /tmp/ZeeScrabble-engine-checks
/tmp/ZeeScrabble-engine-checks
```

Checks cover premiums, cross words, blanks, illegal placements, bingo, endgame deductions, passing, exchange, save roundtrips, legal AI turns, and tile conservation. UI interaction and device behavior still benefit from hands-on testing.
