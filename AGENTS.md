# FIFOCard - AI Agent Guide

## Project Overview

FIFOCard is a single-player card game built with Godot 4.4. The game is based on a "FIFO queue + same-suit consecutive elimination" mechanic where players insert an active card into a hand queue to create groups of 3 or more consecutive cards of the same suit.

**Project Structure:**
- **Godot Version:** 4.4
- **Scripting Language:** GDScript
- **Renderer:** OpenGL Compatibility
- **Screen Resolution:** 1920x1080

## Game Concept (游戏简介)

FIFOCard is a solitaire-style card game with the following core mechanics:

1. **Hand Queue:** A configurable queue of cards (default 15 cards, range 9-20)
2. **Active Card:** One card that the player can insert into the hand queue
3. **Matching Rule:** When 3+ consecutive cards of the same suit align, they are played and scored
4. **Chain Combos:** After cards are played, new cards are drawn from the deck to fill gaps. If the gap closure creates new matches, chain combos are triggered

### Key Game Elements

- **Standard 52-card deck** (no jokers during gameplay)
- **White Cards (白牌):** Special item cards that don't form matches. They act as temporary wildcards that return to the deck after use
- **Chameleon Cards (变色龙):** Special item cards that change the suit of the card to their left
- **Item Slots:** Two slots for holding special item cards (white cards or chameleons)
- **Economy System:** Gold coins earned by clearing levels, used to buy items in the shop

### Game Flow

1. Draw "hand queue size + 1" cards from the deck
2. The rightmost card becomes the active card
3. Player inserts the active card (or an item card) into any position in the hand queue
4. If 3+ same-suit consecutive cards form, they are played
5. Draw cards to fill gaps, shift cards right to fill empty slots
6. Check for collision matches (when gap closure brings same-suit cards together)
7. Score calculation based on poker hand combinations and multipliers
8. Continue until level target score is reached (win) or no more valid moves exist (lose)

### Scoring System

The scoring formula is:
```
Score = ceil(Σ(card_values) × card_count_multiplier × collision_multiplier) + poker_hand_bonus
```

- **Card Values:** A=11, 2-10=face value, J/Q/K=10
- **Card Count Multiplier:** 1 + (card_count - 3) × 0.5
- **Collision Multiplier:** 2^collision_count
- **Poker Hands:** Pair, Two Pair, Three of a Kind, Straight, Flush, Full House, Four of a Kind, Straight Flush

### Level Progression

- **Level Target Score:** 1000 × level²
- **Initial Gold:** 4 coins
- **Level Clear Reward:** 3 coins + interest (floor(gold / 5))
- **Shop:** After each level, players can buy item cards (white cards or chameleon cards)

## Directory Structure

```
FIFOCard_Godot/
├── project.godot           # Godot project configuration
├── icon.svg                # Project icon
├── scenes/                 # Godot scene files (.tscn)
│   ├── Game.tscn          # Main game scene
│   └── card.tscn          # Card UI component scene
├── src/                    # GDScript source code
│   ├── autoload/          # Auto-loaded singletons (global scripts)
│   ├── cards/             # Card-related classes (Card, CardData, CardManager)
│   ├── effects/           # Visual/audio effects
│   ├── game_logic/        # Core game logic (GameManager, FIFOQueue)
│   ├── ui/                # UI components
│   │   ├── HandCardQueue.gd
│   │   └── Modals/        # Modal dialogs
│   └── ...
├── assets/                 # Game assets
│   ├── audio/             # Sound effects and music
│   ├── fonts/             # Custom fonts
│   └── textures/          # Card textures (52 cards + jokers + back)
│       ├── card_clubs_*.png
│       ├── card_diamonds_*.png
│       ├── card_hearts_*.png
│       ├── card_spades_*.png
│       ├── card_joker_*.png
│       ├── card_back.png
│       └── PokerBgd.png
└── html_prototype/        # HTML/JavaScript prototype for reference
    ├── index.html
    ├── css/style.css
    ├── js/game.js         # Full game implementation reference
    ├── FIFOCardRule.md    # Complete game rules (Chinese)
    ├── 计分规则.md         # Scoring rules
    ├── 经济系统.md         # Economy system
    └── 道具.md             # Item descriptions
```

## Key Configuration Files

### project.godot
Main Godot project configuration file containing:
- Project name: "FIFOCard"
- Main scene reference (run/main_scene)
- Display settings (1920x1080)
- Rendering method (GL Compatibility)

### .editorconfig
```
root = true
[*]
charset = utf-8
```

### .gitignore
```
.godot/
/android/
```

## Build and Run Commands

### Using Godot Editor
1. Open the project in Godot 4.4+ editor
2. Press F5 or click the Play button to run

### Using Command Line
```bash
# Run the project
godot --path .

# Export for Windows
godot --export-release "Windows Desktop" ./build/FIFOCard.exe

# Export for Web/HTML5
godot --export-release "Web" ./build/web/index.html
```

## Code Organization

### Scene Architecture
The game uses Godot's node-based scene system:

1. **Game.tscn** - Main scene containing:
   - Background (ColorRect)
   - DrawPile (Control)
   - HandCardQueue (Control with HBoxContainer for cards)

2. **card.tscn** - Reusable card component with:
   - Front face (TextureRect with card image)
   - Back face (TextureRect with card back)
   - Button for interaction

### Source Code Structure

**Note:** The project is in early development. Only one script exists:
- `src/ui/HandCardQueue.gd` - UI component for managing the hand queue display

Planned modules (directories exist but are empty):
- `src/autoload/` - Global game state, settings, audio manager
- `src/cards/` - Card class, card data structures, card manager
- `src/effects/` - Animations, particle effects, sound effects
- `src/game_logic/` - Core game rules, queue management, scoring
- `src/ui/Modals/` - Shop, game over, level clear dialogs

### GDScript Naming Conventions
Based on existing code:
- Class names use PascalCase with `class_name` (e.g., `HandCardQueue`)
- Variables use snake_case
- Exported variables use `@export` annotation
- Type hints are used (e.g., `var card_slots : Array[CardSlot] = []`)

## Development Guidelines

### Adding New Features

1. **Card System:**
   - Create `CardData` class for card properties (suit, rank, value)
   - Create `Card` scene/script for visual representation
   - Implement `CardManager` for deck operations (shuffle, draw)

2. **Game Logic:**
   - Implement match detection (3+ consecutive same-suit cards)
   - Handle chain combo logic (collision detection after gap fill)
   - Implement scoring with poker hand evaluation

3. **UI Components:**
   - Hand queue display with drag-and-drop support
   - Active card area
   - Item slots (2 slots)
   - Play area for displaying played cards
   - Score display, level info, gold display
   - Shop modal for buying items

4. **Economy System:**
   - Gold management
   - Shop interface
   - Item inventory (2 slots)

### Important Game Rules to Implement

Refer to `html_prototype/FIFOCardRule.md` for complete rules. Key points:

1. **White Card Rules:**
   - Never enter hand queue during normal draw
   - Go directly to item slot when drawn
   - Don't form matches with any suit
   - Return to deck after next regular card is played

2. **Chameleon Card Rules:**
   - Change the suit of the card to their left
   - Cannot be placed at position 0 (leftmost)
   - Return to item deck after use

3. **Match Detection:**
   - Only same-suit consecutive cards count
   - White cards break suit chains
   - Minimum 3 cards for a match

4. **Scoring:**
   - Cards played in a round are scored together
   - Poker hands provide bonus multipliers
   - Chain combos double the multiplier each time

## Reference Implementation

The `html_prototype/` directory contains a complete working implementation in JavaScript. Key reference files:

- `js/game.js` - Full game logic including:
  - Deck management and shuffling
  - Match detection algorithm
  - Chain combo processing
  - Poker hand evaluation (DFS algorithm for best combination)
  - Scoring calculation
  - Shop system
  - UI interactions

- `FIFOCardRule.md` - Complete game rules in Chinese

When implementing features in Godot, refer to the JavaScript implementation for the exact algorithms, especially:
- `getSuitSegment()` - Find consecutive same-suit card groups
- `checkAndResolveMatches()` - Handle matches and chain reactions
- `calculateBestPokerHand()` - Evaluate poker hands for scoring
- `generateCandidateHands()` - Generate all possible poker hands

## Asset Guidelines

- Card textures are PNG format, named `card_{suit}_{rank}.png`
- Suits: clubs (梅花), diamonds (方片), hearts (红桃), spades (黑桃)
- Ranks: A, 02-10, J, Q, K
- Additional: `card_joker_red.png`, `card_joker_black.png`, `card_back.png`
- Background: `PokerBgd.png`

## Testing Strategy

Currently no automated tests are set up. For manual testing:

1. Test match detection with various card arrangements
2. Test chain combo scenarios
3. Test edge cases (empty deck, all white cards, etc.)
4. Test scoring with different poker hands
5. Test shop purchasing with insufficient gold
6. Test item usage (white cards, chameleons)

## Future Development Notes

The following features are planned but not yet implemented:

1. Full GDScript implementation of game logic
2. Drag-and-drop card interaction
3. Animation system for card movements
4. Sound effects and music
5. Save/load game state
6. High score persistence
7. Mobile/touch support

When implementing, always refer to the HTML prototype for correct behavior.
