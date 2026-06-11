# GDScript & Godot 学习指南（从 JS 迁移）

## 一、核心语法对比

### 1.1 基础语法速查

```gdscript
# ========== 变量声明 ==========
# JavaScript
let count = 5;
const MAX = 10;

# GDScript
var count: int = 5          # 可变量
const MAX: int = 10         # 常量
@export var health: int     # 在编辑器中可调整

# ========== 函数定义 ==========
# JavaScript
function add(a, b) {
    return a + b;
}
const multiply = (a, b) => a * b;

# GDScript
func add(a: int, b: int) -> int:
    return a + b

func multiply(a: int, b: int) -> int:
    return a * b

# ========== 数组操作 ==========
# JavaScript
const arr = [1, 2, 3];
arr.push(4);
arr.splice(1, 1);
const mapped = arr.map(x => x * 2);
const filtered = arr.filter(x => x > 2);

# GDScript
var arr: Array[int] = [1, 2, 3]
arr.append(4)                           # push
arr.remove_at(1)                        # splice(index, 1)
var mapped = arr.map(func(x): return x * 2)
var filtered = arr.filter(func(x): return x > 2)

# 常用数组方法对比
# JS: arr.length           GD: arr.size()
# JS: arr.includes(x)      GD: x in arr 或 arr.has(x)
# JS: arr.indexOf(x)       GD: arr.find(x)
# JS: arr.find(x => x > 5) GD: arr.find(func(x): return x > 5)

# ========== 字典/对象 ==========
# JavaScript
const obj = { name: "Alice", age: 25 };
obj.score = 100;
console.log(obj.name);

# GDScript
var obj: Dictionary = {"name": "Alice", "age": 25}
obj["score"] = 100
print(obj["name"])
# 或使用 . 访问（如果key是有效的标识符）
print(obj.name)

# ========== 条件判断 ==========
# JavaScript
if (condition) {
} else if (other) {
} else {
}

# GDScript
if condition:
    pass
elif other:
    pass
else:
    pass

# ========== 循环 ==========
# JavaScript
for (let i = 0; i < 10; i++) { }
for (const item of array) { }
for (const key in object) { }

# GDScript
for i in range(10):           # 0 到 9
for i in range(5, 10):        # 5 到 9
for i in range(0, 10, 2):     # 0, 2, 4, 6, 8
for item in array:
for key in dict.keys():

# ========== 类定义 ==========
# JavaScript
class Card {
    constructor(suit, rank) {
        this.suit = suit;
        this.rank = rank;
    }
    
    getValue() {
        return this.rank === 'A' ? 11 : 10;
    }
}

# GDScript
class_name CardData
extends Resource      # 或 extends Node, RefCounted等

var suit: String
var rank: String

func get_value() -> int:
    return 11 if rank == "A" else 10

# ========== 字符串操作 ==========
# JavaScript
const str = `Hello ${name}`;
const parts = str.split(',');
const joined = arr.join('-');

# GDScript
var str = "Hello %s" % name           # 格式化
var str2 = "Hello {name}".format({"name": name})
var parts = str.split(',')
var joined = "-".join(arr)
```

### 1.2 特殊语法注意

```gdscript
# 1. 使用冒号和缩进（类似 Python）
func example():
    if true:
        print("缩进决定代码块")
    print("这一行在 if 外面")

# 2. 没有 switch，使用 match
match value:
    1:
        print("one")
    2, 3:
        print("two or three")
    _:
        print("other")

# 3. 空值处理
# JavaScript: null / undefined
# GDScript: null（只有null）
var maybe: CardData = null

# 4. 三元运算符
var result = "yes" if condition else "no"

# 5. 默认参数
func greet(name: String, greeting: String = "Hello") -> String:
    return "%s, %s!" % [greeting, name]

# 6. 静态函数
static func static_func():
    pass
```

---

## 二、Godot 核心概念（与 JS 最大的不同）

### 2.1 场景树（Scene Tree）

```gdscript
# 在 JS 中，DOM 是全局的
# document.getElementById('app')

# 在 Godot 中，场景树是节点层级
# 获取节点
@onready var hand_queue = $HandQueue           # 相对路径
@onready var game_manager = $"/root/Main/GameManager"  # 绝对路径
@onready var sprite = $Sprite2D as Sprite2D    # 带类型转换

# 节点操作
var new_card = card_scene.instantiate()        # 类似 document.createElement
add_child(new_card)                            # 添加到场景树
new_card.queue_free()                          # 删除节点（不要直接 free()）

# 获取子节点
for child in hand_container.get_children():
    if child is Card:
        child.highlight()

# 获取父节点
var parent = get_parent()

# 查找节点
var found = find_child("Card*", true, false)   # 递归查找名称为Card开头的
```

### 2.2 信号（Signals）- 替代事件监听

```gdscript
# JavaScript: 事件监听
element.addEventListener('click', handler);
button.onclick = handler;

# GDScript: 信号（Signal）
# 1. 定义信号（在类顶部）
signal card_clicked(card_data: CardData)
signal score_changed(new_score: int, old_score: int)

# 2. 发射信号
func on_button_pressed():
    card_clicked.emit(current_card)

# 3. 连接信号（_ready 中）
func _ready():
    # 方式1：连接自己的信号
    card_clicked.connect(_on_card_clicked)
    
    # 方式2：连接其他节点的信号
    $Button.pressed.connect(_on_button_pressed)
    
    # 方式3：用 Callable（类似 bind）
    $Card.card_clicked.connect(func(card): _handle_card(card, extra_data))

func _on_card_clicked(card_data: CardData):
    print("Card clicked: %s" % card_data.rank)

# 4. 断开信号
card_clicked.disconnect(_on_card_clicked)

# 5. 一次性连接
button.pressed.connect(_on_pressed, CONNECT_ONE_SHOT)
```

### 2.3 生命周期函数

```gdscript
extends Node

# 构造函数（少用，尽量用 _ready）
func _init():
    pass

# 节点进入场景树时调用
func _enter_tree():
    pass

# _ready: 节点和所有子节点都初始化完成
# 这是最常用的初始化点
func _ready():
    print("准备完成！")
    
# _process: 每帧调用（与帧率相关）
# delta: 上一帧到现在的时间（秒）
func _process(delta: float):
    position.x += speed * delta
    
# _physics_process: 物理帧（固定 60fps）
# 用于移动、碰撞检测等
func _physics_process(delta: float):
    velocity.y += gravity * delta
    move_and_slide()

# 节点即将退出场景树
func _exit_tree():
    pass
```

### 2.4 资源（Resource）vs 节点（Node）

```gdscript
# Resource: 轻量级数据容器，不依赖场景树
# 用于：卡牌数据、配置、存档数据
class_name CardData
extends Resource

@export var suit: String
@export var rank: String

# 使用
var card = CardData.new()
card.suit = "♠"

# Node: 场景树上的对象，有生命周期
# 用于：视觉元素、控制器、管理器
class_name Card
extends Control

@export var data: CardData  # 引用Resource

func _ready():
    update_visual(data)
```

---

## 三、实践练习建议

### 练习 1：CardData 和 CardManager

```gdscript
# 目标：实现牌堆创建和洗牌
# 文件：src/cards/CardData.gd

class_name CardData
extends Resource

enum Suit { SPADES, HEARTS, CLUBS, DIAMONDS }
enum Type { NORMAL, WHITE, CHAMELEON }

@export var id: int
@export var suit: Suit
@export var rank: String
@export var type: Type

func get_value() -> int:
    if rank == "A": return 11
    if rank in ["J", "Q", "K"]: return 10
    return int(rank)

# 挑战1：实现 to_string() 方法
# 挑战2：实现 duplicate() 的深拷贝
```

```gdscript
# 文件：src/cards/CardManager.gd

class_name CardManager
extends Node

const SUITS = [CardData.Suit.SPADES, CardData.Suit.HEARTS, 
               CardData.Suit.CLUBS, CardData.Suit.DIAMONDS]
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var deck: Array[CardData] = []
var item_deck: Array[CardData] = []

func create_deck() -> void:
    deck.clear()
    var id = 0
    for suit in SUITS:
        for rank in RANKS:
            var card = CardData.new()
            card.id = id
            card.suit = suit
            card.rank = rank
            card.type = CardData.Type.NORMAL
            deck.append(card)
            id += 1
    shuffle_deck()

func shuffle_deck() -> void:
    # 挑战：实现 Fisher-Yates 洗牌算法
    pass

func draw_card() -> CardData:
    # 挑战：实现抽牌，返回null如果牌堆为空
    pass

func create_item_deck() -> void:
    # 挑战：创建10张白牌+8张变色龙（每种花色2张）
    pass
```

### 练习 2：拖放系统

```gdscript
# 目标：实现卡牌的点击和拖放
# 文件：src/cards/Card.gd

class_name Card
extends Control

signal card_drag_started(card: Card)
signal card_dropped(card: Card, position: Vector2)

@export var data: CardData
@onready var texture_rect = $TextureRect

var is_dragging: bool = false
var drag_start_position: Vector2

func _ready():
    gui_input.connect(_on_gui_input)
    update_visual()

func _on_gui_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                # 开始拖动
                is_dragging = true
                drag_start_position = global_position
                card_drag_started.emit(self)
            else:
                # 结束拖动
                if is_dragging:
                    is_dragging = false
                    card_dropped.emit(self, global_position)

func _process(_delta):
    if is_dragging:
        global_position = get_global_mouse_position() - size / 2

func update_visual():
    # 挑战：根据 data 加载对应纹理
    pass
```

### 练习 3：匹配检测算法

```gdscript
# 文件：src/game_logic/MatchDetector.gd

class_name MatchDetector
extends RefCounted

# 挑战：将JS的 getSuitSegment 移植过来
static func get_suit_segment(hand_queue: Array[CardData], index: int) -> Dictionary:
    # 输入：手牌队列和索引
    # 输出：{"start": int, "end": int, "length": int} 或 null
    
    # 提示步骤：
    # 1. 获取index位置的卡牌
    # 2. 如果卡牌是白牌或变色龙，返回null
    # 3. 向左遍历，直到不同花色或白牌
    # 4. 向右遍历，直到不同花色或白牌
    # 5. 如果长度<3返回null，否则返回段信息
    
    return null  # 替换为实际实现

# 进阶挑战：检测碰撞点
static func find_collision_points(hand_queue: Array[CardData]) -> Array[int]:
    # 返回所有可能产生碰撞的索引位置
    return []
```

### 练习 4：递归连消

```gdscript
# 文件：src/game_logic/GameManager.gd（部分）

# 挑战：实现连消的递归/循环处理
# 参考JS的 checkAndResolveMatches

func process_matches(initial_index: int) -> void:
    var step_count = 0
    var total_to_draw = 0
    var indices_to_check = [initial_index]
    
    while indices_to_check.size() > 0 or total_to_draw > 0:
        # 提示：按照计划文档中的伪代码实现
        pass
    
    # 计算得分
    if play_area_cards.size() > 0:
        calculate_score(step_count - 1)

# 挑战：实现补牌动画的 await
func draw_cards_with_animation(count: int) -> void:
    # 提示：使用 Tween 创建补牌动画
    # 动画完成后继续
    pass
```

---

## 四、调试技巧

### 4.1 打印调试

```gdscript
func some_function():
    # 基本打印
    print("Debug message")
    
    # 打印变量
    print("Score: ", score, ", Level: ", current_level)
    
    # 打印数组/字典
    print("Hand queue: ", hand_queue)
    
    # 格式化打印
    print("Player has %d cards in hand" % hand_queue.size())
    
    # 打印对象（需要自定义 _to_string）
    print(card_data)  # 输出：<Resource#1234>

# 自定义资源打印
class_name CardData
extends Resource

func _to_string() -> String:
    return "%s%s" % [get_suit_symbol(), rank]

func get_suit_symbol() -> String:
    match suit:
        Suit.SPADES: return "♠"
        Suit.HEARTS: return "♥"
        Suit.CLUBS: return "♣"
        Suit.DIAMONDS: return "♦"
        _: return "□"
```

### 4.2 断点调试

1. 在编辑器中点击代码行号左侧添加断点
2. 按 F9 或点击运行
3. 当程序停在断点时：
   - **Step Over (F10)**: 执行当前行，不进入函数
   - **Step Into (F11)**: 进入函数内部
   - **Step Out (Shift+F11)**: 跳出当前函数
   - **Continue (F7)**: 继续运行

### 4.3 远程场景树检查

```gdscript
# 运行时检查场景树
func _ready():
    print_tree()  # 打印整个场景树
    
# 或者用编辑器远程场景树面板
# 项目设置 -> 调试 -> 远程场景树（默认开启）
```

### 4.4 性能分析

```gdscript
# 简单计时
var start_time = Time.get_ticks_msec()
# ... 执行代码
var elapsed = Time.get_ticks_msec() - start_time
print("耗时: %d ms" % elapsed)

# 使用内置性能分析器
# 调试 -> 性能分析器
```

---

## 五、常见陷阱

### 5.1 引用 vs 拷贝

```gdscript
# 陷阱：数组和字典是引用类型
var arr1 = [1, 2, 3]
var arr2 = arr1
arr2.append(4)
print(arr1)  # [1, 2, 3, 4] - arr1也被修改了！

# 解决：使用 duplicate()
var arr2 = arr1.duplicate()  # 浅拷贝
var arr3 = arr1.duplicate(true)  # 深拷贝

# 字典同理
var dict2 = dict1.duplicate(true)
```

### 5.2 节点生命周期

```gdscript
# 陷阱：在 _ready 中访问其他节点可能失败
func _ready():
    # 如果 GameManager 还没准备好，这会失败
    GameManager.score_changed.connect(_on_score_changed)

# 解决：使用 @onready 或延迟调用
@onready var game_manager = $"/root/Main/GameManager"

func _ready():
    game_manager.score_changed.connect(_on_score_changed)

# 或者使用 call_deferred
func _ready():
    call_deferred("late_setup")

func late_setup():
    # 此时所有节点都准备好了
    pass
```

### 5.3 异步/等待

```gdscript
# 陷阱：忘记标记函数为 async
func do_something():
    await get_tree().create_timer(1.0).timeout  # 错误！

# 解决：没有 async 关键字，await 只能在 coroutine 中使用
func do_something() -> void:
    await get_tree().create_timer(1.0).timeout  # 正确

# 如果函数返回被await的值，需要返回对应类型
func get_data_async() -> Dictionary:
    await some_async_operation()
    return {"key": "value"}
```

### 5.4 类型安全

```gdscript
# 陷阱：运行时类型错误
var cards: Array[CardData] = []
cards.append("string")  # 运行时错误！

# 解决：开启强类型检查
# 项目设置 -> 调试 -> GDScript -> 强类型检查

# 或者更安全的写法
func add_card(card: CardData) -> void:
    cards.append(card)
```

---

## 六、学习资源推荐

### 官方资源
- [GDScript 文档](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- [Godot API 参考](https://docs.godotengine.org/en/stable/classes/index.html)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

### 实践技巧
1. **从简单开始**：先实现 CardData 和 CardManager，测试洗牌和抽牌
2. **小步快跑**：每写一个小功能就运行测试
3. **大量打印**：不确定时就 print()
4. **查看示例项目**：Godot 自带许多示例项目

### 本项目的学习路径建议

```
第1天：只实现 CardData + CardManager
        - 创建52张牌
        - 洗牌
        - 抽牌测试

第2天：实现 Card 视觉 + 简单UI
        - 显示一张卡牌
        - 点击高亮

第3天：实现 HandQueue + DropZone
        - 显示15张牌
        - 点击位置插入新牌

第4天：实现 MatchDetector
        - 检测3+同花色
        - 测试各种边界情况

第5天：连接 GameManager
        - 完整回合流程
        - 补牌逻辑

第6天：添加计分
        - 基础计分（不计牌型）

第7天：添加牌型计算
        - 移植DFS算法
```

---

## 七、QA 清单

写代码时问自己这些问题：

- [ ] 变量是否有类型注解？
- [ ] 函数是否有返回类型？
- [ ] 是否使用了 @onready 缓存节点引用？
- [ ] 信号是否及时断开避免内存泄漏？
- [ ] 数组/字典操作前是否检查了大小？
- [ ] 异步函数是否正确使用了 await？
- [ ] 是否有 null 检查？
- [ ] 资源是否及时释放（queue_free）？

---

祝你学习愉快！遇到具体问题随时问我。
