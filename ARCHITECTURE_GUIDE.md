# FIFOCard 架构设计指南

> **本文档描述 FIFOCard 项目的目标架构。**
> 项目正从早期的"硬编码 + 上帝类"模式，向 **"Node 树状态机调度 + 数据驱动配置"** 架构演进。
> 新功能开发应遵循本指南；历史遗留代码应逐步按此指南重构。
>
> **相关文档：**
> - `docs/Refactoring_Plan.md` — 重构实施计划（分 6 个 Phase）
> - `docs/NodeStateMachine_Guide.md` — 状态机实现细节与代码示例
> - `AGENTS.md` — 项目概览与开发规范

---

## 目录

1. [核心原则](#一核心原则)
2. [目标架构总览](#二目标架构总览)
3. [模块划分与职责](#三模块划分与职责)
4. [Node 树状态机](#四node-树状态机)
5. [数据驱动设计](#五数据驱动设计)
6. [全局事件总线 EventBus](#六全局事件总线-eventbus)
7. [完整数据流](#七完整数据流)
8. [文件结构](#八文件结构)
9. [解耦技巧](#九解耦技巧)
10. [测试策略](#十测试策略)
11. [风险与回滚](#十一风险与回滚)
12. [架构检查清单](#十二架构检查清单)

---

## 一、核心原则

### 1.1 单一职责原则（SRP）

每个类/模块只做一件事，做好一件事。

```
❌ 错误：GameManager 什么都管
    - 管理游戏状态
    - 计算分数
    - 检测匹配
    - 播放音效
    - 保存存档

✅ 正确：职责分离
    GameManager      → 只持有游戏数据，提供业务接口
    StateMachine     → 只负责"什么时候切到下一个状态"
    MatchEngine      → 只负责匹配检测算法
    ScoreCalculator  → 只负责分数计算
    EventBus         → 只负责全局信号转发
```

### 1.2 依赖倒置原则

上层模块不依赖下层模块的具体实现，而依赖抽象/接口。

```
❌ 错误：GameManager 直接操作 Card 的显示
    GameManager -> Card.update_texture()

✅ 正确：GameManager 发信号，Card 自己响应
    GameManager.emit("card_played", card_data)
    Card._on_card_played(card_data)
```

### 1.3 开闭原则

对扩展开放，对修改关闭。

```
❌ 错误：写死的计分方式
    func calculate_score():
        return base_score * 2

✅ 正确：可配置的计分策略 + 数据驱动的关卡规则
    func calculate_score(rule: MatchRule):
        return rule.apply(base_score)

    # 新增关卡规则只需新建 .tres 文件，不改代码
```

### 1.4 改造后新增原则

| 原则 | 含义 |
|------|------|
| **状态只管流程** | State 节点只决定"什么时候做"、"下一步去哪" |
| **GameManager 只管数据** | 不持有状态变量，只提供业务接口（检测匹配、计算分数、操作牌堆） |
| **UI 只管表现** | HandCardQueue 不判断状态合法性，只响应 EventBus 事件 |
| **数据决定规则** | 关卡难度、道具属性、匹配规则全部外置到 `.tres` / `.json` |
| **信号驱动通信** | 层与层之间通过 EventBus 信号通信，禁止直接引用回调 |

---

## 二、目标架构总览

### 2.1 四层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         表现层 (View)                            │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────────────┐  │
│  │ HandCardQueue│ │ ActiveCard   │ │ Modals (Shop/Result)   │  │
│  │ 手牌队列渲染  │ │ 当前活动卡牌  │ │ 弹窗界面               │  │
│  └──────────────┘ └──────────────┘ └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↑↓ EventBus 事件通信（解耦）
┌─────────────────────────────────────────────────────────────────┐
│                       调度层 (Controller)                        │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                      StateMachine                         │ │
│  │  ┌─────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │  │Idle │ │Inserting│ │Matching │ │Playing  │ ...       │ │
│  │  └─────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  │     决定"什么时候做"、"下一步去哪"                       │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↑↓ 调用业务接口
┌─────────────────────────────────────────────────────────────────┐
│                        业务层 (Model)                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐   │
│  │ GameManager │ │ MatchEngine │ │ ScoreCalculator         │   │
│  │ 游戏数据持有者 │ │ 匹配检测算法  │ │ 分数计算 + 扑克牌型评估  │   │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↑↓ 读取配置
┌─────────────────────────────────────────────────────────────────┐
│                        数据层 (Data)                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐    │
│  │LevelConfig │ │MatchRule   │ │ItemDefinition│ │CardDef   │    │
│  │ 关卡配置    │ │ 匹配规则    │ │ 道具定义      │ │ 卡牌定义  │    │
│  │(.tres)     │ │(.tres)     │ │(.tres)       │ │(.tres)   │    │
│  └────────────┘ └────────────┘ └────────────┘ └───────────┘    │
│  ┌────────────┐ ┌────────────┐ ┌─────────────────────────────┐ │
│  │save_01.json│ │locale_zh.json│ │shop_inventory.json         │ │
│  │ 存档数据    │ │ 多语言文本   │ │ 商店配置（运行时只读→json） │ │
│  └────────────┘ └────────────┘ └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 各层职责

| 层级 | 职责 | 不应该做 |
|------|------|----------|
| **表现层** | 显示数据、播放动画、接收输入 | 修改游戏逻辑、直接操作数据、判断状态合法性 |
| **调度层** | 管理游戏对局流程、决定状态切换时机 | 执行具体业务算法、直接操作牌堆数据 |
| **业务层** | 游戏规则、匹配算法、计分、牌堆操作 | 直接操作显示、处理输入细节、管理状态切换 |
| **数据层** | 存储配置、提供数据访问 | 包含业务逻辑、知道如何显示 |

---

## 三、模块划分与职责

### 3.1 模块关系图

```
┌──────────────────────────────────────────────────────────────────┐
│                          scenes/Game.tscn                        │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ StateMachine │  │  GameManager │  │   CardManager        │   │
│  │  (调度层)     │  │  (业务层)    │  │   (业务层)           │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘   │
│         │                 │                     │               │
│         │ owns            │ 调用               │ 创建          │
│    ┌────┴────┐            │                    │               │
│    ▼         ▼            ▼                    ▼               │
│ ┌──────┐ ┌────────┐  ┌──────────┐      ┌──────────────┐      │
│ │ Setup│ │ Idle   │  │MatchEngine│      │   CardData   │      │
│ └──────┘ └────────┘  └──────────┘      └──────────────┘      │
│    ...                                                    ...  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ HandCardQueue│  │ ScoreDisplay │  │   ItemSlots          │   │
│  │  (表现层)     │  │  (表现层)    │  │   (表现层)           │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼ EventBus 全局信号
                    ┌────────────────────┐
                    │   EventBus (Autoload)│
                    └────────────────────┘
```

### 3.2 核心模块说明

#### StateMachine（调度层）

- **文件：** `src/state_machine/StateMachine.gd`、`src/state_machine/State.gd`
- **职责：** 收集所有子 State 节点，执行状态切换，发出 `state_changed` 信号
- **关键机制：** 利用 Godot Node 的 `set_process()` 开关实现物理隔离——只有当前状态的 `_process()` 会执行

#### GameManager（业务层）

- **文件：** `src/game_logic/GameManager.gd`
- **职责：** 持有游戏运行时数据，提供业务接口供 State 调用
- **不做的：** 不持有状态变量，不直接切换状态

```gdscript
# GameManager 的核心数据
var hand_cards: Array[CardData] = []     # 手牌队列（仅普通牌）
var active_card: CardData                # 当前激活牌
var item_slots: Array[CardData] = []     # 2个道具槽
var current_matches: Array[Array] = []   # 当前匹配结果
var current_score: int = 0
var gold: int = 4
var chain_count: int = 0

# 供 State 调用的业务接口
func insert_active_card_at(index: int) -> bool
func insert_white_card(slot_index: int, hand_index: int) -> bool
func insert_chameleon(slot_index: int, hand_index: int) -> bool
func find_matches() -> Array[Array]
func score_current_matches() -> void
func fill_empty_slots() -> void
func is_level_complete() -> bool
```

#### MatchEngine（业务层）

- **文件：** `src/game_logic/MatchEngine.gd`
- **职责：** 在手牌中找出所有匹配组（3+ 同花色连续）
- **特点：** 纯算法类，无状态，可独立测试

#### ScoreCalculator（业务层）

- **文件：** `src/game_logic/ScoreCalculator.gd`
- **职责：** 计算匹配分数（牌面总值 × 张数倍率 × 连锁倍率 + 扑克牌型奖励）

#### CardManager（业务层）

- **文件：** `src/cards/CardManager.gd`
- **职责：** 创建/管理两个独立牌堆（52 张普通牌 + 18 张道具牌）、洗牌、抽牌、回收道具牌

#### EventBus（全局 Autoload）

- **文件：** `src/autoload/EventBus.gd`
- **职责：** 全局信号中心，所有模块通过它通信，消除直接引用

#### 数据 Resource 类（数据层）

- **文件：** `src/data/LevelConfig.gd`、`src/data/MatchRule.gd`、`src/data/ItemDefinition.gd`
- **职责：** 定义可配置数据的结构，通过 `@export` 在 Godot 编辑器中可视化编辑
- **实例文件：** `data/levels/level_01.tres`、`data/rules/standard_rule.tres` 等

---

## 四、Node 树状态机

### 4.1 核心思想

把**每个状态做成一个 Node**，利用 Godot 引擎的 `set_process()` 机制：

- **当前状态** = `process(true)`，它的 `_process()` 在运行
- **其他状态** = `process(false)`，它们完全不执行
- **状态切换** = 调用当前状态的 `exit()` → 关闭 process → 调用新状态的 `enter()` → 开启 process

**优势：**

| 优势 | 说明 |
|------|------|
| 物理隔离 | 非活跃状态的代码绝对不会被执行，杜绝"抢跑" |
| 自包含 | 每个状态自己管理信号连接、动画监听、计时器 |
| 可视化 | 在 Godot 编辑器里状态是节点，一目了然 |
| 可扩展 | 新增状态 = 新增一个脚本 + 场景节点，不碰旧代码 |
| 父子关系 | 状态机可以嵌套（如 `PlayingState` 下再分子状态） |

### 4.2 状态节点树（Game.tscn 中）

```
Game (Control)
├── BackGround
├── StateMachine (Node)           ← 状态机管理器
│   ├── Setup (Node)              ← 关卡初始化（发牌、创建道具牌堆）
│   ├── Idle (Node)               ← 等待玩家操作
│   ├── Inserting (Node)          ← 插入动画
│   ├── Matching (Node)           ← 匹配检测
│   ├── Playing (Node)            ← 消除动画 + 计分
│   ├── Filling (Node)            ← 补牌 + 移位
│   ├── LevelEnd (Node)           ← 关卡结算
│   └── GameOver (Node)           ← 游戏结束
├── HandCardQueue (Control)
├── DrawPile (Control)
├── CardManager (Node)
└── GameManager (Node)            ← 改造后：专注数据逻辑
```

### 4.3 八个状态职责

| 状态 | 核心职责 | 进入时做什么 | 退出时做什么 |
|------|----------|-------------|-------------|
| **SetupState** | 关卡初始化 | 加载配置、创建牌堆、洗牌、发初始手牌、抽 active card、清空道具槽 | — |
| **IdleState** | 等待玩家 | 启用输入、高亮可放位置、连接玩家输入信号 | 断开信号、禁用输入 |
| **InsertingState** | 插入动画 | 调用 GameManager 执行插入、播动画 | 清理 |
| **MatchingState** | 检测匹配 | 调用 MatchEngine 检测 | 无 |
| **PlayingState** | 消除动画+计分 | 调用 ScoreCalculator、播消除动画 | 清理 |
| **FillingState** | 补牌移位 | 调用 GameManager 补牌、播补位动画 | 清理 |
| **LevelEndState** | 关卡结算 | 显示结算 UI、连接按钮信号 | 断开信号 |
| **GameOverState** | 游戏结束 | 显示结束 UI | 断开信号 |

### 4.4 状态流转图

```
游戏启动 / 进入下一关
    │
    ▼
┌─────────┐
│  Setup  │  ← 创建52张普通牌堆、创建18张道具牌堆、洗牌、
│ (初始化) │     发hand_size张初始手牌、抽1张active card、清空道具槽
└────┬────┘
     │ 发牌完成
     ▼
┌─────────────┐
│   Idle      │◄─────────────────────────────────────┐
│ (等待输入)   │                                      │
└──────┬──────┘                                      │
       │ 玩家选择牌（普通/白牌/变色龙）并点击 slot    │
       ▼                                              │
┌─────────────┐                                       │
│  Inserting  │                                       │
│ (插入动画)   │                                       │
└──────┬──────┘                                       │
       │ 判断插入牌类型                                │
       ├─ 白牌 ───────→ [直接生效] ───────→ [Idle]    │
       ├─ 变色龙 ─────→ [改变花色] ───────→ [Idle]    │
       └─ 普通牌 ─────→ [Matching]                    │
       │                                               │
       ▼                                               │
┌─────────────┐    无匹配+达成目标                    │
│  Matching   │──────────────────────────────┐       │
│ (匹配检测)   │                              │       │
└──────┬──────┘                              │       │
       │有匹配                                │       │
       │                                     │       │
       ▼                                     ▼       │
 ┌─────────┐                          ┌────────┐    │
 │ Playing │                          │LevelEnd│    │
 │(消除动画)│                          │(关卡结算)│   │
 └────┬────┘                          └────────┘    │
      │ 动画完成                                     │
      ▼                                              │
 ┌─────────┐                                         │
 │ Filling │                                         │
 │(补牌移位)│                                         │
 └────┬────┘                                         │
      │ 动画完成                                      │
      └─────── (回到 Matching 检测连锁)               │
                                                      │
      连锁结束，显示"确定并继续"                       │
      玩家点击后 → 结算分数、回收白牌 → [Idle]        │
                                                      │
         无匹配+死局                                  │
    ┌─────────────────────────────────────────────────┘
    ▼
┌─────────────┐
│  GameOver   │
│ (游戏结束)   │
└─────────────┘
```

### 4.5 连锁循环

```
[Matching] --有匹配--> [Playing] --动画完成--> [Filling] --动画完成--> [Matching]
                                                              ↑                          │
                                                              └──────────────────────────┘
                                                           （连锁循环）
```

连锁计数变化：
- `Setup → Idle`：chain_count = 0
- 每经过一次 `PlayingState`：chain_count += 1
- 回到 `Idle`（无匹配或本回合结束）：chain_count = 0

### 4.6 状态实现口诀

> **状态即节点，切换即开关。**
> **入态连信号，出态断干净。**
> **数据归管理，流转归状态。**
> **动画回调切，决策分支明。**

---

## 五、数据驱动设计

### 5.1 设计理念

所有"会变的东西"（数值、概率、规则参数）放在 `data/` 目录的 `.tres` 文件中；代码中只保留"不变的东西"（算法框架、状态流转规则）。

策划可以在 Godot 编辑器中双击 `.tres` 文件修改数值，无需改代码、无需重新编译。

### 5.2 核心数据类

#### LevelConfig（关卡配置）

```gdscript
class_name LevelConfig
extends Resource

@export var level_id: int = 1
@export var target_score: int = 1000
@export var hand_size: int = 15
@export var active_card_count: int = 1
@export var max_item_slots: int = 2

@export_group("奖励")
@export var reward_gold_base: int = 3
@export var reward_interest_divisor: int = 5

@export_group("规则覆盖")
@export var match_rule: MatchRule
@export var special_rules: Array[String] = []
```

#### MatchRule（匹配规则）

```gdscript
class_name MatchRule
extends Resource

@export var min_match_size: int = 3
@export var must_same_suit: bool = true
@export var must_consecutive: bool = false
@export var wildcard_types: Array[CardData.Type] = []
```

#### ItemDefinition（道具定义）

```gdscript
class_name ItemDefinition
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var cost: int
@export var max_stack: int = 1
@export var icon: Texture2D
@export var effect_type: String
@export var effect_params: Dictionary = {}
```

### 5.3 数据访问器

```gdscript
# src/data/LevelDatabase.gd
class_name LevelDatabase
extends RefCounted

const LEVEL_PATH = "res://data/levels/"

static func get_level(level_id: int) -> LevelConfig:
    var path = LEVEL_PATH + "level_%02d.tres" % level_id
    if ResourceLoader.exists(path):
        return load(path)
    return _generate_default(level_id)
```

### 5.4 运行时数据分离

```gdscript
# src/autoload/PlayerData.gd（玩家持久化数据）
class_name PlayerData
extends Node

@export var hand_size_bonus: int = 0   # 商店购买的手牌位加成
@export var gold: int = 4

func get_current_hand_size(base: int) -> int:
    return base + hand_size_bonus
```

---

## 六、全局事件总线 EventBus

### 6.1 设计目的

消除 UI 层与逻辑层的直接引用。UI 不直接调用 GameManager 的方法，只通过 EventBus 发信号；逻辑层也只通过 EventBus 通知 UI 更新。

### 6.2 信号定义

```gdscript
# src/autoload/EventBus.gd
extends Node

# ===== UI → 逻辑层 =====
signal card_slot_clicked(slot_index: int)
signal active_card_played()
signal item_used(item_slot: int, target_index: int)
signal shop_item_purchased(item_id: String)
signal next_level_requested()
signal restart_requested()
signal return_to_menu_requested()

# ===== 逻辑层 → UI =====
signal input_enabled_changed(enabled: bool)
signal highlight_slots(enabled: bool)
signal match_found(cards: Array[CardData], combo: int)
signal score_added(amount: int, total: int, combo: int)
signal cards_eliminated(cards: Array[CardData])
signal cards_drawn(cards: Array[CardData], target_slots: Array[int])
signal gap_filled(cards: Array[CardData], positions: Array[int])
signal chain_combo_triggered(combo_count: int)
signal level_started(level: int, target_score: int)
signal level_completed(score: int, reward: int)
signal game_over(final_score: int, level: int)
signal gold_changed(new_amount: int, delta: int)

# ===== 状态机 → 全局 =====
signal state_changed(new_state: String, old_state: String)
```

### 6.3 配置

在 `project.godot` 的 `[autoload]` 中注册：

```ini
EventBus="*res://src/autoload/EventBus.gd"
```

---

## 七、完整数据流

### 7.1 一次普通牌插入的完整流程

```
用户点击 slot 3
    │
    ▼
┌─────────────────┐
│   HandCardQueue │  捕获输入，通过 EventBus 转发
│   (表现层)       │  EventBus.card_slot_clicked.emit(3)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   IdleState     │  监听 card_slot_clicked，请求插入
│   (调度层)       │  game_manager.insert_active_card_at(3)
│                  │  success → go_to("Inserting")
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  InsertingState │  播放插入动画
│   (调度层)       │  动画完成 → go_to("Matching")
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  MatchingState  │  调用 MatchEngine 检测
│   (调度层)       │  matches.size() > 0 → go_to("Playing")
│                  │  matches.size() == 0 → _check_game_progress()
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PlayingState   │  1. GameManager.score_current_matches()
│   (调度层)       │  2. 播放消除动画
│                  │  动画完成 → go_to("Filling")
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  FillingState   │  1. GameManager.fill_empty_slots()
│   (调度层)       │  2. 播放补位动画
│                  │  动画完成 → go_to("Matching")（检测连锁）
└────────┬────────┘
         │
         ▼
      [循环直到 Matching 无匹配]
         │
         ▼
┌─────────────────┐
│   IdleState     │  连锁结束，等待玩家下一次操作
│   (调度层)       │  game_manager.reset_chain()
└─────────────────┘
```

### 7.2 白牌/变色龙的特殊流程

白牌和变色龙是**道具牌**，不消耗回合：

```
IdleState
    │ 玩家点击道具槽
    ▼
├─ 白牌 ──→ game_manager.insert_white_card() ──→ 直接 go_to("Idle")
│
└─ 变色龙 ─→ game_manager.insert_chameleon() ──→ 直接 go_to("Idle")
```

### 7.3 关键设计决策

1. **为什么 GameManager 不直接操作 CardUI？**
   - CardUI 是表现层，可能动态创建/销毁
   - 通过 EventBus 通信，GameManager 不需要知道 CardUI 是否存在

2. **为什么 MatchEngine 是独立的类？**
   - 匹配算法复杂，单独测试更方便
   - 可以复用（比如预览模式下检测潜在匹配）

3. **为什么 CardData 是 Resource 不是 Node？**
   - 数据应该与显示分离
   - Resource 可以序列化保存
   - 多个 CardUI 可以共享同一个 CardData

---

## 八、文件结构

### 8.1 改造后目标结构

```
FIFOCard_Godot/
├── project.godot
├── src/
│   ├── autoload/
│   │   ├── EventBus.gd              ← 全局事件总线
│   │   └── GameData.gd              ← 全局数据访问点（可选）
│   ├── data/                        ← 数据定义脚本
│   │   ├── LevelConfig.gd
│   │   ├── MatchRule.gd
│   │   ├── ItemDefinition.gd
│   │   ├── CardDefinition.gd
│   │   └── LevelDatabase.gd
│   ├── state_machine/               ← 状态机系统
│   │   ├── StateMachine.gd
│   │   ├── State.gd
│   │   └── states/
│   │       ├── SetupState.gd
│   │       ├── IdleState.gd
│   │       ├── InsertingState.gd
│   │       ├── MatchingState.gd
│   │       ├── PlayingState.gd
│   │       ├── FillingState.gd
│   │       ├── LevelEndState.gd
│   │       └── GameOverState.gd
│   ├── game_logic/                  ← 业务逻辑
│   │   ├── GameManager.gd           ← 改造后：专注数据+接口
│   │   ├── MatchEngine.gd           ← 匹配检测算法
│   │   ├── ScoreCalculator.gd       ← 分数计算
│   │   └── SaveManager.gd           ← 存档管理
│   ├── cards/                       ← 卡牌系统
│   │   ├── Card.gd                  ← 改造后：支持数据驱动纹理
│   │   ├── CardData.gd
│   │   └── CardManager.gd           ← 改造后：双牌堆管理
│   ├── ui/                          ← UI 表现层
│   │   ├── HandCardQueue.gd         ← 改造后：EventBus 通信
│   │   ├── ActiveCardArea.gd
│   │   ├── ScoreDisplay.gd
│   │   ├── GoldDisplay.gd
│   │   ├── ItemSlots.gd
│   │   ├── LevelInfo.gd
│   │   └── Modals/
│   │       ├── BaseModal.gd
│   │       ├── LevelEndModal.gd
│   │       ├── GameOverModal.gd
│   │       ├── ShopModal.gd
│   │       └── PauseModal.gd
│   └── effects/                     ← 视觉/音效效果（后续扩展）
├── data/                            ← 实际数据资源文件（.tres）
│   ├── levels/
│   │   ├── level_01.tres
│   │   └── level_02.tres
│   ├── rules/
│   │   └── standard_rule.tres
│   └── items/
│       ├── white_card.tres
│       └── chameleon.tres
├── locale/                          ← 多语言
│   └── zh_CN.json
├── saves/                           ← 运行时存档目录
├── scenes/                          ← Godot 场景文件
│   ├── Game.tscn                    ← 改造后：含 StateMachine 节点树
│   └── card.tscn
└── assets/                          ← 游戏资源
    ├── audio/
    ├── fonts/
    └── textures/
```

---

## 九、解耦技巧

### 9.1 事件总线（Event Bus）

当模块间需要通信但又不想直接依赖时，使用 EventBus：

```gdscript
# 任何模块都可以发送和接收
# 发送：EventBus.card_slot_clicked.emit(index)
# 接收：EventBus.card_slot_clicked.connect(_on_slot_clicked)
```

**适用场景：**
- 多个模块都需要知道某个事件
- 模块间关系复杂，直接引用会导致循环依赖

### 9.2 依赖注入（Dependency Injection）

```gdscript
# 方式1：通过 @export 在编辑器中配置
class_name GameManager
extends Node

@export var card_manager: CardManager
@export var state_machine: StateMachine

# 方式2：通过构造函数（适合代码创建）
func create_game_manager(deck_mgr: CardManager) -> GameManager:
    var gm = GameManager.new()
    gm.card_manager = deck_mgr
    return gm
```

**好处：**
- 易于测试：可以注入 Mock 对象
- 模块间松耦合
- 依赖关系清晰可见

### 9.3 策略模式（Strategy Pattern）

当有不同的算法实现时：

```gdscript
# 策略接口
class_name ScoreStrategy
extends RefCounted

func calculate(cards: Array[CardData]) -> int:
    push_error("Must implement calculate()")
    return 0

# 具体策略
class_name BasicScoreStrategy extends ScoreStrategy
class_name PokerScoreStrategy extends ScoreStrategy

# 使用
var current_strategy: ScoreStrategy
func calculate_score(cards: Array[CardData]) -> int:
    return current_strategy.calculate(cards)
```

### 9.4 观察者模式（Observer Pattern）

Godot 的 Signal 就是观察者模式的实现：

```gdscript
# 被观察者
class_name CardManager
extends Node

signal deck_shuffled
signal card_drawn(card_data)
signal deck_empty

# 观察者：UI 显示
func _ready():
    card_manager.card_drawn.connect(_on_card_drawn)

# 观察者：音效
func _ready():
    card_manager.card_drawn.connect(_on_card_drawn)
```

---

## 十、测试策略

### 10.1 单元测试（针对逻辑层）

```gdscript
# test_match_engine.gd
extends GutTest

func test_find_matches_basic():
    var hand = [
        create_card(Suit.SPADES, "2"),
        create_card(Suit.SPADES, "3"),
        create_card(Suit.SPADES, "4"),
        create_card(Suit.HEARTS, "5"),
    ]
    var rule = MatchRule.new()
    rule.min_match_size = 3
    
    var matches = MatchEngine.find_matches(hand, rule)
    assert_eq(matches.size(), 1)
    assert_eq(matches[0].size(), 3)
```

### 10.2 状态机测试

```gdscript
# test_state_machine.gd
extends GutTest

func test_idle_to_inserting():
    var sm = StateMachine.new()
    sm.change_state("Idle")
    assert_eq(sm.get_current_state_name(), "Idle")
    
    sm.change_state("Inserting")
    assert_eq(sm.get_current_state_name(), "Inserting")
```

### 10.3 集成测试（模块间交互）

```gdscript
# test_game_flow.gd
extends GutTest

func test_complete_turn():
    var game_manager = GameManager.new()
    var card_manager = MockCardManager.new()
    game_manager.card_manager = card_manager
    
    game_manager.start_level(1)
    var success = game_manager.insert_active_card_at(5)
    
    assert_true(success)
    assert_eq(game_manager.hand_cards.size(), 16)
```

---

## 十一、风险与回滚

### 11.1 主要风险

| 风险 | 概率 | 影响 | 应对策略 |
|------|------|------|----------|
| 状态机循环卡死 | 中 | 高 | 每个状态加超时保护；加 `F5` 强制重置快捷键 |
| 信号未断开导致内存泄漏 | 低 | 中 | 严格遵守 State 的 `exit()` 断开所有信号 |
| 数据文件丢失/损坏 | 低 | 中 | `.tres` 文件提交 Git；存档 JSON 加 version 字段做迁移兼容 |
| 改造周期过长影响开发 | 高 | 中 | **分阶段交付**，每阶段都是一个可运行版本 |
| 性能下降（信号 vs 直接调用） | 低 | 低 | EventBus 是单例，信号连接开销可忽略；关键路径可保留直接调用 |

### 11.2 回滚方案

- **每阶段独立 Git 提交**，保留 commit 历史
- 若某阶段出现问题，可 `git checkout` 回退到上一阶段
- 改造期间保留原始 `GameManager.gd.bak` 备份

---

## 十二、架构检查清单

设计每个模块时问自己：

- [ ] **单一职责**：这个类是否只做一件事？
- [ ] **依赖关系**：是否依赖了不该依赖的模块？
- [ ] **接口清晰**：对外提供的接口是否简单明确？
- [ ] **可测试性**：能否不依赖其他模块进行测试？
- [ ] **可扩展性**：新增功能是否需要修改现有代码？
- [ ] **信号通信**：模块间通信是否使用了信号/EventBus 而非直接调用？
- [ ] **数据流向**：数据是否单向流动（数据→逻辑→表现）？
- [ ] **状态隔离**：State 的 `enter()` 连信号、`exit()` 断信号是否成对？
- [ ] **数据驱动**：数值/规则是否外置到 `.tres` 文件？
- [ ] **GameManager 瘦身**：GameManager 行数是否控制在 200 行以内？

---

## 附录：推荐阅读

- 《游戏编程模式》（Game Programming Patterns）- Robert Nystrom
- 《重构：改善既有代码的设计》- Martin Fowler
- Godot 官方文档：最佳实践部分
