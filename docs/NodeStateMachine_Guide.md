# FIFOCard 的 Node 树分层状态机实现指南

> 本文档详细讲解如何在 FIFOCard 项目中使用 **Godot Node 树分层状态机**来管理游戏对局流程。
> 
> 目标：将目前 `GameManager` 中零散的状态枚举，改造成**每个状态独立为一个 Node**，利用 Godot 引擎的 `process` 开关机制，实现清晰、可扩展、可调试的状态管理。

---

## 目录

1. [核心思想](#1-核心思想)
2. [架构总览](#2-架构总览)
3. [文件清单](#3-文件清单)
4. [基类实现](#4-基类实现)
5. [具体状态实现](#5-具体状态实现)
6. [状态流转详解](#6-状态流转详解)
7. [整合现有代码](#7-整合现有代码)
8. [场景节点配置](#8-场景节点配置)
9. [调试技巧](#9-调试技巧)

---

## 1. 核心思想

### 传统方式的问题

目前 `GameManager` 中的状态管理是这样的：

```gdscript
enum PlayState { IDLE, INSER_CARD, MATCH_CARD, PLAY_CARD, ... }
var play_new_state: PlayState = PlayState.IDLE
```

所有状态的进入/退出逻辑都塞在 `GameManager` 的一个大 `match` 里，随着功能增加会越来越臃肿。

### Node 树状态机的核心洞察

Godot 的每个 Node 都有 `set_process(enabled)` 和 `set_physics_process(enabled)`。如果我们把**每个状态做成一个 Node**，那么：

- **当前状态** = `process(true)`，它的 `_process()` 在运行
- **其他状态** = `process(false)`，它们完全不执行
- **状态切换** = 调用当前状态的 `exit()` → 关闭 process → 调用新状态的 `enter()` → 开启 process

**好处：**

| 优势 | 说明 |
|------|------|
| 物理隔离 | 非活跃状态的代码绝对不会被执行，杜绝"抢跑" |
| 自包含 | 每个状态自己管理信号连接、动画监听、计时器 |
| 可视化 | 在 Godot 编辑器里状态是节点，一目了然 |
| 可扩展 | 新增状态 = 新增一个脚本 + 场景节点，不碰旧代码 |
| 父子关系 | 状态机可以嵌套（比如 `PlayingState` 下再分 `AnimatingIn` / `AnimatingOut`） |

---

## 2. 架构总览

### 节点树结构（Game.tscn 中）

```
Game (Control)
├── BackGround
├── StateMachine (Node)           ← 新增：状态机管理器
│   ├── Setup (Node)              ← 关卡初始化（发牌、创建道具牌堆）
│   ├── Idle (Node)               ← 等待玩家操作
│   ├── Inserting (Node)          ← 插入动画
│   ├── Matching (Node)           ← 匹配检测
│   ├── Playing (Node)            ← 消除动画+计分
│   ├── Filling (Node)            ← 补牌+移位
│   ├── LevelEnd (Node)           ← 关卡结算
│   └── GameOver (Node)           ← 游戏结束
├── HandCardQueue
├── DrawPile
├── CardManager (Node)            ← 保留：牌堆管理（创建、洗牌、抽牌）
└── GameManager (Node)            ← 改造：不再直接管状态，专注数据逻辑
```

### 类关系图

```
┌─────────────────┐         ┌─────────────────┐
│   StateMachine  │◄────────│   GameManager   │
│   (管理器)       │         │   (数据+业务)    │
└────────┬────────┘         └─────────────────┘
         │ owns
         ▼
    ┌─────────┐
    │  State  │◄────────── 基类（抽象）
    └────┬────┘
         │ extends
    ┌────┴────┬────────┬─────────┬────────┬──────────┬─────────┐
    ▼         ▼        ▼         ▼        ▼          ▼         ▼
┌───────┐ ┌────────┐ ┌────────┐ ┌───────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ Setup │ │ Idle   │ │Inserting│ │Matching│ │Playing │ │Filling │ │LevelEnd│ │GameOver│
└───────┘ └────────┘ └────────┘ └───────┘ └────────┘ └────────┘ └────────┘
```

### 职责划分

| 组件 | 职责 |
|------|------|
| **StateMachine** | 维护 `current_state`，执行切换，通知 GameManager |
| **State（基类）** | 定义 `enter()` / `exit()` / `_process()` 模板 |
| **具体 State** | 实现该状态下的业务逻辑（监听信号、请求切换） |
| **GameManager** | 持有游戏数据（hand_cards, score, deck），提供业务接口（检测匹配、计算分数、操作牌堆），**不直接管理状态切换** |
| **HandCardQueue** | UI 层，只发玩家输入事件，**不判断状态是否合法** |

---

## 3. 文件清单

需要在项目中创建以下文件：

| 文件路径 | 说明 |
|---------|------|
| `src/game_logic/state_machine/StateMachine.gd` | 状态机管理器基类 |
| `src/game_logic/state_machine/State.gd` | 状态基类 |
| `src/game_logic/state_machine/states/SetupState.gd` | 关卡初始化状态 |
| `src/game_logic/state_machine/states/IdleState.gd` | 等待输入状态 |
| `src/game_logic/state_machine/states/InsertingState.gd` | 插入动画状态 |
| `src/game_logic/state_machine/states/MatchingState.gd` | 匹配检测状态 |
| `src/game_logic/state_machine/states/PlayingState.gd` | 消除播放状态 |
| `src/game_logic/state_machine/states/FillingState.gd` | 补牌填充状态 |
| `src/game_logic/state_machine/states/LevelEndState.gd` | 关卡结算状态 |
| `src/game_logic/state_machine/states/GameOverState.gd` | 游戏结束状态 |

---

## 4. 基类实现

### 4.1 StateMachine.gd（管理器）

```gdscript
# src/game_logic/state_machine/StateMachine.gd
class_name StateMachine
extends Node

## 状态发生变化时发出（新状态名，旧状态名）
signal state_changed(new_state_name: String, old_state_name: String)

## 初始状态节点（在编辑器中指定）
@export var initial_state: Node

## 当前激活的状态
var current_state: State

## 状态名 → State 实例的映射
var _states: Dictionary = {}

func _ready() -> void:
    _collect_states()
    if initial_state:
        change_state(initial_state.name)

## 收集所有子节点中的 State
func _collect_states() -> void:
    for child in get_children():
        if child is State:
            _states[child.name] = child
            child.state_machine = self
            # 默认关闭所有状态的 process
            child.set_process(false)
            child.set_physics_process(false)
            
            # 连接状态内部的切换请求
            if not child.transition_requested.is_connected(_on_transition_requested):
                child.transition_requested.connect(_on_transition_requested)

## 切换状态（外部也可直接调用）
func change_state(state_name: String) -> void:
    if state_name == current_state.name if current_state else "":
        return
    
    var new_state = _states.get(state_name)
    if not new_state:
        push_error("StateMachine: 找不到状态 '%s'" % state_name)
        return
    
    var old_name = current_state.name if current_state else ""
    
    # 退出旧状态
    if current_state:
        current_state.exit()
        current_state.set_process(false)
        current_state.set_physics_process(false)
    
    # 进入新状态
    current_state = new_state
    current_state.set_process(true)
    current_state.set_physics_process(true)
    current_state.enter()
    
    state_changed.emit(state_name, old_name)
    print("[StateMachine] %s -> %s" % [old_name, state_name])

## 响应状态内部发出的切换请求
func _on_transition_requested(next_state_name: String) -> void:
    change_state(next_state_name)

## 获取当前状态名（方便调试）
func get_current_state_name() -> String:
    return current_state.name if current_state else ""
```

### 4.2 State.gd（状态基类）

```gdscript
# src/game_logic/state_machine/State.gd
class_name State
extends Node

## 状态内部请求切换到另一个状态
## 用法：在子类中 emit(transition_requested, "NextStateName")
signal transition_requested(next_state_name: String)

## 反向引用到状态机（由 StateMachine 自动设置）
var state_machine: StateMachine

## 便捷引用到 GameManager（因为 StateMachine 是 Game 的子节点）
var game_manager: GameManager:
    get:
        if not _game_manager:
            _game_manager = get_node_or_null("/root/Game/GameManager")
        return _game_manager
var _game_manager: GameManager

## 进入状态时调用（子类必须 super.enter()）
func enter() -> void:
    pass

## 退出状态时调用（子类必须 super.exit()）
func exit() -> void:
    pass

## 便捷方法：请求切换到指定状态
func go_to(state_name: String) -> void:
    transition_requested.emit(state_name)
```

---

## 5. 具体状态实现

### 5.1 SetupState —— 关卡初始化

```gdscript
# src/game_logic/state_machine/states/SetupState.gd
class_name SetupState
extends State

func enter() -> void:
    super.enter()
    
    # 1. 加载关卡配置
    var level_id = game_manager.current_level_id
    game_manager.start_level(level_id)
    
    # 2. 创建普通牌堆（52张）
    game_manager.card_manager.create_poker_deck()
    
    # 3. 创建道具牌堆（18张：10白牌 + 8变色龙），仅在第一关或道具牌耗尽时
    game_manager.card_manager.create_item_deck()
    
    # 4. 清空道具槽
    game_manager.item_slots.clear()
    game_manager.item_slots.resize(2)
    game_manager.item_slots.fill(null)
    
    # 5. 发初始手牌：抽 hand_size + 1 张普通牌
    var hand_size = game_manager.current_level.hand_size
    var total = game_manager.card_manager.draw_cards(hand_size + 1)
    
    # 6. 最右侧1张作为 active card，其余为手牌队列
    game_manager.active_card = total.pop_back()
    game_manager.hand_cards.append_array(total)
    
    # 7. 通知 UI
    EventBus.level_started.emit(level_id, game_manager.current_level.target_score)
    EventBus.cards_drawn.emit(game_manager.hand_cards)
    EventBus.active_card_changed.emit(game_manager.active_card)
    EventBus.item_slots_changed.emit(game_manager.item_slots)
    
    # 8. 等一帧让 UI 渲染，然后进入 Idle
    await get_tree().process_frame
    go_to("Idle")
```

**关键设计点：**

- SetupState 是**自动执行**的，不需要玩家输入
- 每关只执行一次，完成后进入 Idle 就不会再回来
- **道具牌和普通牌完全分离**：道具牌不混入普通牌堆，初始道具槽为空
- 开局发牌规则：抽 `hand_size + 1` 张普通牌，最右1张为 active card
- 如果普通牌堆不够发初始手牌，直接进入 `GameOver`

### 5.2 IdleState —— 等待玩家操作

```gdscript
# src/game_logic/state_machine/states/IdleState.gd
class_name IdleState
extends State

func enter() -> void:
    super.enter()
    
    # 启用 UI 输入
    _set_input_enabled(true)
    
    # 高亮可放置位置
    _highlight_slots(true)
    
    # 连接玩家输入信号
    EventBus.card_slot_clicked.connect(_on_slot_clicked)
    EventBus.item_slot_clicked.connect(_on_item_slot_clicked)

func exit() -> void:
    # 断开信号（重要！防止旧状态"幽灵监听"）
    EventBus.card_slot_clicked.disconnect(_on_slot_clicked)
    EventBus.item_slot_clicked.disconnect(_on_item_slot_clicked)
    
    _set_input_enabled(false)
    _highlight_slots(false)
    super.exit()

func _on_slot_clicked(slot_index: int) -> void:
    # 告诉 GameManager 执行数据层面的插入
    var success = game_manager.insert_active_card_at(slot_index)
    if success:
        # 插入成功，进入动画状态
        go_to("Inserting")

func _on_item_slot_clicked(item_slot: int, target_index: int) -> void:
    var item = game_manager.item_slots[item_slot]
    if not item:
        return
    
    match item.type:
        CardData.Type.WHITE:
            var success = game_manager.insert_white_card(item_slot, target_index)
            if success:
                # 白牌不消耗回合，直接回 Idle
                go_to("Idle")
        CardData.Type.CHAMELEON:
            var success = game_manager.insert_chameleon(item_slot, target_index)
            if success:
                # 变色龙不消耗回合，直接回 Idle
                go_to("Idle")

func _set_input_enabled(enabled: bool) -> void:
    var hand_queue = get_node_or_null("/root/Game/HandCardQueue")
    if hand_queue:
        hand_queue.set_interactive(enabled)

func _highlight_slots(active: bool) -> void:
    # 让 UI 显示/隐藏放置提示
    EventBus.highlight_slots.emit(active)
```

**关键设计点：**

- `enter()` 时连接信号，`exit()` 时断开信号 → **保证只有当前状态响应输入**
- 实际的数据操作（插入卡牌）交给 `GameManager`，状态只负责"何时切换"
- 白牌/变色龙插入后直接回 Idle，**不进入 Inserting/Matching**
- 如果插入失败（比如索引非法），`success == false`，状态不切换，玩家继续操作

### 5.3 InsertingState —— 插入动画

```gdscript
# src/game_logic/state_machine/states/InsertingState.gd
class_name InsertingState
extends State

func enter() -> void:
    super.enter()
    
    # 播放插入动画，动画完成后回调
    var hand_queue = get_node_or_null("/root/Game/HandCardQueue")
    if hand_queue:
        hand_queue.play_insert_animation(_on_animation_finished)
    else:
        # 如果没有动画系统，直接下一帧切换
        go_to("Matching")

func exit() -> void:
    super.exit()

func _on_animation_finished() -> void:
    go_to("Matching")
```

**关键设计点：**

- 这是一个**纯动画状态**，不处理任何数据
- 动画完成后自动进入 `Matching` 状态
- 如果以后要加"插入音效"、"屏幕震动"，直接加在这个状态的 `enter()` 里即可

### 5.4 MatchingState —— 匹配检测

```gdscript
# src/game_logic/state_machine/states/MatchingState.gd
class_name MatchingState
extends State

func enter() -> void:
    super.enter()
    
    # 让 GameManager 检测匹配
    var matches = game_manager.find_matches()
    
    if matches.size() > 0:
        # 有匹配，保存结果，进入播放状态
        game_manager.set_current_matches(matches)
        go_to("Playing")
    else:
        # 没有匹配，判断游戏是否继续
        _check_game_progress()

func exit() -> void:
    super.exit()

func _check_game_progress() -> void:
    # 检查是否达成关卡目标
    if game_manager.is_level_complete():
        go_to("LevelEnd")
        return
    
    # 检查是否死局（牌堆空且四种花色都<3）
    if game_manager.has_valid_moves():
        # 正常继续，回到等待输入
        game_manager.reset_chain()  # 连锁结束
        go_to("Idle")
    else:
        go_to("GameOver")
```

**关键设计点：**

- 这是**决策分支点**，决定游戏往哪个方向走
- `find_matches()` 是 GameManager 的核心算法，状态机不碰算法细节
- 如果进入 `Idle`，说明本轮连锁结束，重置连锁计数

### 5.5 PlayingState —— 消除动画 + 计分

```gdscript
# src/game_logic/state_machine/states/PlayingState.gd
class_name PlayingState
extends State

func enter() -> void:
    super.enter()
    
    # 1. 计分（数据操作交给 GameManager）
    game_manager.score_current_matches()
    
    # 2. 播放消除动画
    var hand_queue = get_node_or_null("/root/Game/HandCardQueue")
    if hand_queue:
        hand_queue.play_eliminate_animation(game_manager.get_current_matches(), _on_animation_finished)
    else:
        _on_animation_finished()

func exit() -> void:
    super.exit()

func _on_animation_finished() -> void:
    # 动画完成后，进入补牌状态
    go_to("Filling")
```

### 5.6 FillingState —— 补牌 + 移位

```gdscript
# src/game_logic/state_machine/states/FillingState.gd
class_name FillingState
extends State

func enter() -> void:
    super.enter()
    
    # 1. GameManager 执行数据层面的补牌（放到最左侧）
    game_manager.fill_empty_slots()
    
    # 2. 播放补位/移位动画
    var hand_queue = get_node_or_null("/root/Game/HandCardQueue")
    if hand_queue:
        hand_queue.play_fill_animation(_on_animation_finished)
    else:
        _on_animation_finished()

func exit() -> void:
    super.exit()

func _on_animation_finished() -> void:
    # 补完牌后，必须再回到 Matching 检测是否形成连锁
    go_to("Matching")
```

**关键设计点：**

- `Filling` → `Matching` 形成了**连锁反应循环**
- 连锁次数由 GameManager 维护，每经过一次 `PlayingState` +1

### 5.7 LevelEndState —— 关卡结算

```gdscript
# src/game_logic/state_machine/states/LevelEndState.gd
class_name LevelEndState
extends State

func enter() -> void:
    super.enter()
    
    # 计算奖励
    game_manager.award_level_rewards()
    
    # 显示结算界面
    EventBus.show_level_end.emit(
        game_manager.current_score,
        game_manager.target_score,
        game_manager.gold
    )
    
    # 等待玩家点击"下一关"或"商店"
    EventBus.next_level_requested.connect(_on_next_level)
    EventBus.shop_requested.connect(_on_shop)

func exit() -> void:
    EventBus.next_level_requested.disconnect(_on_next_level)
    EventBus.shop_requested.disconnect(_on_shop)
    EventBus.hide_level_end.emit()
    super.exit()

func _on_next_level() -> void:
    game_manager.start_next_level()
    go_to("Setup")  # 进入新关卡需要重新初始化

func _on_shop() -> void:
    # 打开商店 UI，不切换状态
    EventBus.show_shop.emit(game_manager.gold)
```

### 5.8 GameOverState —— 游戏结束

```gdscript
# src/game_logic/state_machine/states/GameOverState.gd
class_name GameOverState
extends State

func enter() -> void:
    super.enter()
    EventBus.show_game_over.emit(game_manager.current_score, game_manager.level)
    EventBus.restart_requested.connect(_on_restart)

func exit() -> void:
    EventBus.restart_requested.disconnect(_on_restart)
    EventBus.hide_game_over.emit()
    super.exit()

func _on_restart() -> void:
    game_manager.restart_game()
    go_to("Setup")
```

---

## 6. 状态流转详解

### 6.1 完整对局流程

```
游戏启动 / 进入下一关
    │
    ▼
[Setup] --发牌完成--> [Idle] --玩家选择牌（普通/白牌/变色龙）并点击 slot --> [Inserting]
                                                          │
                                                          │ 判断插入牌类型
                                                          ├─ 白牌 ───────→ [直接生效] ───────→ [Idle]
                                                          ├─ 变色龙 ─────→ [改变花色] ───────→ [Idle]
                                                          └─ 普通牌 ─────→ [Matching]
                                                          │
                                                          ▼
                                                   [Matching] --有匹配--> [Playing]
                                                          │
                                                          │ 无匹配
                                                          ▼
                                                   [Idle] / [LevelEnd] / [GameOver]
```

### 6.2 普通牌连锁循环

```
[Matching] --有匹配--> [Playing] --动画完成--> [Filling] --动画完成--> [Matching]
                                                              ↑                          │
                                                              └──────────────────────────┘
                                                           （连锁循环）
```

### 6.3 无匹配分支

```
[Matching] --无匹配+有可行操作--> [Idle]  （连锁结束，继续游戏）
[Matching] --无匹配+死局--------> [GameOver]
[Matching] --无匹配+达成目标----> [LevelEnd]

[LevelEnd] --玩家点击"下一关"--> [Setup]  （重新初始化新关卡）
[GameOver] --玩家点击"重试"----> [Setup]  （重新初始化当前关卡）
```

### 6.4 连锁计数的变化时机

```
chain_count = 0

Setup → Idle（chain_count = 0）
  → Inserting → Matching（检测到匹配，chain_count += 1 → 1）
  → Playing → Filling → Matching（再次检测到匹配，chain_count += 1 → 2）
  → Playing → Filling → Matching（无匹配）
  → Idle（chain_count = 0）
```

在 `GameManager` 中：

```gdscript
func score_current_matches() -> void:
    var base_score = _calculate_match_score(current_matches)
    var multiplier = pow(2, chain_count)  # 连锁翻倍
    total_score += ceil(base_score * multiplier)
```

---

## 7. 整合现有代码

### 7.1 改造 GameManager.gd

`GameManager` 不再直接持有状态变量，而是专注**数据 + 业务接口**。

```gdscript
# src/game_logic/GameManager.gd
class_name GameManager
extends Node

# ========== 子系统引用 ==========
@export var card_manager: CardManager
@export var state_machine: StateMachine  # 新增：在编辑器中关联

# ========== 游戏配置 ==========
@export var max_hand_cards: int = 15     # 默认15张，范围9~20

# ========== 游戏数据 ==========
var hand_cards: Array[CardData] = []       # 手牌队列（仅普通牌，不含白牌）
var active_card: CardData                  # 当前普通激活牌
var item_slots: Array[CardData] = []       # 2个道具槽
var current_matches: Array[Array] = []     # 当前匹配结果

var level: int = 1
var target_score: int = 1000
var current_score: int = 0
var gold: int = 4
var chain_count: int = 0
var is_item_played: bool = false           # 本回合是否已使用道具

# ========== 信号 ==========
signal card_drawn(cards: Array[CardData])
signal score_changed(new_total: int, added: int, combo: int)
signal matches_found(matches: Array[Array], combo: int)

func _ready() -> void:
    if state_machine:
        state_machine.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: String, old_state: String) -> void:
    print("[GameManager] 状态切换: %s -> %s" % [old_state, new_state])

# ========== 业务接口：供 State 调用 ==========

## 关卡初始化（由 SetupState 调用）
func start_level(level_id: int):
    level = level_id
    target_score = 1000 * level_id * level_id
    current_score = 0
    chain_count = 0
    hand_cards.clear()
    item_slots.clear()
    item_slots.resize(2)
    item_slots.fill(null)
    
    card_manager.create_poker_deck()
    card_manager.create_item_deck()

## 插入普通激活牌到指定位置
func insert_active_card_at(index: int) -> bool:
    if index < 0 or index > hand_cards.size():
        return false
    
    hand_cards.insert(index, active_card)
    is_item_played = false
    return true

## 插入白牌（道具，不消耗回合）
func insert_white_card(slot_index: int, hand_index: int) -> bool:
    if slot_index < 0 or slot_index >= item_slots.size():
        return false
    var white = item_slots[slot_index]
    if not white or white.type != CardData.Type.WHITE:
        return false
    
    hand_cards.insert(hand_index, white)
    item_slots[slot_index] = null
    EventBus.white_card_inserted.emit(hand_index)
    return true

## 插入变色龙（道具，不消耗回合）
func insert_chameleon(slot_index: int, hand_index: int) -> bool:
    if slot_index < 0 or slot_index >= item_slots.size():
        return false
    if hand_index <= 0:
        return false
    
    var chameleon = item_slots[slot_index]
    if not chameleon or chameleon.type != CardData.Type.CHAMELEON:
        return false
    
    var left_card = hand_cards[hand_index - 1]
    if left_card.type == CardData.Type.WHITE:
        return false
    
    left_card.suit = chameleon.suit
    item_slots[slot_index] = null
    card_manager.return_item_card(chameleon)
    EventBus.chameleon_used.emit(hand_index - 1, chameleon.suit)
    return true

## 检测匹配（核心算法，白牌阻断连续性）
func find_matches() -> Array[Array]:
    var matches: Array[Array] = []
    
    var i = 0
    while i < hand_cards.size():
        # 白牌不参与匹配，直接跳过
        if hand_cards[i].type == CardData.Type.WHITE:
            i += 1
            continue
        
        var segment = _get_suit_segment(i)
        if segment.size() >= 3:
            matches.append(segment)
            i += segment.size()
        else:
            i += 1
    
    return matches

func _get_suit_segment(start_index: int) -> Array[CardData]:
    if start_index >= hand_cards.size():
        return []
    
    var suit = hand_cards[start_index].suit
    var segment: Array[CardData] = []
    
    for i in range(start_index, hand_cards.size()):
        var card = hand_cards[i]
        # 白牌阻断连续性
        if card.type == CardData.Type.WHITE:
            break
        if card.suit == suit:
            segment.append(card)
        else:
            break
    
    return segment

## 设置/获取当前匹配结果
func set_current_matches(matches: Array[Array]) -> void:
    current_matches = matches

func get_current_matches() -> Array[Array]:
    return current_matches

## 计分
func score_current_matches() -> void:
    chain_count += 1
    
    var total_card_value = 0
    var total_cards = 0
    
    for group in current_matches:
        for card in group:
            total_card_value += card.get_value()
            total_cards += 1
    
    var count_multiplier = 1.0 + (total_cards - 3) * 0.5
    var chain_multiplier = pow(2, chain_count - 1)
    var added = ceil(total_card_value * count_multiplier * chain_multiplier)
    
    current_score += added
    score_changed.emit(current_score, added, chain_count)
    matches_found.emit(current_matches, chain_count)

## 填补空缺：移除已消除牌，从牌堆顶部抽牌放到最左侧
func fill_empty_slots() -> void:
    var cards_to_remove: Array[CardData] = []
    for group in current_matches:
        for card in group:
            cards_to_remove.append(card)
    
    for card in cards_to_remove:
        hand_cards.erase(card)
    
    # 从牌堆顶部抽取相同数量，放入最左侧
    var needed = cards_to_remove.size()
    if needed > 0:
        var drawn = card_manager.draw_cards(needed)
        for i in range(drawn.size()):
            hand_cards.insert(i, drawn[i])
    
    current_matches.clear()

## 回合结算：回收白牌、补充激活牌
func end_round() -> void:
    _recycle_white_cards()
    
    if not active_card and hand_cards.size() > 0:
        active_card = hand_cards.pop_back()
        EventBus.active_card_changed.emit(active_card)
    
    is_item_played = false

func _recycle_white_cards() -> void:
    var new_hand: Array[CardData] = []
    for card in hand_cards:
        if card.type == CardData.Type.WHITE:
            card_manager.return_item_card(card)
        else:
            new_hand.append(card)
    hand_cards = new_hand

## 检查关卡是否完成
func is_level_complete() -> bool:
    return current_score >= target_score

## 检查是否有可行操作
func has_valid_moves() -> bool:
    # 有普通激活牌，或道具槽有可用道具
    if active_card != null:
        return true
    for item in item_slots:
        if item != null:
            return true
    return false

## 重置连锁计数
func reset_chain() -> void:
    chain_count = 0

## 关卡奖励
func award_level_rewards() -> void:
    var interest = floor(gold / 5.0)
    gold += 3 + interest

## 下一关
func start_next_level() -> void:
    level += 1
    target_score = 1000 * level * level
    current_score = 0
    chain_count = 0
    hand_cards.clear()
    current_matches.clear()
    
    card_manager.create_poker_deck()

## 重新开始
func restart_game() -> void:
    level = 1
    target_score = 1000
    current_score = 0
    gold = 4
    chain_count = 0
    hand_cards.clear()
    current_matches.clear()
    
    card_manager.create_poker_deck()
```

### 7.2 EventBus（新增，可选但推荐）

为了让 State 和 UI 解耦，引入一个全局事件总线：

```gdscript
# src/autoload/EventBus.gd
extends Node

# UI -> State
signal card_slot_clicked(index: int)
signal item_slot_clicked(slot_index: int, target_index: int)
signal item_used(item_slot: int, target_index: int)
signal next_level_requested()
signal shop_requested()
signal restart_requested()

# State -> UI
signal highlight_slots(active: bool)
signal white_card_inserted(hand_index: int)
signal chameleon_used(target_index: int, new_suit: int)
signal white_cards_recycled(cards: Array[CardData])
signal active_card_changed(card: CardData)
signal item_slots_changed(slots: Array[CardData])
signal show_level_end(score: int, target: int, gold: int)
signal hide_level_end()
signal show_game_over(score: int, level: int)
signal hide_game_over()
signal show_shop(gold: int)
```

在 `project.godot` 的 `[autoload]` 中加入：

```ini
EventBus="*res://src/autoload/EventBus.gd"
```

### 7.3 HandCardQueue.gd 的适配

```gdscript
# src/ui/HandCardQueue.gd（修改部分）

func _ready():
    EventBus.level_started.connect(_on_level_started)
    EventBus.cards_drawn.connect(_on_cards_drawn)
    EventBus.highlight_slots.connect(_on_highlight_slots)

func set_interactive(enabled: bool) -> void:
    # 启用/禁用所有 slot 的输入
    for slot in slots:
        slot.set_process_input(enabled)

func play_insert_animation(callback: Callable) -> void:
    var tween = create_tween()
    # ... tween 设置 ...
    tween.finished.connect(callback)

func play_eliminate_animation(matches: Array[Array], callback: Callable) -> void:
    var tween = create_tween()
    # ... 播放消除动画 ...
    tween.finished.connect(callback)

func play_fill_animation(callback: Callable) -> void:
    var tween = create_tween()
    # ... 播放补位动画 ...
    tween.finished.connect(callback)

func _on_highlight_slots(active: bool) -> void:
    for slot in slots:
        slot.modulate = Color.YELLOW if active else Color.WHITE
```

---

## 8. 场景节点配置

### 8.1 创建 State 节点

1. 在编辑器中打开 `scenes/Game.tscn`
2. 在 `Game` 节点下新增一个 `Node`，命名为 `StateMachine`
3. 给 `StateMachine` 附加脚本 `res://src/game_logic/state_machine/StateMachine.gd`
4. 在 `StateMachine` 下创建 8 个子节点（都是普通 Node）：
   - `Setup`
   - `Idle`
   - `Inserting`
   - `Matching`
   - `Playing`
   - `Filling`
   - `LevelEnd`
   - `GameOver`
5. 分别给这 8 个节点附加对应的 State 脚本
6. 在 `StateMachine` 的 Inspector 中，设置 `Initial State` 为 `Setup`

### 8.2 修改 GameManager 节点

1. 选中 `GameManager` 节点
2. 在 Inspector 中，将 `State Machine` 属性指向 `../StateMachine`（相对路径）

### 8.3 最终的 Game.tscn 节点树

```
Game (Control)
├── GameManager (Node)
│   └── script: GameManager.gd
│   └── Card Manager = NodePath("../CardManager")
│   └── State Machine = NodePath("../StateMachine")    ← 新增
├── StateMachine (Node)                                  ← 新增
│   └── script: StateMachine.gd
│   └── Initial State = NodePath("Setup")
│   ├── Setup (Node)                                     ← 新增：关卡初始化
│   ├── Idle (Node)                                      ← 新增
│   │   └── script: IdleState.gd
│   ├── Inserting (Node)                                 ← 新增
│   │   └── script: InsertingState.gd
│   ├── Matching (Node)                                  ← 新增
│   │   └── script: MatchingState.gd
│   ├── Playing (Node)                                   ← 新增
│   │   └── script: PlayingState.gd
│   ├── Filling (Node)                                   ← 新增
│   │   └── script: FillingState.gd
│   ├── LevelEnd (Node)                                  ← 新增
│   │   └── script: LevelEndState.gd
│   └── GameOver (Node)                                  ← 新增
│       └── script: GameOverState.gd
├── HandCardQueue (Control)
├── DrawPile (Control)
└── CardManager (Node)
```

---

## 9. 调试技巧

### 9.1 实时查看当前状态

在 `StateMachine.gd` 的 `change_state()` 里已经有 `print` 了。运行时输出会是：

```
[StateMachine] -> Setup
[StateMachine] Setup -> Idle
[StateMachine] Idle -> Inserting
[StateMachine] Inserting -> Matching
[StateMachine] Matching -> Playing
[StateMachine] Playing -> Filling
[StateMachine] Filling -> Matching
[StateMachine] Matching -> Playing
...
```

### 9.2 状态历史追踪

```gdscript
# 在 StateMachine.gd 中添加
var state_history: Array[String] = []
const MAX_HISTORY = 20

func change_state(state_name: String) -> void:
    # ... 原有逻辑 ...
    state_history.append("%s -> %s" % [old_name, state_name])
    if state_history.size() > MAX_HISTORY:
        state_history.pop_front()
```

### 9.3 强制状态切换（作弊/调试）

```gdscript
# 按 F1 强制进入 LevelEnd
func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_F1:
                $StateMachine.change_state("LevelEnd")
            KEY_F2:
                $StateMachine.change_state("Idle")
```

### 9.4 状态计时

```gdscript
# 在 State.gd 中添加
var enter_time: float = 0.0

func enter() -> void:
    enter_time = Time.get_time_dict_from_system()["second"]
    # ...

func exit() -> void:
    var duration = Time.get_time_dict_from_system()["second"] - enter_time
    print("[%s] 持续了 %d 秒" % [name, duration])
    # ...
```

---

## 附录：完整流程示例

假设玩家在第 2 关，当前手牌有 15 张，active card 是红桃 5：

| 时间 | 状态 | 发生的事 |
|------|------|---------|
| T-1 | **Setup** | 加载 level_02 配置，创建52张普通牌堆，创建18张道具牌堆，洗牌，发16张普通牌（15手牌+1激活牌），道具槽清空 |
| T0 | **Setup** → Idle | 发牌动画完成，玩家看到高亮的可放置位置 |
| T1 | **Idle** → Inserting | 玩家点击 slot 3，红桃 5 插入 |
| T2 | **Inserting** | 播放插入动画，卡牌滑入位置 |
| T3 | **Inserting** → Matching | 动画完成，进入检测 |
| T4 | **Matching** | GameManager 发现 slot 2-4 形成红桃 3-4-5，有匹配！ |
| T5 | **Matching** → Playing | chain_count = 1 |
| T6 | **Playing** | 播放消除动画，计算得分，UI 飘出 "+150" |
| T7 | **Playing** → Filling | 动画完成 |
| T8 | **Filling** | 移除 3 张红桃，从牌堆顶部抽 3 张新牌放到最左侧，填空后右侧牌左移 |
| T9 | **Filling** → Matching | 补位动画完成，再次检测 |
| T10 | **Matching** | 新抽的牌让某处形成黑桃 J-Q-K！ |
| T11 | **Matching** → Playing | chain_count = 2，UI 显示 "Combo x2" |
| T12 | **Playing** | 播放消除，计算得分（x2 倍率） |
| T13 | **Playing** → Filling | |
| T14 | **Filling** → Matching | |
| T15 | **Matching** | 这次没有新匹配了 |
| T16 | **Matching** → Idle | 显示"确定并继续"，玩家点击后结算分数、回收白牌，chain_count 重置为 0，等待玩家下一次操作 |

---

## 总结

Node 树状态机的核心口诀：

> **状态即节点，切换即开关。**  
> **入态连信号，出态断干净。**  
> **数据归管理，流转归状态。**  
> **动画回调切，决策分支明。**

这样改造后，你的 `GameManager` 从"什么都管的大管家"变成了"只管数据的仓库"，而每个状态节点只关心"我在的时候该做什么"。代码会清晰很多，加新状态（比如 `ShopState`、`PauseState`）也完全不碰旧代码。
