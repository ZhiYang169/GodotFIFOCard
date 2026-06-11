# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FIFOCard is a single-player card game built with Godot 4.4 (GL Compatibility renderer, 1920x1080). Core mechanic: insert an active card into a hand queue to form groups of 3+ consecutive same-suit cards, triggering chain combos.

**Note:** `AGENTS.md` is outdated — it describes planned architecture from early development. Trust the actual code and `ARCHITECTURE_GUIDE.md` over it.

## Build & Run

```bash
# Run project (editor)
godot --path .

# Run project (headless, for debug output)
godot --headless --path .
```

No build system, test framework, or CI pipeline exists. The project runs directly in Godot.

## Architecture: 4-Layer Model

```
View (UI)        → HandCardQueue, ActiveCardSlot, PlayingCard, Card
Controller       → StateMachine + 4 State nodes (SETUP, IDLE, MATCHING, PLAYING)
Model            → GameManager (data owner), CardManager (deck operations)
Data             → LevelConfig (.tres), CardData (Resource)
```

**Critical rule:** Layers communicate exclusively through `EventBus` signals (autoload at `src/autoload/EventBus.gd`). UI never calls GameManager directly; GameManager never touches UI nodes. The universal event payload is `CardEvent` (`src/autoload/CardEvent.gd`) — a RefCounted carrying `cards: Array[CardData]` plus positional indices.

## Node Tree State Machine

States are **Node children** of `StateMachine` in `Game.tscn`. Only the active state has `process(true)` — all others are physically disabled.

```
StateMachine (src/game_logic/StateMachine.gd)
├── SETUP     → deals cards, animates, then → IDLE
├── IDLE      → waits for player input, then → MATCHING
├── MATCHING  → runs suit-segment detection, then → PLAYING (if match) or stuck (if no match)
└── PLAYING   → emits get_playing_card event, but has NO transition out (BROKEN)
```

Base class: `States` (class_name in `src/game_logic/State.gd`). Pattern: `enter()` connects signals, `exit()` disconnects them. Call `go_to("STATE_NAME")` to transition.

## Key Files

| File | Role |
|------|------|
| `src/autoload/EventBus.gd` | All 15+ cross-layer signals (3 groups: UI→Logic, Logic→UI, intra-Logic) |
| `src/autoload/CardEvent.gd` | Typed event payload (cards + position metadata) |
| `src/game_logic/GameManager.gd` | Central game state — hand_cards, active_card, match detection (`_get_suit_segment()`) |
| `src/game_logic/StateMachine.gd` | Collects child State nodes, manages transitions, emits `state_changed` |
| `src/game_logic/State.gd` | Base state (class_name `States`), provides `go_to()`, lazy `game_manager` lookup |
| `src/cards/CardManager.gd` | 52-card poker deck creation, Fisher-Yates shuffle, draw/pop |
| `src/cards/Card.gd` | UI card with drag support, loads texture from `card_{suit}_{rank}.png` |
| `src/cards/CardData.gd` | Resource class: suit enum, rank, value calculation |
| `src/ui/HandCardQueue.gd` | Hand display, slot/gap creation, deal animation, drag-drop handling |
| `src/ui/ActiveCardSlot.gd` | Active card display with drag ghost via DragLayer |
| `src/data/LevelConfig.gd` | Resource: level_id, target_score, hand_size |
| `src/data/LevelDatabase.gd` | Static loader for `data/Levels/level_XX.tres` |

## Known Critical Issues

1. **State machine deadlock after PLAYING** — `PlayingCardState` emits `get_playing_card` but never calls `go_to()`. The machine stays in PLAYING forever. `MatchingState` also has no fallback when no match found.

2. **`GameManager.start_level()` draw loop bug (line ~40)** — Uses `for i in range(len(drawn_cards))` while `pop_front()` shrinks the array, causing early loop exit. Should be a `while` loop.

3. **HandCardQueue permanently disconnects signals** — `_disconnect_signals()` is called after initial deal, removing `card_drawned` and `level_started` listeners permanently. Mid-game draws will not be received.

4. **No scoring** — `ScoreCalculator` does not exist. GameManager has `current_score` field that is never updated.

5. **Only 4 of 8 planned states exist** — FILLING, LevelEnd, GameOver, and PopActiveCard are missing.

## Codebase Conventions

- **Naming:** PascalCase classes, snake_case variables/methods, `@export` for editor-configurable fields
- **EventBus signals:** All named in past tense — `card_drawned`, `card_droped`, `active_card_inserted`, `get_playing_card`
- **Dead code:** `src/game_logic/States/State.gd` is a duplicate of `src/game_logic/State.gd` (different class_name). Only `States` is used.
- **Typos in codebase** (match these for grep/compatibility):
  - `PalyingCardState.gd` (file), class is `PlayingCardState`
  - `card_droped` (dropped), `card_drawned` (drawn)
  - `_on_active_card_instered` (inserted) in IdleState
  - `scale_ration` (ratio), `containter` (container) in UI files
- **Lazy node lookup pattern:** States get `game_manager` via `get_node("/root/Game/GameManager")`, not via `@export`
- **UI positioning:** Slot/gap positions calculated as `start_pos + GAP_SIZE*(index) + SLOT_SIZE*index`, with centering math based on container width

## Reference Implementation

`html_prototype/` contains a complete JavaScript reference with the full game loop, match detection (DFS-based poker hand evaluation), scoring formulas, and shop system. Key files: `js/game.js`, `FIFOCardRule.md` (Chinese rules), `计分规则.md`, `经济系统.md`, `道具.md`.
