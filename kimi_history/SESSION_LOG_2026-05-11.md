# Session Log - FIFOCard Godot

**Date**: 2026-05-11  
**Topic**: 激活牌插入手牌队列功能实现 & 架构讨论

---

## 项目速览

- **Engine**: Godot 4.4, GDScript
- **Renderer**: OpenGL Compatibility
- **Resolution**: 1920x1080
- **Core Mechanic**: 激活牌插入手牌队列 → 制造3张以上同花色连续相邻 → 消除得分

### 关键文件清单

| 路径 | 职责 |
|------|------|
| `src/ui/HandCardQueue.gd` | 手牌队列UI。管理 slots（Card容器）、gaps（间隙检测Button）、cards_ui（Card实例数组） |
| `src/ui/ActiveCardSlot.gd` | 激活牌槽。响应拖拽，在 DragLayer(CanvasLayer) 上创建 ghost |
| `src/cards/Card.gd` | 卡牌UI组件。含 CardButton，支持 button_down/up 拖拽阈值检测 |
| `src/cards/CardData.gd` | 卡牌数据 Resource（suit, rank, type, value） |
| `src/cards/CardManager.gd` | 牌组管理（52张普通牌创建、洗牌、抽牌） |
| `src/game_logic/GameManager.gd` | 游戏数据持有者（hand_cards, active_card, score, level） |
| `src/game_logic/StateMachine.gd` | Node树状态机管理器 |
| `src/game_logic/States/SetupState.gd` | 关卡初始化状态（发牌） |
| `src/autoload/EventBus.gd` | 全局事件总线 |
| `scenes/Game.tscn` | 主场景 |
| `docs/NodeStateMachine_Guide.md` | Node树分层状态机实现指南（8个状态） |
| `docs/Refactoring_Plan.md` | 6阶段重构规划（EventBus→数据层→状态机→业务逻辑→UI→存档） |
| `FIFOCardRule.md` | 完整游戏规则说明书（中文） |

---

## 已完成验证

### 1. Gap Button 拖拽检测方案（采纳）

**方案**: 在 `HandCardQueue` 每张牌之间的间隙创建 `Button`，平时 `mouse_filter = IGNORE`，拖拽激活牌时临时开启 `PASS`，通过 `mouse_entered` 信号直接获取插入 index。

**优势**: 无需每帧坐标计算，精度像素级，代码量比坐标方案少一半。

**关键代码**:
```gdscript
# _create_slots 中创建 slot_count+1 个 gap button
for i in range(slot_count + 1):
    var gap = Button.new()
    gap.mouse_filter = MOUSE_FILTER_IGNORE
    gap.mouse_entered.connect(_on_gap_mouse_entered.bind(i))
```

### 2. Ghost 鼠标事件穿透

**问题**: 拖拽时 ghost 在 CanvasLayer 上，内部 CardButton 拦截了下方 gap button 的 hover 事件。  
**解决**: 创建 ghost 后递归设置整棵树 `mouse_filter = IGNORE`：

```gdscript
_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
_set_mouse_filter_recursive(_drag_ghost, Control.MOUSE_FILTER_IGNORE)
```

### 3. 激活牌插入后旧牌消失 Bug（已定位）

**现象**: 激活牌插入手牌队列后，其他旧牌全部消失，只剩新插入的激活牌。  
**根因**: `_clear_slots()` 中 `slot.queue_free()` 会**递归连带销毁子节点**（Card UI）。虽然 `cards_ui` 数组保留了旧引用，但 Card 节点已被标记销毁。同一帧内 `add_child` 看似成功，帧末旧牌被回收。

**验证**:
- `is_instance_valid(cards_ui[i])` 返回 `true`（帧末前）
- `global_pos / visible / modulate` 全部正常
- 但 parent 出现 `@Control@7` 等匿名节点（新旧 slot 命名冲突证据）

**解决方案**: 在 `_clear_slots()` 中先 `remove_child(cards_ui)`，再 `queue_free(slot)`：

```gdscript
func _clear_slots() -> void:
    for i in range(min(slots.size(), cards_ui.size())):
        if is_instance_valid(cards_ui[i]) and cards_ui[i].get_parent() == slots[i]:
            slots[i].remove_child(cards_ui[i])
    
    for slot in slots:
        if is_instance_valid(slot):
            slot.queue_free()
    slots.clear()
    # ... gaps 清理同上
```

---

## 踩坑记录

| 坑 | 原因 | 教训 |
|---|---|---|
| `MOUSE_FILTER_PASS` 不等于透传 | PASS 仍会接收 `mouse_entered/mouse_exited`，只有 IGNORE 才完全不做鼠标检测 | ghost 必须设 IGNORE，不是 PASS |
| `queue_free()` 是延迟销毁 | 同一帧内节点仍 valid，但已带销毁标记 | 不能依赖 `is_instance_valid` 判断节点是否安全 |
| 新旧 slot 命名冲突 | 旧 slot 还没销毁，新 slot 同名 add_child 会被 Godot 重命名为 `@Control@N` | 先 remove_child 再 free，避免场景树打架 |
| 大上下文降智 | 长对话中错误假设堆积，模型注意力被噪声污染 | 人做压缩，AI做推理；里程碑后开新 session |

---

## 待办事项（Open）

### P0 - 当前阻塞
- [ ] **验证 `_clear_slots` 修复**: 在 `remove_child` 保护下，插入激活牌后旧牌是否正常显示
- [ ] **插入重排动画**: 旧牌后移一位的 Tween 动画
- [ ] **GameManager 数据插入**: `hand_cards.insert(index, active_card)`，`active_card = null`

### P1 - 状态机衔接
- [ ] 创建 `IdleState.gd`（extends States）
- [ ] `SetupState` 发牌动画完成后 `go_to("IDLE")`
- [ ] GameManager 监听 `card_slot_clicked` 执行数据插入

### P2 - 交互优化
- [ ] 拖拽时同花色邻居高亮预览（gap hover 时检测左右牌 suit）
- [ ] 无效区域释放时 ghost 回弹/恢复原位动画
- [ ] 新激活牌补充逻辑（从手牌队列最右侧取一张）

### P3 - 后续架构
- [ ] 接入 `MatchEngine.gd`（匹配检测）
- [ ] 接入 `ScoreCalculator.gd`（计分）
- [ ] UI 层完全通过 EventBus 通信，解除对 GameManager 的直接引用

---

## 架构决策备忘

### 状态机设计（当前已实现）
```
StateMachine
└── SETUP (SetupState) ──发牌完成──→ 待接入 IDLE
```

目标完整流转：
```
SETUP ──→ IDLE ──→ Inserting ──→ Matching ──→ Playing ──→ Filling ──→ Matching(连锁循环)
                                              ↓ 无匹配
                                            Idle / LevelEnd / GameOver
```

### 信号总线（EventBus）已定义关键信号
- `card_drag_started(card: Card)` / `card_droped(card, pos)` — Card 层
- `active_card_changed(data: CardData)` — ActiveCardSlot ↔ GameManager
- `card_slot_clicked(index: int)` — HandCardQueue → GameManager
- `deal_animation_finished()` — 发牌动画完成
- `level_started(hand_size: int)` — 关卡初始化

---

## 关于大上下文降智的教训

**现象**: 长对话中模型反复绕圈，给出复杂方案；开新 session 后 codex 一眼看出 `_clear_slots` 的 `queue_free` 连带销毁问题。

**根因**: LLM 的 "Lost in the Middle" —— 长序列中注意力稀释，早期错误假设污染后续推理。

**对策**:
1. **Session 切分**: 一个 session 只做一件事（搭框架 / 调功能 / 修 Bug）
2. **状态快照**: Session 结束时输出精炼的 "Checkpoint" 摘要，新 session 开头贴给 AI
3. **只给相关文件**: 用 `@` 精确引用，不要全文贴整个项目
4. **强指令重置**: 绕远时手动打断 —— "忽略之前所有假设，只基于以下事实重新推理：..."

---

## 备注

- `src/game_logic/State.gd` 定义 `class_name States`（注意是复数），SetupState/IdleState 需 `extends States`
- `src/game_logic/States/State.gd` 文件冗余（也定义了 `class_name State`），存在命名冲突风险
- Card.tscn 根节点 size = (150, 200)，HandCardContainter size.y = 140，scale_ration ≈ 0.7
