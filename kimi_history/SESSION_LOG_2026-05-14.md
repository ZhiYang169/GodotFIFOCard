# FIFOCard 会话记录 — 2026-05-14

## 1. 阅读项目架构

阅读了 `ARCHITECTURE_GUIDE.md`，了解了 FIFOCard 的目标架构：
- **四层架构**：表现层(View) → 调度层(StateMachine) → 业务层(GameManager/MatchEngine/ScoreCalculator) → 数据层(.tres 配置)
- **Node 树状态机**：8 个状态（Setup/Idle/Inserting/Matching/Playing/Filling/LevelEnd/GameOver），利用 `set_process()` 物理隔离
- **EventBus 全局信号**：层与层之间禁止直接引用，统一通过 Autoload EventBus 通信
- **数据驱动**：关卡配置、匹配规则、道具定义全部外置到 `data/*.tres`

## 2. 架构问题：激活牌插入后如何通知 ActiveCardSlot 清除 UI

**推荐方案**：在 `EventBus.gd` 中定义信号 `active_card_inserted(cards: Array[CardData])`。

信号流向：
- `GameManager.insert_active_card_at()` 执行成功后 → `EventBus.active_card_inserted.emit()`
- `ActiveCardSlot.gd` 在 `_ready()` 中连接该信号 → 收到后清除激活牌 UI

这是文档中"逻辑层 → UI"通信的标准范式。

## 3. Bug 修复：EventBus 信号名拼写不一致

**报错**：
```
Invalid access to property or key 'active_inserted' on a base object of type 'Node (EventBus.gd)'
```

**根因**：
- `EventBus.gd` 中定义的信号名：`active_card_inserted`
- `HandCardQueue.gd` 第 140 行调用的信号名：`active_inserted`

**修复**：两边信号名保持一致即可（建议统一为 `active_card_inserted`）。

## 4. Bug 分析：拖拽释放后影子牌未被销毁

**现象**：插入激活牌后，`ActiveCardSlot._on_drag_ended()` 中清理影子牌的逻辑没有执行，直接触发了 `_on_active_card_inserted()`，导致 `_drag_ghost` 残留在屏幕上。

**根因**：信号回调的执行顺序冲突。

当玩家松开鼠标，`Card` 发射 `card_droped` 信号，两个监听者：
1. `HandCardQueue._on_drag_ended()`
2. `ActiveCardSlot._on_drag_ended()`

如果 HandCardQueue 先执行，它内部会**同步**发射 `active_card_inserted`，触发 `ActiveCardSlot._on_active_card_inserted()` —— 该函数直接把 `active_card` `remove_child` + `queue_free()` 了。

随后当 `card_droped` 的下一个回调 `ActiveCardSlot._on_drag_ended()` 执行时，传入的 `card` 的父节点已不再是 `ActiveCardSlot`，`card.get_parent() != self` 直接 `return`，`_drag_ghost` 永远没机会被清理。

**修复方案**（未执行，仅提供分析）：
- `ActiveCardSlot._on_drag_ended()`：把 `card.get_parent() != self` 改为 `card != active_card`；对 `active_card` 使用 `is_instance_valid()` 检查
- `ActiveCardSlot._on_active_card_inserted()`：补充 `_drag_ghost` 的清理逻辑，同样使用 `is_instance_valid(active_card)`；销毁后把 `active_card = null`


---

## 5. GameManager._get_suit_segment 问题分析

**致命 Bug：`update_hand_cards` 第47行**
```gdscript
hand_cards.insert(index, hand_cards)   # ❌ 把整个数组作为单个元素插入自身
```
应该是 `hand_cards.insert(index, active_card)`。

**`_get_suit_segment` 返回顺序混乱**
先向右扫描再向左扫描，返回的数组不是按手牌索引排序的。例如手牌 `[♠A, ♠2, ♠3]` 调用 `_get_suit_segment(1)` 返回 `[♠2, ♠3, ♠A]`，后续消除动画或牌型评估会受影响。

**建议**：返回前按索引排序，或调整扫描顺序（先左后右）。

---

## 6. 为什么数组删除要从后往前

因为删除元素后，后面所有元素的索引会往前偏移。

示例：删除索引 1 和 2
- **从前往后**：先删索引1 → 原索引2变成新索引1 → 再删索引2时删的是原索引3，**原索引2逃掉了**
- **从后往前**：先删索引2 → 再删索引1 → 正确

替代方案：用 `slice` 拼接避免循环删除
```gdscript
hand_cards = hand_cards.slice(0, left) + hand_cards.slice(right + 1)
```

---

## 7. Bug：`get_tree().process_frames` 不存在

**报错**：`Invalid access to property or key 'process_frames' on a base object of type 'SceneTree'`

**根因**：`SceneTree` 没有 `process_frames`（复数），正确写法是：
- `await get_tree().process_frame`（单数，等待一帧）
- `Engine.get_process_frames()`（获取当前帧数）

---

## 8. PlayingCardState 耦合分析与索引 Bug

**耦合问题**：`PlayingCardState` 直接访问 GameManager 内部字段
```gdscript
EventBus.get_playing_card.emit(
    game_manager.current_matches[-1],                    # 直接读内部数组
    game_manager.matches_start_index_in_hand_queue       # 直接读内部变量
)
```
- 违反"GameManager 只管数据，提供业务接口"的架构原则
- `current_matches[-1]` 数组为空时会崩溃
- State 不应知道 GameManager 的内部存储结构

**推荐改法**：GameManager 提供封装方法
```gdscript
func get_last_match() -> Dictionary:
    if current_matches.is_empty():
        return {"cards": [], "start_index": -1}
    return {"cards": current_matches[-1], "start_index": matches_start_index_in_hand_queue}
```

**附：`_get_suit_segment` 中的索引赋值 Bug**
`matches_start_index_in_hand_queue = i` 只在**向左扫描**的循环里赋值。如果匹配段没有左侧延伸（只有插入点 + 右侧），该变量保持默认值 `-1`，但正确的起始索引应该是 `insert_index`。

**修复**：在 `_get_suit_segment` 开头初始化
```gdscript
matches_start_index_in_hand_queue = insert_index
```


---

## 9. 统一信号参数：CardEvent 数据结构

用户希望把 EventBus 中涉及卡牌操作的信号参数统一，避免有时传 index、有时传 card_data、有时传集合的混乱。

**推荐设计**：新建 `src/autoload/CardEvent.gd`
```gdscript
class_name CardEvent
extends RefCounted

var cards: Array[CardData] = []
var start_index_in_handcards: int = -1
var end_index_in_handcards: int = -1
var target_index_in_handcards: int = -1
var operation: String = ""

func is_empty() -> bool:
    return cards.is_empty()

func count() -> int:
    return cards.size()
```

**EventBus 信号统一后**：
```gdscript
signal card_drawned(event: CardEvent)
signal active_card_changed(event: CardEvent)
signal active_card_inserted(event: CardEvent)
signal get_playing_card(event: CardEvent)
```

**优点**：接口统一、扩展性强、减少参数个数。
**注意**：`Array[CardData]` 和 `Array` 类型不兼容，字面量数组赋值会报错，需用 `.assign()` 或先声明类型。

---

## 10. RefCounted 是什么

`RefCounted` 是 Godot 的**引用计数对象**，不进场景树、不用手动 `free()`，没人引用时自动销毁。

| 基类 | 内存管理 | 进场景树 | 保存为文件 |
|------|---------|---------|-----------|
| Node | 手动 `queue_free()` | ✅ | ❌ |
| RefCounted | 自动（引用计数归零销毁） | ❌ | ❌ |
| Resource | 自动（继承 RefCounted） | ❌ | ✅ `.tres` |

`CardEvent` 用 `RefCounted` 的原因：不进场景树、不保存文件、临时创建临时销毁、自动回收。

---

## 11. GameManager.get_last_matches 写法问题

**问题1**：`var match_info = CardEvent` —— 这是类引用，不是实例，必须 `CardEvent.new()`
**问题2**：字段名不匹配。CardEvent 里定义的是 `start_index_in_handcards`，但代码里写了 `matches_start_index_in_hand_queue`
**问题3**：EventBus 信号签名已改为 `CardEvent`，但 GameManager 里部分 `emit` 仍传旧类型（如 `active_card_changed.emit(active_card)` 传的是 `CardData` 而非 `CardEvent`）

---

## 12. ActiveCardSlot 没收到 active_card_changed 信号

**根因**：参数类型不匹配。
- EventBus 信号：`signal active_card_changed(event: CardEvent)`
- ActiveCardSlot 回调：`func _on_active_card_changed(event: CardData)`

Godot 4 信号回调参数类型不匹配时不会执行。修复：把回调参数改成 `CardEvent`。

---

## 13. 测试牌组方案

推荐轻量版：在 GameManager 中加 `test_mode` + 字符串数组配置。

```gdscript
@export var test_mode: bool = false
@export var test_hand: Array[String] = ["spades_2", "spades_3", "spades_4"]
@export var test_active_card: String = "spades_5"
```

`start_level()` 中根据 `test_mode` 走 `_setup_test_deck()`，跳过正常洗牌抽牌流程。字符串格式：`{suit}_{rank}`，如 `spades_A`、`hearts_10`。

---

## 14. Bug：go_to("IdleState") 没成功

**排查过程**：
1. 第一次错误猜测是 `"Idle State"` 带空格问题（实际用户写的是 `"IdleState"`）
2. 第二次查看 `Game.tscn`，发现 `StateMachine` 下**只有 SETUP 节点**，根本没有 IdleState 子节点
3. 用户添加节点后，第三次发现节点名是 **`IDLE`**（第107行），但代码里写的是 `go_to("IdleState")`。StateMachine 用 `child.name` 作为 key，字典里只有 `"IDLE"`

**修复**：统一节点名和代码中的状态名字符串。

---

## 15. 运行项目

通过命令行直接运行：
```bash
cd "d:/Godot/FIFOCard_Godot"
"/d/Godot/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64.exe" --path .
```

运行日志显示：
- SETUP → IDLE 状态切换成功
- 激活牌拖拽、插入流程正常
- 存在资源缺失报错：`res://assets/textures/back.png` 未找到
- 存在类型错误：`Attempted to insert a variable of type 'Array' into a TypedArray of type 'Object'`（GameManager `insert_active_card` 中 `hand_cards.insert(index, hand_cards)` 的 bug 导致）
