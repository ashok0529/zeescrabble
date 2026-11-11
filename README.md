# ZeeWords

Native SwiftUI iPhone game against an offline computer opponent. Open `ZeeWords.xcodeproj`, select the ZeeWords scheme and an iPhone simulator, and Run. Device signing uses team X35PT5T5BN and bundle ID com.zeesrinivasan.zeewords; change the team for your own account.

Requires iOS/iPadOS 18 or later, or macOS Sequoia 15 or later on a Mac with Apple silicon.

## Playing
Wide windows use a larger square board with scores, rack, and controls below it. Scroll to reach the controls in shorter windows; smaller windows use the phone layout.

Drag rack tiles to reorder them, or drag a tile onto a highlighted board square. Unplayed tiles can be dragged back to the rack. You can also tap a rack tile, then an empty board square. Choose a letter when placing a blank. Tap a staged tile to return it, or Recall to return all. Play commits the turn after validating every word. Pinch to zoom and pan around the board, or use the magnifier. Recall zooms back out. Computer moves play one tile at a time in the full-board view, followed by a five-second purple highlight. Winning opens a celebration; other outcomes show final scores and a New Game option. Exchange requires at least seven tiles in the bag. Games save locally after each committed turn.

The engine implements the classic 15-by-15 board, English 100-tile distribution, seven-tile racks, connected straight-line moves, cross-word scoring, fresh-square premiums, 50-point seven-tile bonus, blank tiles, passing, exchanging, and endgame rack deductions. Six consecutive scoreless turns end a game. Invalid words are rejected automatically; there is no challenge phase.

The computer searches a trie using its own rack and the visible board, checking cross words and scoring legal candidates. It searches for up to five seconds and chooses its highest-scoring candidate; it is not guaranteed to find the globally best move. If no move is found it exchanges or passes.

## Dictionary
Tap the book icon in the existing toolbar to look up a word without changing the board layout. Results update as you type using the same bundled dictionary as move validation; lookup does not use a turn.

The bundled `ZeeWords/dictwithmeaning.txt` is copied from the supplied `dictwithmeaning.txt`. Lookup displays available meanings offline; missing meanings show a message and a link to scrabble.merriam.com. The original game dictionary still determines word validity.

The user-supplied `dictionary.txt` is copied unchanged into `ZeeWords/dictionary.txt` and bundled with the app. It contains 178,691 unique ASCII words of 2–15 letters. Both move validation and the computer use this single dictionary, with no fallback to the previous word list. Its source and edition have not been independently verified. Existing saved boards are preserved; start a new game to clear words played with the previous dictionary.

## Verification
Run from the project root:

```sh
xcrun swiftc -g ZeeWords/GameEngine.swift Tests/EngineChecks.swift -o /tmp/ZeeWords-engine-checks
/tmp/ZeeWords-engine-checks
```

Checks cover premiums, cross words, blanks, illegal placements, bingo, endgame deductions, passing, exchange, save roundtrips, legal AI turns, and tile conservation. UI interaction and device behavior still benefit from hands-on testing.
