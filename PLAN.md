# FIFOCard Godot 实现计划

## 一、项目架构设计

### 1.1 核心类结构

```
src/
├── autoload/
│   └── Global.gd              # 全局状态管理（高分、设置、金币）
├── cards/
│   ├── CardData.gd            # 卡牌数据类（suit, rank, value, type）
│   ├── Card.gd                # 卡牌视觉节点（TextureButton + 动画）
│   └── CardManager.gd         # 牌堆管理（洗牌、抽牌、道具牌堆）
├── game_logic/
│   ├── GameManager.gd         # 游戏主逻辑（回合、状态机）
│   ├── FIFOQueue.gd           # 手牌队列管理
│   ├── MatchDetector.gd       # 匹配检测（3+同花色连续）
│   ├── PokerHandCalculator.gd # 扑克牌型计算（DFS算法移植）
│   └── ScoreManager.gd        # 计分系统
├── ui/
│   ├── components/
│   │   ├── CardSlot.gd        # 卡槽基类
│   │   ├── HandQueue.gd       # 手牌队列UI
│   │   ├── DropZone.gd        # 放置区域
│   │   └── PlayArea.gd        # 出牌展示区
│   └── modals/
│       ├── ShopModal.gd       # 商店弹窗
│       ├── LevelClearModal.gd # 过关弹窗
│       └── GameOverModal.gd   # 游戏结束弹窗
└── effects/
    └── AnimationHelper.gd     # 动画辅助
```

### 1.2 关键数据结构

```gdscript
# CardData - 卡牌数据
class_name CardData
extends Resource

enum Suit { SPADES, HEARTS, CLUBS, DIAMONDS, NONE }
enum Type { NORMAL, WHITE, CHAMELEON }

var id: int
var suit: Suit
var rank: String  # "A", "2"-"10", "J", "Q", "K"
var value: int    # A=11, 2-10=face, J/Q/K=10
var type: Type
var is_white: bool

# 从原型移植的常量
const WHITE_CARD_RANK = "白"
const WHITE_CARD_SUIT = "□"
```

### 1.3 游戏状态机

```gdscript
enum GameState {
    IDLE,           # 等待玩家操作
    INSERTING,      # 插入卡牌动画中
    MATCHING,       # 检测匹配中
    DRAWING,        # 补牌动画中
    COMBO,          # 连消处理中
    ROUND_END,      # 回合结算
    LEVEL_CLEAR,    # 过关
    GAME_OVER       # 游戏结束
}
```

### 1.4 核心算法移植映射

| JavaScript 函数 | Godot 实现 | 说明 |
|----------------|-----------|------|
| `initGame()` | `GameManager.start_game()` | 初始化游戏 |
| `getSuitSegment()` | `MatchDetector.get_suit_segment()` | 获取同花色连续段 |
| `checkAndResolveMatches()` | `MatchDetector.check_and_resolve()` | 递归检测匹配 |
| `generateCandidateHands()` | `PokerHandCalculator.generate_candidates()` | 生成候选牌型 |
| `calculateBestPokerHand()` | `PokerHandCalculator.calculate_best()` | DFS找最优组合 |
| `handleDrop()` | `HandQueue.on_card_dropped()` | 处理放置 |
| `advanceRoundAfterSettlement()` | `GameManager.advance_round()` | 推进回合 |

---

## 二、开发阶段规划

### 阶段1：基础框架（预计1-2天）

#### 1.1 核心数据类
- [ ] `CardData.gd` - 卡牌数据定义
- [ ] `CardManager.gd` - 牌堆管理（52张牌+白牌+变色龙）
- [ ] `Global.gd` (AutoLoad) - 全局状态

#### 1.2 卡牌视觉
- [ ] 更新 `card.tscn` - 完善卡牌场景
- [ ] `Card.gd` - 卡牌控制器（翻转、高亮、拖动）

#### 1.3 场景搭建
- [ ] 重构 `Game.tscn` - 主游戏场景布局
  - 顶部状态栏（金币、分数、关卡、目标分、牌堆数）
  - 出牌区（Play Area）
  - 手牌队列区（Hand Queue + Drop Zones）
  - 激活牌区（Active Card）
  - 道具卡槽区（2 slots）

### 阶段2：核心游戏逻辑（预计2-3天）

#### 2.1 队列系统
- [ ] `FIFOQueue.gd` - 手牌队列管理
- [ ] `HandQueue.gd` - 手牌队列UI（含DropZone动态生成）
- [ ] `DropZone.gd` - 放置区域（检测鼠标位置高亮）

#### 2.2 匹配系统
- [ ] `MatchDetector.gd` - 同花色连续检测
  - `get_suit_segment(index)` - 获取包含index的同花色段
  - `check_collision(left, right)` - 检测碰撞
- [ ] 实现补牌、填空、碰撞连锁逻辑

#### 2.3 回合流程
- [ ] `GameManager.gd` - 主控制器
  - 初始化发牌逻辑
  - 回合推进（白牌不耗回合、普通牌耗回合）
  - 白牌延迟回收机制
  - 游戏结束检测

### 阶段3：计分系统（预计1-2天）

#### 3.1 牌型计算（移植JS算法）
- [ ] `PokerHandCalculator.gd`
  - `get_combinations()` - 组合生成
  - `generate_candidate_hands()` - 候选牌型
  - `calculate_best_poker_hand()` - DFS最优解
  - 牌型：对子、两对、三条、顺子、同花、葫芦、四条、同花顺

#### 3.2 计分逻辑
- [ ] `ScoreManager.gd`
  - 牌面分值计算
  - 牌数倍率（1 + (count-3) * 0.5）
  - 碰撞倍率（2^collision_count）
  - 牌型加成
  - 公式：`ceil((sum_values + poker_bonus) * card_mult * collision_mult)`

### 阶段4：道具与商店（预计1天）

#### 4.1 道具系统
- [ ] 白牌（White Card）逻辑
  - 抽到直接进道具槽
  - 插入后不计分、不消牌
  - 下回合回收
- [ ] 变色龙（Chameleon）逻辑
  - 改变左侧牌花色
  - 不能放在最左侧
  - 使用后回道具牌堆

#### 4.2 商店系统
- [ ] `ShopModal.tscn` - 商店界面
- [ ] 每关结束后弹出
- [ ] 2个道具槽位购买逻辑
- [ ] 金币扣除与物品添加

### 阶段5：UI与弹窗（预计1-2天）

#### 5.1 主UI组件
- [ ] 手牌队列高亮（匹配预览）
- [ ] 点数排序预览（按住按钮）
- [ ] 出牌区展示（带牌型标签）
- [ ] Combo徽章动画

#### 5.2 弹窗系统
- [ ] `LevelClearModal.tscn` - 过关弹窗（金币+利息+奖励）
- [ ] `GameOverModal.tscn` - 游戏结束弹窗
- [ ] `ShopModal.tscn` - 商店弹窗

### 阶段6：动画与特效（预计1天）

- [ ] 卡牌移动动画（FLIP技术移植）
- [ ] 补牌抽牌动画
- [ ] 匹配消除动画
- [ ] 分数弹出动画
- [ ] 连击效果

### 阶段7：调试与优化（预计1天）

- [ ] DEBUG模式（逐步连消）
- [ ] 性能优化
- [ ] 边界情况测试
- [ ] 存档持久化（最高分、金币）

---

## 三、关键实现细节

### 3.1 匹配检测算法（伪代码）

```gdscript
func get_suit_segment(hand_queue: Array[CardData], index: int) -> Dictionary:
    if index < 0 or index >= hand_queue.size():
        return null
    
    var current = hand_queue[index]
    if current.is_white or current.type == CardData.Type.CHAMELEON:
        return null
    
    var suit = current.suit
    var start = index
    var end = index
    
    # 向左扩展
    while start > 0 and not hand_queue[start - 1].is_white \
          and hand_queue[start - 1].suit == suit:
        start -= 1
    
    # 向右扩展
    while end < hand_queue.size() - 1 and not hand_queue[end + 1].is_white \
          and hand_queue[end + 1].suit == suit:
        end += 1
    
    var length = end - start + 1
    if length < 3:
        return null
    
    return {"start": start, "end": end, "length": length}
```

### 3.2 连消处理流程

```gdscript
func check_and_resolve_matches(initial_index: int) -> void:
    var step_count = 0
    var total_to_draw = 0
    var indices_to_check = [initial_index]
    
    while indices_to_check.size() > 0 or total_to_draw > 0:
        if indices_to_check.size() > 0:
            var check_idx = indices_to_check.pop_front()
            var match = get_suit_segment(hand_queue, check_idx)
            
            if match:
                step_count += 1
                # 移除匹配的牌，加入出牌区
                var matched = hand_queue.splice(match.start, match.length)
                play_area_cards.append_array(matched)
                
                # 播放动画
                await animate_cards_to_play_area(matched)
                
                total_to_draw += match.length
                
                # 检测碰撞（空位闭合后左右是否同花色）
                if match.start > 0 and match.start < hand_queue.size():
                    var left = hand_queue[match.start - 1]
                    var right = hand_queue[match.start]
                    if can_collide(left, right):
                        indices_to_check.append(match.start - 1)
                continue
        
        if indices_to_check.is_empty() and total_to_draw > 0:
            # 补牌
            var drawn = draw_cards(total_to_draw)
            await animate_draw_cards(drawn)
            total_to_draw = 0
            
            # 检测新补牌与原有牌的碰撞
            if drawn.size() > 0 and drawn.size() < hand_queue.size():
                var left = hand_queue[drawn.size() - 1]
                var right = hand_queue[drawn.size()]
                if can_collide(left, right):
                    indices_to_check.append(drawn.size() - 1)
    
    # 计算得分
    if play_area_cards.size() > 0:
        calculate_and_add_score(play_area_cards, step_count - 1)
```

### 3.3 扑克牌型DFS算法

```gdscript
# 移植自JS的 generateCandidateHands 和 DFS
func calculate_best_hand(cards: Array[CardData]) -> Dictionary:
    var candidates = generate_candidates(cards)
    candidates.sort_custom(func(a, b): return a.bonus > b.bonus)
    
    var best_combo = []
    var best_bonus = 0
    
    func dfs(index: int, current_mask: int, current_bonus: int, current_hands: Array):
        if current_bonus > best_bonus:
            best_bonus = current_bonus
            best_combo = current_hands.duplicate()
        
        # 剪枝
        var max_possible = current_bonus
        var temp_mask = current_mask
        for i in range(index, candidates.size()):
            if temp_mask & candidates[i].mask == 0:
                max_possible += candidates[i].bonus
                temp_mask |= candidates[i].mask
        
        if max_possible <= best_bonus:
            return
        
        # DFS搜索
        for i in range(index, candidates.size()):
            var cand = candidates[i]
            if current_mask & cand.mask == 0:
                current_hands.append(cand)
                dfs(i + 1, current_mask | cand.mask, current_bonus + cand.bonus, current_hands)
                current_hands.pop_back()
    
    dfs(0, 0, 0, [])
    return {"hands": best_combo, "bonus": best_bonus}
```

### 3.4 放置预览高亮

```gdscript
# 当拖动卡牌到手牌队列上方时
func preview_match_at_index(card: CardData, index: int) -> void:
    clear_highlights()
    
    # 模拟插入
    var preview_queue = hand_queue.duplicate()
    preview_queue.insert(index, card)
    
    # 获取匹配段
    var segment = get_suit_segment(preview_queue, index)
    if not segment or segment.length < 3:
        return
    
    # 高亮匹配的卡牌
    for i in range(segment.start, segment.end + 1):
        if i == index:
            continue  # 跳过刚插入的
        var hand_index = i if i < index else i - 1
        highlight_card(hand_index)
```

---

## 四、文件清单

### 4.1 新建脚本文件

```
src/autoload/Global.gd
src/cards/CardData.gd
src/cards/Card.gd
src/cards/CardManager.gd
src/game_logic/GameManager.gd
src/game_logic/FIFOQueue.gd
src/game_logic/MatchDetector.gd
src/game_logic/PokerHandCalculator.gd
src/game_logic/ScoreManager.gd
src/ui/components/CardSlot.gd
src/ui/components/HandQueue.gd
src/ui/components/DropZone.gd
src/ui/components/PlayArea.gd
src/ui/modals/ShopModal.gd
src/ui/modals/LevelClearModal.gd
src/ui/modals/GameOverModal.gd
src/effects/AnimationHelper.gd
```

### 4.2 新建场景文件

```
scenes/Main.tscn          (替换现有的Game.tscn)
scenes/Card.tscn          (更新现有的)
scenes/ui/HandQueue.tscn
scenes/ui/DropZone.tscn
scenes/ui/PlayArea.tscn
scenes/modals/ShopModal.tscn
scenes/modals/LevelClearModal.tscn
scenes/modals/GameOverModal.tscn
```

---

## 五、优先级建议

### 必须优先实现（MVP）
1. CardData + CardManager（基础数据）
2. HandQueue + DropZone（核心交互）
3. MatchDetector（核心玩法）
4. GameManager基础回合流程
5. 基础计分（不含牌型）

### 重要功能
6. 白牌道具系统
7. PokerHandCalculator完整计分
8. 商店系统
9. 过关/游戏结束流程

###  polish 功能
10. 动画系统
11. 变色龙道具
12. DEBUG模式
13. 存档系统

---

## 六、与HTML原型的差异

| 方面 | HTML原型 | Godot实现 |
|-----|---------|----------|
| 卡牌拖动 | HTML5 Drag API | Godot 内置拖拽/自定义点击移动 |
| 动画 | CSS Transition + FLIP | Godot Tween系统 |
| 状态管理 | 全局变量 | 场景树 + AutoLoad |
| 布局 | Flexbox | Godot Control节点 |
| 扑克牌型 | JS BigInt位运算 | GDScript int（64位足够） |

---

**预计总工期：7-10天（全职开发）**

建议按阶段逐步完成，每个阶段结束后进行测试验证。
