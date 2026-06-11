# FIFOCard 状态机 + 数据驱动 重构规划文档

> **文档版本:** v1.0
> **目标:** 将现有项目从"代码硬编码"架构，改造为"Node树状态机调度 + 数据驱动配置"架构
> **预期工期:** 6 个阶段，可分阶段交付验证

---

## 目录

1. [项目现状诊断](#1-项目现状诊断)
2. [目标架构总览](#2-目标架构总览)
3. [改造核心原则](#3-改造核心原则)
4. [Phase 1: 基础设施搭建](#4-phase-1-基础设施搭建)
5. [Phase 2: 数据层建设](#5-phase-2-数据层建设)
6. [Phase 3: 状态机系统](#6-phase-3-状态机系统)
7. [Phase 4: 业务逻辑迁移](#7-phase-4-业务逻辑迁移)
8. [Phase 5: UI 系统适配](#8-phase-5-ui-系统适配)
9. [Phase 6: 关卡与存档](#9-phase-6-关卡与存档)
10. [文件结构对比](#10-文件结构对比)
11. [风险与回滚策略](#11-风险与回滚策略)
12. [验收标准](#12-验收标准)

---

## 1. 项目现状诊断

### 1.1 当前代码清单


| 文件                            | 职责                                 | 问题                                        |
| ------------------------------- | ------------------------------------ | ------------------------------------------- |
| `src/cards/CardData.gd`         | 卡牌数据定义（suit, rank, value）    | ✅ 基础良好，后续扩展 type 即可             |
| `src/cards/Card.gd`             | 卡牌 UI 表现（TextureRect + Button） | ⚠️ 硬编码纹理路径，需支持数据驱动纹理加载 |
| `src/cards/CardManager.gd`      | 牌组管理（创建52张、洗牌、抽牌）     | ⚠️ 白牌/道具牌逻辑未接入，规则硬编码      |
| `src/game_logic/GameManager.gd` | 游戏主控（状态枚举、发牌）           | ❌ 状态管理松散，大量逻辑将涌入此处         |
| `src/ui/HandCardQueue.gd`       | 手牌队列 UI                          | ⚠️ 直接持有 game_manager 引用，耦合度高   |
| `scenes/Game.tscn`              | 主场景                               | ⚠️ 缺少状态机节点树结构                   |
| `scenes/card.tscn`              | 卡牌组件                             | ✅ 基础良好                                 |

### 1.2 当前架构痛点

```
现状：GameManager 是"上帝类"
┌─────────────────────────────┐
│        GameManager          │
│  ├─ 状态枚举（PlayState）    │
│  ├─ 发牌逻辑                 │
│  ├─ 手牌数据 hand_cards[]   │
│  ├─ 分数计算（将要实现）      │
│  ├─ 匹配检测（将要实现）      │
│  ├─ 道具逻辑（将要实现）      │
│  └─ 关卡目标（将要实现）      │
└─────────────────────────────┘
         ↓ 所有逻辑塞这里
       越来越臃肿，越来越难以维护
```

### 1.3 核心缺失


| 缺失模块         | 影响                                 |
| ---------------- | ------------------------------------ |
| **全局事件总线** | UI 层和逻辑层直接引用，耦合严重      |
| **数据配置层**   | 关卡数值、道具属性全部要硬编码       |
| **状态机系统**   | 游戏流程用枚举+if-else管理，无法扩展 |
| **存档系统**     | 玩家进度无法保存                     |
| **多语言支持**   | 文本硬编码在代码或场景中             |

---

## 2. 目标架构总览

### 2.1 架构分层图

```
┌───────────────────────────────────────────────────────────────┐
│                        表现层 (View)                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │ HandCardQueue│ │ ActiveCard   │ │ Modals (Shop/Result) │  │
│  │ 手牌队列渲染  │ │ 当前活动卡牌  │ │ 弹窗界面             │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                              ↑↓ EventBus 事件通信（解耦）
┌───────────────────────────────────────────────────────────────┐
│                      调度层 (Controller)                       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    StateMachine                         │  │
│  │  ┌─────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │  │
│  │  │Idle │ │Inserting│ │Matching │ │Playing  │ ...     │  │
│  │  └─────┘ └─────────┘ └─────────┘ └─────────┘         │  │
│  │     决定"什么时候做"、"下一步去哪"                     │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                              ↑↓ 调用业务接口
┌───────────────────────────────────────────────────────────────┐
│                       业务层 (Model)                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │ GameManager │ │ MatchEngine │ │ ScoreCalculator         │ │
│  │ 游戏数据持有者 │ │ 匹配检测算法  │ │ 分数计算 + 扑克牌型评估  │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
                              ↑↓ 读取配置
┌───────────────────────────────────────────────────────────────┐
│                       数据层 (Data)                            │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │LevelConfig │ │MatchRule   │ │ItemDefinition│ │CardDef   │ │
│  │ 关卡配置    │ │ 匹配规则    │ │ 道具定义      │ │ 卡牌定义  │ │
│  │(.tres)     │ │(.tres)     │ │(.tres)       │ │(.tres)   │ │
│  └────────────┘ └────────────┘ └────────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌───────────────────────────┐ │
│  │save_01.json│ │locale_zh.json│ │shop_inventory.json        │ │
│  │ 存档数据    │ │ 多语言文本   │ │ 商店配置（运行时只读→json）│ │
│  └────────────┘ └────────────┘ └───────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### 2.2 改造后核心原则


| 原则                     | 含义                                                           |
| ------------------------ | -------------------------------------------------------------- |
| **状态只管流程**         | State 节点只决定"什么时候切到下一个状态"                       |
| **GameManager 只管数据** | 不持有状态变量，只提供业务接口（检测匹配、计算分数、操作牌堆） |
| **UI 只管表现**          | HandCardQueue 不判断状态合法性，只响应 EventBus 事件           |
| **数据决定规则**         | 关卡难度、道具属性、匹配规则全部外置到 .tres / .json           |
| **信号驱动通信**         | 层与层之间通过 EventBus 信号通信，禁止直接引用回调             |

---

## 3. 改造核心原则

### 3.1 不破坏现有功能

- 每一阶段改造后，游戏仍能运行（最小可运行版本）
- 保留现有 `CardData`、`Card`、`CardManager` 的核心逻辑
- 逐步替换，不一次性推翻重写

### 3.2 先搭框架，再填内容

- Phase 1-3 搭建"空的状态机 + 空的数据层"，能跑通流程
- Phase 4-6 逐步把具体业务逻辑（匹配算法、计分、道具）填入

### 3.3 数据与逻辑分离

- 所有"会变的东西"（数值、概率、规则参数）必须放在 `data/` 目录
- 代码中只保留"不变的东西"（算法框架、状态流转规则）

---

## 4. Phase 1: 基础设施搭建

**目标:** 建立全局事件通信 + 目录结构 + 数据基类框架
**工期:** 1 天
**交付物:** 项目能编译运行，EventBus 信号能通

### 4.1 目录结构创建

```
FIFOCard_Godot/
├── src/
│   ├── autoload/
│   │   ├── EventBus.gd              ← 新建：全局事件总线
│   │   └── GameData.gd              ← 新建：全局数据访问点（可选）
│   ├── data/                        ← 新建：数据定义脚本
│   │   ├── LevelConfig.gd
│   │   ├── MatchRule.gd
│   │   ├── ItemDefinition.gd
│   │   └── CardDefinition.gd
│   ├── state_machine/               ← 新建：状态机系统
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
│   ├── game_logic/
│   │   ├── GameManager.gd           ← 改造
│   │   ├── MatchEngine.gd           ← 新建：匹配检测算法
│   │   └── ScoreCalculator.gd       ← 新建：分数计算
│   ├── cards/                       ← 基本保留
│   ├── ui/                          ← 后续改造
│   └── effects/                     ← 后续填充
├── data/                            ← 新建：实际数据资源文件
│   ├── levels/
│   │   └── level_01.tres
│   ├── rules/
│   │   └── standard_rule.tres
│   └── items/
│       ├── white_card.tres
│       └── chameleon.tres
├── saves/                           ← 新建：运行时存档目录
└── locale/                          ← 新建：多语言目录
    └── zh_CN.json
```

### 4.2 新建文件清单


| 文件                         | 职责                                   |
| ---------------------------- | -------------------------------------- |
| `src/autoload/EventBus.gd`   | 全局信号中心，所有模块通过它通信       |
| `src/data/LevelConfig.gd`    | 关卡配置 Resource 基类                 |
| `src/data/MatchRule.gd`      | 匹配规则 Resource 基类                 |
| `src/data/ItemDefinition.gd` | 道具定义 Resource 基类                 |
| `src/data/CardDefinition.gd` | 卡牌定义 Resource 基类（扩展特殊卡牌） |

### 4.3 EventBus 信号设计

```gdscript
# src/autoload/EventBus.gd
extends Node

# ===== UI → 逻辑层 =====
signal card_slot_clicked(slot_index: int)
signal active_card_played()                    # 点击打出 active card
signal item_used(item_slot: int, target_index: int)
signal shop_item_purchased(item_id: String)
signal next_level_requested()
signal restart_requested()
signal return_to_menu_requested()

# ===== 逻辑层 → UI =====
signal input_enabled_changed(enabled: bool)    # 全局输入开关
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

### 4.4 project.godot 配置修改

```ini
[autoload]
EventBus="*res://src/autoload/EventBus.gd"
```

### 4.5 验收标准

- [ ]  `EventBus` 已注册为 autoload
- [ ]  任意两个模块能通过 EventBus 收发信号
- [ ]  目录结构创建完毕

---

## 5. Phase 2: 数据层建设

**目标:** 把"会变的东西"全部抽成 Resource 配置
**工期:** 1-2 天
**交付物:** 策划可以在 Godot 编辑器里双击 .tres 改数值，不改代码

### 5.1 数据基类实现

#### LevelConfig.gd

```gdscript
class_name LevelConfig
extends Resource

@export var level_id: int = 1
@export var target_score: int = 1000
@export var hand_size: int = 15       # 默认15张，范围9~20
@export var active_card_count: int = 1
@export var max_item_slots: int = 2

@export_group("奖励")
@export var reward_gold_base: int = 3
@export var reward_interest_divisor: int = 5

@export_group("规则覆盖")
@export var match_rule: MatchRule          # 引用匹配规则
@export var special_rules: Array[String] = []  # 如 ["no_hearts", "double_score"]
```

#### MatchRule.gd

```gdscript
class_name MatchRule
extends Resource

@export var min_match_size: int = 3
@export var must_same_suit: bool = true
@export var must_consecutive: bool = false   # FIFOCard 目前是同花色连续
@export var wildcard_types: Array[CardData.Type] = []
@export var chain_multiplier_formula: String = "pow(2, chain_count)"
@export var count_multiplier_formula: String = "1.0 + (card_count - 3) * 0.5"
```

#### ItemDefinition.gd

```gdscript
class_name ItemDefinition
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var cost: int
@export var max_stack: int = 1
@export var icon: Texture2D
@export var effect_type: String         # "change_suit", "destroy", "wild"
@export var effect_params: Dictionary = {}
```

### 5.2 创建示例数据文件


| 文件                            | 内容                                      |
| ------------------------------- | ----------------------------------------- |
| `data/levels/level_01.tres`     | 第1关：目标1000分，手牌10张，标准规则     |
| `data/levels/level_02.tres`     | 第2关：目标4000分，手牌12张，5%白牌概率   |
| `data/rules/standard_rule.tres` | 标准匹配规则：3张同花色连续               |
| `data/rules/easy_rule.tres`     | 简单规则：2张同花色即可匹配（无尽模式用） |
| `data/items/white_card.tres`    | 白牌道具定义                              |
| `data/items/chameleon.tres`     | 变色龙道具定义                            |

### 5.3 数据访问器（Database）

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

static func _generate_default(level_id: int) -> LevelConfig:
    var config = LevelConfig.new()
    config.level_id = level_id
    config.target_score = 1000 * level_id * level_id
    # hand_size 不再硬编码，使用 LevelConfig 默认值（15）或在 .tres 中配置
    config.match_rule = load("res://data/rules/standard_rule.tres")
    return config
```

### 5.3b 后期扩展：商店购买增加手牌位

当前 `hand_size` 由关卡 `.tres` 的 `@export` 字段配置。后续加入商店系统时，建议把**基础值**和**加成值**分离：

```gdscript
# src/autoload/PlayerData.gd（玩家持久化数据）
class_name PlayerData
extends Node

@export var hand_size_bonus: int = 0   # 商店购买的手牌位加成
@export var gold: int = 4
```

```gdscript
# src/game_logic/GameManager.gd
func get_current_hand_size() -> int:
    var base = LevelDatabase.get_level(current_level).hand_size
    var bonus = PlayerData.hand_size_bonus
    return base + bonus
```

商店购买时：
```gdscript
# 例如：花费 5 金币购买 +1 手牌位
PlayerData.gold -= 5
PlayerData.hand_size_bonus += 1
```

这样 `LevelConfig` 继续作为关卡基础设计，商店加成作为全局玩家进度，互不影响。

### 5.4 验收标准

- [ ]  双击 `data/levels/level_01.tres` 能在 Inspector 中编辑所有字段
- [ ]  `LevelDatabase.get_level(1).target_score` 返回正确值
- [ ]  修改 .tres 后不需要改代码即可影响游戏

---

## 6. Phase 3: 状态机系统

**目标:** 搭建 Node 树状态机，能跑通 Idle → Inserting → Matching → Idle 的空流程
**工期:** 2 天
**交付物:** 运行游戏后能在输出窗口看到状态流转日志

### 6.1 基类实现

参考 `docs/NodeStateMachine_Guide.md` 中的完整代码，此处列出核心接口：

#### StateMachine.gd（管理器）

- 收集所有子 State 节点
- `change_state(state_name)` 执行切换
- 发出 `state_changed` 信号
- 初始状态由 `@export var initial_state` 指定

#### State.gd（状态基类）

- `enter()` / `exit()` 生命周期
- `transition_requested(next_state_name)` 信号
- `go_to(state_name)` 便捷方法
- `set_process(false)` 在 exit 时关闭，enter 时开启

### 6.2 8 个状态节点实现


| 状态               | 核心职责      | 进入时做什么                                           | 退出时做什么 |
| ------------------ | ------------- | ------------------------------------------------------ | ------------ |
| **SetupState**     | 关卡初始化    | 创建普通牌堆、创建道具牌堆、洗牌、发初始手牌、抽 active card、清空道具槽 | 清理         |
| **IdleState**      | 等待玩家      | 启用输入、高亮可放位置                                 | 禁用输入     |
| **InsertingState** | 插入动画      | 调用 GameManager 执行插入、播动画                      | 清理         |
| **MatchingState**  | 检测匹配      | 调用 MatchEngine 检测                                  | 无           |
| **PlayingState**   | 消除动画+计分 | 调用 ScoreCalculator、播消除动画                       | 清理         |
| **FillingState**   | 补牌移位      | 调用 GameManager 补牌、播补位动画                      | 清理         |
| **LevelEndState**  | 关卡结算      | 显示结算 UI、连接按钮信号                              | 断开信号     |
| **GameOverState**  | 游戏结束      | 显示结束 UI                                            | 断开信号     |

### 6.3 场景节点配置

在 `scenes/Game.tscn` 中添加：

```
Game
├── GameManager
├── StateMachine (Node)                    ← 新增
│   ├── Setup (Node) + SetupState.gd       ← 新增：关卡初始化（发牌、创建道具牌堆）
│   ├── Idle (Node) + IdleState.gd         ← 新增
│   ├── Inserting (Node) + InsertingState.gd
│   ├── Matching (Node) + MatchingState.gd
│   ├── Playing (Node) + PlayingState.gd
│   ├── Filling (Node) + FillingState.gd
│   ├── LevelEnd (Node) + LevelEndState.gd
│   └── GameOver (Node) + GameOverState.gd
├── HandCardQueue
├── DrawPile
└── CardManager
```

### 6.4 状态流转图（完整版）

```
游戏启动 / 进入下一关
    │
    ▼
┌─────────┐
│  Setup  │  ← 创建52张普通牌堆、创建18张道具牌堆、洗牌、
│ (初始化) │     发hand_size张初始手牌、抽1张active card、清空道具槽
└────┬────┘
     │ 发牌动画完成
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

### 6.5 验收标准

- [ ]  运行游戏，控制台输出 `[StateMachine] -> Setup -> Idle`
- [ ]  点击任意 slot，输出 `[StateMachine] Idle -> Inserting -> Matching -> ... -> Idle`
- [ ]  插入白牌/变色龙后，状态直接回到 Idle，不经过 Matching
- [ ]  每个状态的 `enter()` / `exit()` 只执行一次，无重复调用
- [ ]  非活跃状态的 `_process` 不执行

---

## 7. Phase 4: 业务逻辑迁移

**目标:** 把匹配检测、分数计算、牌堆操作从"即将变成的硬编码"迁移到独立模块
**工期:** 2-3 天
**交付物:** 完整的核心玩法循环可运行

### 7.1 新建业务模块

#### MatchEngine.gd（匹配检测）

```gdscript
class_name MatchEngine
extends RefCounted

## 在手牌中找出所有匹配组
static func find_matches(hand: Array[CardData], rule: MatchRule) -> Array[Array]:
    var matches: Array[Array] = []
  
    var i = 0
    while i < hand.size():
        var segment = _get_suit_segment(hand, i, rule)
        if segment.size() >= rule.min_match_size:
            matches.append(segment)
            i += segment.size()
        else:
            i += 1
  
    return matches

static func _get_suit_segment(hand: Array[CardData], start: int, rule: MatchRule) -> Array[CardData]:
    if start >= hand.size():
        return []
  
    var suit = hand[start].suit
    var segment: Array[CardData] = []
  
    for j in range(start, hand.size()):
        var card = hand[j]
        # 白牌处理：如果规则允许 wildcard
        if card.type in rule.wildcard_types:
            segment.append(card)
            continue
        if card.suit == suit:
            segment.append(card)
        else:
            break
  
    return segment
```

#### ScoreCalculator.gd（分数计算）

```gdscript
class_name ScoreCalculator
extends RefCounted

## 计算一组匹配的分数
static func calculate(match_groups: Array[Array], chain_count: int, rule: MatchRule) -> int:
    var total_value = 0
    var total_cards = 0
  
    for group in match_groups:
        for card in group:
            total_value += card.get_value()
            total_cards += 1
  
    # 张数倍率
    var count_mult = 1.0 + (total_cards - 3) * 0.5
  
    # 连锁倍率
    var chain_mult = pow(2, chain_count - 1)
  
    # 扑克牌型奖励
    var poker_bonus = _evaluate_poker_bonus(match_groups)
  
    return ceil((total_value * count_mult + poker_bonus) * chain_mult)

static func _evaluate_poker_bonus(groups: Array[Array]) -> int:
    # 简化版：后续扩展为完整牌型检测
    return 0
```

### 7.2 改造 GameManager.gd

**改造前:**

```gdscript
class_name GameManager
extends Node

enum PlayState { IDLE, INSER_CARD, ... }
var play_new_state: PlayState = PlayState.IDLE

# 所有逻辑都要往这里塞...
```

**改造后:**

```gdscript
class_name GameManager
extends Node

# ===== 子系统引用 =====
@export var card_manager: CardManager
@export var state_machine: StateMachine

# ===== 运行时数据 =====
var current_level: LevelConfig
var hand_cards: Array[CardData] = []       # 手牌队列（仅普通牌）
var active_card: CardData                  # 当前激活牌（普通牌）
var item_slots: Array[CardData] = []       # 2个道具槽
var current_matches: Array[Array] = []
var current_score: int = 0
var gold: int = 4
var chain_count: int = 0
var is_item_played: bool = false           # 本回合是否已使用道具（不消耗回合）

# ===== 信号 =====
signal card_drawn(cards: Array[CardData])
signal score_changed(new_total: int, added: int, combo: int)

# ===== 生命周期 =====
func start_level(level_id: int):
    current_level = LevelDatabase.get_level(level_id)
    current_score = 0
    chain_count = 0
    hand_cards.clear()
    item_slots.clear()
    is_item_played = false
    
    # 创建两个独立牌堆
    card_manager.create_poker_deck()     # 52张普通牌
    card_manager.create_item_deck()      # 18张道具牌（10白+8变色龙）
    
    # 发初始手牌：抽 hand_size + 1 张普通牌
    var total = card_manager.draw_cards(current_level.hand_size + 1)
    # 最右侧1张作为active card
    active_card = total.pop_back()
    hand_cards.append_array(total)
    
    EventBus.level_started.emit(level_id, current_level.target_score)
    EventBus.cards_drawn.emit(hand_cards)
    EventBus.active_card_changed.emit(active_card)

# ===== 业务接口（供 State 调用） =====

## 插入普通激活牌
func insert_active_card_at(index: int) -> bool:
    if index < 0 or index > hand_cards.size():
        return false
    
    hand_cards.insert(index, active_card)
    is_item_played = false
    return true

## 插入白牌（道具）
func insert_white_card(slot_index: int, hand_index: int) -> bool:
    if slot_index < 0 or slot_index >= item_slots.size():
        return false
    
    var white_card = item_slots[slot_index]
    if not white_card or white_card.type != CardData.Type.WHITE:
        return false
    
    hand_cards.insert(hand_index, white_card)
    item_slots[slot_index] = null  # 道具槽清空
    
    # 白牌不触发匹配检测，不消耗回合
    EventBus.white_card_inserted.emit(hand_index)
    return true

## 插入变色龙（道具）
func insert_chameleon(slot_index: int, hand_index: int) -> bool:
    if slot_index < 0 or slot_index >= item_slots.size():
        return false
    if hand_index <= 0:
        return false  # 不能插在最左端
    
    var chameleon = item_slots[slot_index]
    if not chameleon or chameleon.type != CardData.Type.CHAMELEON:
        return false
    
    var left_card = hand_cards[hand_index - 1]
    if left_card.type == CardData.Type.WHITE:
        return false  # 左侧不能是白牌
    
    # 改变左侧牌花色
    left_card.suit = chameleon.suit
    item_slots[slot_index] = null  # 道具槽清空
    
    # 变色龙回收至道具牌堆底部
    card_manager.return_item_card(chameleon)
    
    EventBus.chameleon_used.emit(hand_index - 1, chameleon.suit)
    return true

## 回合结算：补充新激活牌、回收白牌
func end_round() -> void:
    # 回收白牌（插入的白牌消失，不触发碰撞）
    _recycle_white_cards()
    
    # 补充新激活牌（从手牌队列最右侧抽一张）
    if not active_card and hand_cards.size() > 0:
        active_card = hand_cards.pop_back()
        EventBus.active_card_changed.emit(active_card)
    
    is_item_played = false

func _recycle_white_cards() -> void:
    var recycled: Array[CardData] = []
    var new_hand: Array[CardData] = []
    
    for card in hand_cards:
        if card.type == CardData.Type.WHITE:
            recycled.append(card)
            card_manager.return_item_card(card)
        else:
            new_hand.append(card)
    
    hand_cards = new_hand
    
    if recycled.size() > 0:
        EventBus.white_cards_recycled.emit(recycled)

func find_matches() -> Array[Array]:
    return MatchEngine.find_matches(hand_cards, current_level.match_rule)

func score_current_matches() -> void:
    chain_count += 1
    var added = ScoreCalculator.calculate(current_matches, chain_count, current_level.match_rule)
    current_score += added
    EventBus.score_added.emit(added, current_score, chain_count)
    EventBus.match_found.emit(current_matches, chain_count)

func fill_empty_slots() -> void:
    # 移除已匹配的牌
    var to_remove: Array[CardData] = []
    for group in current_matches:
        for card in group:
            to_remove.append(card)
    
    for card in to_remove:
        hand_cards.erase(card)
    
    # 从牌堆顶部抽取相应数量，放入最左侧
    var needed = to_remove.size()
    if needed > 0:
        var drawn = card_manager.draw_cards(needed)
        # 新牌放入最左侧（补到hand_cards前面）
        for i in range(drawn.size()):
            hand_cards.insert(i, drawn[i])
    
    current_matches.clear()

func is_level_complete() -> bool:
    return current_score >= current_level.target_score

func has_valid_moves() -> bool:
    return active_card != null

func reset_chain() -> void:
    chain_count = 0

func award_level_rewards() -> void:
    var interest = floor(gold / float(current_level.reward_interest_divisor))
    var delta = current_level.reward_gold_base + interest
    gold += delta
    EventBus.gold_changed.emit(gold, delta)
```

### 7.3 验收标准

- [ ]  运行游戏，能完整进行一次"插入→检测→消除→补牌→等待"循环
- [ ]  消除时控制台输出正确分数
- [ ]  修改 `level_01.tres` 的 `target_score` 后，游戏目标分随之变化

---

## 8. Phase 5: UI 系统适配

**目标:** UI 层完全通过 EventBus 通信，不直接引用 GameManager
**工期:** 2 天
**交付物:** 所有 UI 表现通过信号驱动，支持输入启用/禁用

### 8.1 HandCardQueue.gd 改造

**改造前:**

```gdscript
@export var game_manager: GameManager

func _connect_signals():
    game_manager.card_drawned.connect(_on_card_drawned)
```

**改造后:**

```gdscript
class_name HandCardQueue
extends Control

@export var card_scene: PackedScene
@export var SLOT_SIZE: Vector2
@export var GAP_SIZE = Vector2i(20, 140)

var scale_ratio: float
var _cards_data: Array[CardData] = []
var cards_ui: Array[Card] = []
var slots: Array[Control] = []
var _max_slots: int = 10

@onready var container = $HandCardContainter

func _ready():
    EventBus.level_started.connect(_on_level_started)
    EventBus.cards_drawn.connect(_on_cards_drawn)
    EventBus.cards_eliminated.connect(_on_cards_eliminated)
    EventBus.input_enabled_changed.connect(_on_input_changed)
    EventBus.highlight_slots.connect(_on_highlight_slots)

func _on_level_started(level: int, target_score: int):
    # 获取关卡配置创建 slot
    var config = LevelDatabase.get_level(level)
    _max_slots = config.hand_size
    _create_slots(_max_slots)

func _on_cards_drawn(cards: Array[CardData], target_slots: Array[int]):
    for i in range(cards.size()):
        var card_ui = _create_card_ui(cards[i])
        cards_ui.append(card_ui)
        if target_slots[i] < slots.size():
            slots[target_slots[i]].add_child(card_ui)

func _on_slot_gui_input(event: InputEvent, slot_index: int):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        EventBus.card_slot_clicked.emit(slot_index)

func set_interactive(enabled: bool):
    for slot in slots:
        # 禁用/启用输入处理
        slot.set_process_input(enabled)
        slot.modulate = Color.WHITE if enabled else Color.GRAY

func play_insert_animation(card: CardData, slot_index: int, callback: Callable):
    # Tween 动画，完成后调用 callback
    pass

func play_eliminate_animation(cards: Array[CardData], callback: Callable):
    # Tween 动画，完成后调用 callback
    pass

func play_fill_animation(cards: Array[CardData], positions: Array[int], callback: Callable):
    # Tween 动画
    pass
```

### 8.2 新增 UI 组件


| 组件           | 文件                       | 职责                           |
| -------------- | -------------------------- | ------------------------------ |
| ActiveCardArea | `src/ui/ActiveCardArea.gd` | 显示当前 active card，支持拖拽 |
| ScoreDisplay   | `src/ui/ScoreDisplay.gd`   | 显示当前分数、目标分数、连锁数 |
| GoldDisplay    | `src/ui/GoldDisplay.gd`    | 显示金币数                     |
| ItemSlots      | `src/ui/ItemSlots.gd`      | 两个道具槽位                   |
| LevelInfo      | `src/ui/LevelInfo.gd`      | 显示当前关卡                   |

### 8.3 弹窗系统（Modals）

```
src/ui/Modals/
├── BaseModal.gd           ← 弹窗基类（打开/关闭动画）
├── LevelEndModal.gd       ← 关卡结算弹窗
├── GameOverModal.gd       ← 游戏结束弹窗
├── ShopModal.gd           ← 商店弹窗
└── PauseModal.gd          ← 暂停弹窗
```

### 8.4 验收标准

- [ ]  HandCardQueue 不再直接引用 GameManager
- [ ]  状态切换时，UI 输入自动启用/禁用
- [ ]  分数变化时，UI 自动更新显示
- [ ]  消除动画播放期间，玩家无法点击

---

## 9. Phase 6: 关卡与存档

**目标:** 实现多关卡切换 + 本地存档系统
**工期:** 1-2 天
**交付物:** 通关后进入下一关，退出游戏后进度保留

### 9.1 存档数据结构（JSON）

```json
{
    "version": 1,
    "highest_level": 3,
    "total_gold": 12,
    "unlocked_items": ["white_card", "chameleon"],
    "settings": {
        "sound_volume": 0.8,
        "music_volume": 0.5
    }
}
```

### 9.2 SaveManager.gd

```gdscript
class_name SaveManager
extends Node

const SAVE_PATH = "user://save.json"

static func save_game(data: Dictionary):
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))

static func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return _default_save()
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var text = file.get_as_string()
    var json = JSON.parse_string(text)
    return json if json else _default_save()

static func _default_save() -> Dictionary:
    return {
        "version": 1,
        "highest_level": 1,
        "total_gold": 4,
        "unlocked_items": [],
        "settings": {"sound_volume": 1.0, "music_volume": 1.0}
    }
```

### 9.3 关卡进度管理

```gdscript
# 在 GameManager 中
func start_next_level():
    current_level_id += 1
    start_level(current_level_id)
  
    # 更新存档
    var save = SaveManager.load_game()
    if current_level_id > save.highest_level:
        save.highest_level = current_level_id
    SaveManager.save_game(save)
```

### 9.4 验收标准

- [ ]  通关后选择"下一关"，正确进入 level_02
- [ ]  关闭游戏再打开，最高关卡进度保留
- [ ]  存档文件位于 `user://save.json`，人类可读

---

## 10. 文件结构对比

### 改造前

```
FIFOCard_Godot/
├── src/
│   ├── autoload/          (空)
│   ├── cards/
│   │   ├── Card.gd
│   │   ├── CardData.gd
│   │   └── CardManager.gd
│   ├── effects/           (空)
│   ├── game_logic/
│   │   └── GameManager.gd
│   └── ui/
│       ├── HandCardQueue.gd
│       └── Modals/        (空)
├── scenes/
│   ├── Game.tscn
│   └── card.tscn
└── assets/
    ├── audio/
    ├── fonts/
    └── textures/
```

### 改造后

```
FIFOCard_Godot/
├── src/
│   ├── autoload/
│   │   ├── EventBus.gd
│   │   └── GameData.gd
│   ├── data/
│   │   ├── LevelConfig.gd
│   │   ├── MatchRule.gd
│   │   ├── ItemDefinition.gd
│   │   ├── CardDefinition.gd
│   │   └── LevelDatabase.gd
│   ├── state_machine/
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
│   ├── game_logic/
│   │   ├── GameManager.gd       (改造后)
│   │   ├── MatchEngine.gd
│   │   ├── ScoreCalculator.gd
│   │   └── SaveManager.gd
│   ├── cards/
│   │   ├── Card.gd              (改造后)
│   │   ├── CardData.gd
│   │   └── CardManager.gd       (改造后)
│   ├── ui/
│   │   ├── HandCardQueue.gd     (改造后)
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
│   └── effects/                 (后续扩展)
├── data/
│   ├── levels/
│   │   ├── level_01.tres
│   │   └── level_02.tres
│   ├── rules/
│   │   └── standard_rule.tres
│   └── items/
│       ├── white_card.tres
│       └── chameleon.tres
├── locale/
│   └── zh_CN.json
├── scenes/
│   ├── Game.tscn                (改造后)
│   └── card.tscn
└── assets/
    ├── audio/
    ├── fonts/
    └── textures/
```

---

## 11. 风险与回滚策略


| 风险                         | 概率 | 影响 | 应对策略                                                                    |
| ---------------------------- | ---- | ---- | --------------------------------------------------------------------------- |
| 状态机循环卡死               | 中   | 高   | 每个状态加超时保护（5秒强制切回 Idle）；加`[F5]` 强制重置快捷键             |
| 信号未断开导致内存泄漏       | 低   | 中   | 严格遵守 State 的`exit()` 断开所有信号；用 Debugger 的 Monitor 检查节点数   |
| 数据文件丢失/损坏            | 低   | 中   | .tres 文件提交 Git；存档 JSON 加 version 字段做迁移兼容                     |
| 改造周期过长影响开发         | 高   | 中   | **分阶段交付**，每阶段都是一个可运行版本；不追求一次性完美                  |
| 性能下降（信号 vs 直接调用） | 低   | 低   | EventBus 是单例，信号连接有开销但可忽略；若瓶颈出现，关键路径可保留直接调用 |

### 回滚方案

- **每阶段独立 Git 提交**，保留 commit 历史
- 若某阶段出现问题，可 `git checkout` 回退到上一阶段
- 改造期间保留原始 `GameManager.gd.bak` 备份

---

## 12. 验收标准

### 总体验收

- [ ]  游戏能完整运行"插入→匹配→消除→补牌→连锁→等待"的核心循环
- [ ]  修改 `data/levels/level_01.tres` 的 `target_score` 无需改代码即可生效
- [ ]  新增一个道具只需创建 `.tres` 文件，无需改代码
- [ ]  UI 层不直接引用 GameManager，仅通过 EventBus 通信
- [ ]  状态切换有完整日志输出，非活跃状态的 `_process` 不执行
- [ ]  存档/读档功能正常

### 代码质量验收

- [ ]  GameManager 行数 < 200（改造前预计会膨胀到 500+）
- [ ]  每个 State 脚本独立，不互相引用
- [ ]  无循环引用（A引用B，B引用A）
- [ ]  所有 `@export` 变量在 Inspector 中有中文/英文注释说明

---

## 附录：实施优先级速查

如果你时间有限，按这个顺序做：


| 优先级 | 阶段                | 理由                                         |
| ------ | ------------------- | -------------------------------------------- |
| **P0** | Phase 3（状态机）   | 没有状态机，后续所有流程逻辑都会写成面条代码 |
| **P1** | Phase 1（EventBus） | 没有事件总线，模块间耦合无法解开             |
| **P2** | Phase 4（业务逻辑） | 核心玩法必须可运行                           |
| **P3** | Phase 2（数据层）   | 数据驱动是锦上添花，状态机才是骨架           |
| **P4** | Phase 5（UI适配）   | 视觉表现可以后补                             |
| **P5** | Phase 6（存档）     | 最后做，不影响核心玩法验证                   |

---

## 附录：人力估算


| 阶段                | 预估工时 | 单人开发          |
| ------------------- | -------- | ----------------- |
| Phase 1: 基础设施   | 4h       | 半天              |
| Phase 2: 数据层     | 6h       | 1天               |
| Phase 3: 状态机     | 8h       | 1-2天             |
| Phase 4: 业务逻辑   | 12h      | 2天               |
| Phase 5: UI 适配    | 8h       | 1-2天             |
| Phase 6: 关卡与存档 | 6h       | 1天               |
| **合计**            | **~44h** | **约1周（全职）** |

---

**文档结束。如需按此规划逐步实施，可以逐阶段执行，每阶段完成后验证验收标准。**
