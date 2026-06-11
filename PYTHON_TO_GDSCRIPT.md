# Python → GDScript 快速迁移指南

> GDScript 设计初衷就是让 Python 开发者感到亲切，所以你会看到很多熟悉的东西。

---

## 一、几乎一样的地方（可以直接用）

### 1.1 基本语法

```gdscript
# 变量和赋值 - 几乎一样
var health = 100
var name = "Player"
var is_alive = true

# 列表/数组操作
var items = ["sword", "shield", "potion"]
items.append("key")          # 同 Python 的 append
items.remove_at(0)           # 同 Python 的 pop(0)
print(items[0])              # 索引访问一样

# 字典操作
var player = {"name": "Alice", "level": 5}
print(player["name"])
player["score"] = 100

# 条件语句
if health > 50:
    print("Healthy")
elif health > 20:
    print("Wounded")
else:
    print("Critical")

# 循环
for i in range(10):          # 0-9
for i in range(5, 10):       # 5-9
for item in items:           # 遍历

# while 循环
while health > 0:
    health -= 1

# 列表推导式（类似Python，但写法稍有不同）
var doubled = items.map(func(x): return x + "!")
var filtered = items.filter(func(x): return x.length() > 4)

# 函数定义
def greet(name):
    return "Hello, " + name

# 类定义
class MyClass:
    var value = 0
    
    def set_value(self, v):
        self.value = v
```

### 1.2 相同的关键字

这些关键字在 GDScript 中和 Python 用法几乎一样：
- `if`, `elif`, `else`
- `for`, `while`, `break`, `continue`
- `pass`
- `return`
- `and`, `or`, `not`
- `in`
- `True`, `False` → GDScript 是 `true`, `false`（小写）
- `None` → GDScript 是 `null`

---

## 二、主要区别（需要注意）

### 2.1 类型注解（GDScript 推荐强类型）

```gdscript
# Python: 类型是提示，不强制
def add(a: int, b: int) -> int:
    return a + b

add("hello", "world")  # Python 不会报错

# GDScript: 类型在调试时会检查
func add(a: int, b: int) -> int:
    return a + b

# 建议：始终加类型，Godot 编辑器会帮你检查和补全
func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)

# 变量类型
var count: int = 0
var health: float = 100.0
var name: String = "Player"
var items: Array[String] = ["a", "b", "c"]
var data: Dictionary = {"key": "value"}
```

### 2.2 缩进规则

```gdscript
# Python: 4空格缩进（PEP8）
def example():
    if True:
        print("indented")

# GDScript: 用 Tab 缩进（Godot编辑器默认）
func example():
    if true:
        print("indented")
    
    # 注意：每个代码块结束后回到上一级的缩进
    print("这行在 if 外面")
```

### 2.3 函数和方法的区别

```gdscript
# Python: 类方法第一个参数是 self
class Player:
    def __init__(self, name):
        self.name = name
    
    def say_hello(self):
        print(f"Hello, I'm {self.name}")

# GDScript: 不需要 self 参数
class_name Player
extends Node  # 或 RefCounted, Resource, Object等

var name: String

func _init(player_name: String):  # 构造函数
    name = player_name

func say_hello():
    print("Hello, I'm %s" % name)  # 直接使用成员变量，不用 self.
    # 或者：print("Hello, I'm ", name)
```

### 2.4 字符串格式化

```gdscript
# Python f-string
f"Hello {name}, you have {score} points"

# GDScript 方式1: % 格式化（类似 Python %）
"Hello %s, you have %d points" % [name, score]

# GDScript 方式2: format 方法
"Hello {name}, you have {score} points".format({"name": name, "score": score})

# GDScript 方式3: 字符串拼接
"Hello " + name + ", you have " + str(score) + " points"
```

### 2.5 类的继承和定义

```gdscript
# Python
class Animal:
    def __init__(self, name):
        self.name = name
    
    def speak(self):
        pass

class Dog(Animal):
    def __init__(self, name):
        super().__init__(name)
    
    def speak(self):
        return f"{self.name} says woof!"

# GDScript
class_name Animal
extends RefCounted  # 基础类

var name: String

func _init(animal_name: String):
    name = animal_name

func speak() -> String:
    return ""

# 子类
class_name Dog
extends Animal

func _init(dog_name: String):
    super(dog_name)  # 调用父类构造函数

func speak() -> String:
    return "%s says woof!" % name
```

### 2.6 枚举

```gdscript
# Python: 用 Enum 类
from enum import Enum
class Suit(Enum):
    SPADES = 1
    HEARTS = 2
    CLUBS = 3
    DIAMONDS = 4

# GDScript: 更简洁
enum Suit { SPADES, HEARTS, CLUBS, DIAMONDS }

# 使用
var my_suit: Suit = Suit.HEARTS

if my_suit == Suit.SPADES:
    print("Spades!")
```

---

## 三、Godot 特有的概念（重点）

### 3.1 场景树（Scene Tree）

这是 Godot 最核心的概念，相当于游戏的"DOM 树"。

```gdscript
# 想象这样一个场景树：
# Main (Node)
# ├── GameManager (Node)
# ├── HandQueue (Control)
# │   ├── Card1 (Control)
# │   ├── Card2 (Control)
# │   └── ...
# └── UI (CanvasLayer)

# 获取节点（类似 CSS 选择器）
@onready var game_manager = $GameManager           # 获取子节点
@onready var card = $HandQueue/Card1              # 获取嵌套子节点
@onready var global = $"/root/Main/GameManager"   # 绝对路径

# 节点操作
var new_card = card_scene.instantiate()   # 创建实例（类似复制模板）
add_child(new_card)                       # 添加到场景树
new_card.queue_free()                     # 删除（安全方式）

# 遍历子节点
for child in hand_queue.get_children():
    if child is Card:
        child.highlight()
```

### 3.2 信号（Signals）

信号是 Godot 的"事件系统"，比 Python 的回调更优雅。

```gdscript
# 定义信号（在类顶部）
signal health_changed(new_health, old_health)
signal card_clicked(card_data)
signal game_over(final_score)

# 发射信号
func take_damage(amount: int):
    var old_health = health
    health -= amount
    health_changed.emit(health, old_health)  # 通知所有监听者

# 连接信号（监听）
func _ready():  # _ready 是初始化函数，类似 __init__
    # 方式1：连接自己的信号
    health_changed.connect(_on_health_changed)
    
    # 方式2：连接其他节点的信号
    $Enemy.damage_dealt.connect(_on_enemy_attacked)
    
    # 方式3：一次性连接
    $Button.pressed.connect(_on_button_click, CONNECT_ONE_SHOT)

# 信号处理函数
func _on_health_changed(new_health: int, old_health: int):
    print("Health changed from %d to %d" % [old_health, new_health])
    update_health_bar(new_health)
```

### 3.3 生命周期函数

```gdscript
extends Node

# 构造函数（很少用）
func _init():
    pass

# 节点准备好（最常用）
func _ready():
    print("节点准备好了！")
    setup_cards()

# 每帧更新（用于动画、持续逻辑）
func _process(delta: float):
    # delta: 上一帧到现在的时间（秒）
    position.x += speed * delta  # 平滑移动

# 物理更新（固定60fps，用于物理相关）
func _physics_process(delta: float):
    velocity.y += gravity * delta
    move_and_slide()
```

### 3.4 @export 和 @onready 装饰器

```gdscript
class_name Player
extends CharacterBody2D

# @export: 让变量在编辑器中可调整
@export var speed: float = 300.0
@export var health: int = 100
@export var weapon_scene: PackedScene  # 可以拖入场景文件

# @onready: 等节点准备好后再获取
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
    # 这里可以安全地使用 sprite 和 collision
    sprite.modulate = Color.RED
```

### 3.5 资源（Resource）vs 节点（Node）

```gdscript
# Resource: 纯数据，不在场景树上，轻量级
class_name CardData
extends Resource

@export var suit: String
@export var rank: String
@export var value: int

func get_display_name() -> String:
    return "%s of %s" % [rank, suit]

# Node: 场景树上的对象，有生命周期
class_name Card
extends Control  # 或 Sprite2D, Node2D等

@export var data: CardData  # 引用Resource

func _ready():
    update_visual(data)
```

---

## 四、Python 程序员常见陷阱

### 4.1 数组/字典是引用类型

```gdscript
# Python 也有这个问题，但新手容易忘
var list1 = [1, 2, 3]
var list2 = list1
list2.append(4)
print(list1)  # [1, 2, 3, 4] - 两个变量指向同一个列表！

# 解决：使用 duplicate()
var list2 = list1.duplicate()      # 浅拷贝
var list3 = list1.duplicate(true)  # 深拷贝

# 字典也一样
var dict2 = dict1.duplicate(true)
```

### 4.2 整数除法

```gdscript
# Python 3
5 / 2    # 2.5（浮点数）
5 // 2   # 2（整数）

# GDScript
5 / 2    # 2（整数！如果两个操作数都是整数）
5.0 / 2  # 2.5（浮点数）
5 / 2.0  # 2.5
float(5) / 2  # 2.5
```

### 4.3 字典 key 访问

```gdscript
# Python: dict[key] 会抛出 KeyError
dict.get(key, default)  # 安全获取

# GDScript: dict[key] 同样会报错，但提供了更安全的写法
var value = dict.get(key, default_value)

# 或者用 has() 检查
if dict.has(key):
    print(dict[key])
```

### 4.4 没有 list comprehension

```gdscript
# Python
[x * 2 for x in items if x > 5]

# GDScript: 用 map 和 filter
items.map(func(x): return x * 2).filter(func(x): return x > 5)

# 或者传统循环
var result = []
for x in items:
    if x > 5:
        result.append(x * 2)
```

### 4.5 文件扩展名

```gdscript
# Python: .py
# GDScript: .gd

# 文件开头（可选但推荐）
class_name MyClassName    # 给类起个全局名字
extends Node              # 继承自什么
```

---

## 五、FIFOCard 项目练习（Python 思维版）

### 练习 1：卡牌数据结构

```gdscript
# src/cards/CardData.gd

class_name CardData
extends Resource

enum Suit { SPADES, HEARTS, CLUBS, DIAMONDS }
enum Type { NORMAL, WHITE, CHAMELEON }

@export var id: int
@export var suit: Suit
@export var rank: String  # "A", "2", "3"... "10", "J", "Q", "K"
@export var type: Type

# 计算卡牌分值
func get_value() -> int:
    match rank:
        "A": return 11
        "J", "Q", "K": return 10
        _: return int(rank)  # "2"-"10"

# 返回显示文本（类似 Python 的 __str__）
func _to_string() -> String:
    var suit_symbol = ["♠", "♥", "♣", "♦"][suit]
    return suit_symbol + rank

# 练习题：
# 1. 添加 is_red() 方法判断是否为红色花色
# 2. 添加 is_face_card() 方法判断是否为J/Q/K
# 3. 实现 duplicate() 的深拷贝
```

### 练习 2：牌堆管理器

```gdscript
# src/cards/DeckManager.gd

class_name DeckManager
extends Node

var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []

func create_standard_deck() -> void:
    deck.clear()
    var id = 0
    
    for suit in CardData.Suit.values():
        for rank in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
            var card = CardData.new()
            card.id = id
            card.suit = suit
            card.rank = rank
            card.type = CardData.Type.NORMAL
            deck.append(card)
            id += 1
    
    shuffle()

func shuffle() -> void:
    # Fisher-Yates 洗牌算法（Python 风格的实现）
    var n = deck.size()
    for i in range(n - 1, 0, -1):
        var j = randi() % (i + 1)  # randi() % n 生成 0 到 n-1 的随机数
        var temp = deck[i]
        deck[i] = deck[j]
        deck[j] = temp

func draw() -> CardData:
    if deck.is_empty():
        return null
    return deck.pop_back()

func draw_multiple(count: int) -> Array[CardData]:
    var drawn: Array[CardData] = []
    for i in range(count):
        var card = draw()
        if card == null:
            break
        drawn.append(card)
    return drawn

# 练习题：
# 1. 添加 create_deck_with_jokers() 创建含大小王的牌堆
# 2. 添加 reshuffle_discard() 将弃牌堆洗回牌堆
# 3. 实现抽牌时的概率加权（某些牌更容易被抽到）
```

### 练习 3：匹配检测（核心算法）

```gdscript
# src/game_logic/MatchDetector.gd

class_name MatchDetector
extends RefCounted  # 轻量级类，不需要节点功能

# 核心算法：找到包含指定位置的同花色连续段
static func get_suit_segment(hand: Array[CardData], index: int) -> Dictionary:
    """
    返回 {"start": int, "end": int, "length": int}
    如果没有3张以上连续同花色，返回 {}
    """
    if index < 0 or index >= hand.size():
        return {}
    
    var card = hand[index]
    
    # 白牌和变色龙不参与匹配
    if card.type == CardData.Type.WHITE or card.type == CardData.Type.CHAMELEON:
        return {}
    
    var suit = card.suit
    var start = index
    var end = index
    
    # 向左扩展
    while start > 0:
        var left_card = hand[start - 1]
        if left_card.type == CardData.Type.WHITE:
            break
        if left_card.suit != suit:
            break
        start -= 1
    
    # 向右扩展
    while end < hand.size() - 1:
        var right_card = hand[end + 1]
        if right_card.type == CardData.Type.WHITE:
            break
        if right_card.suit != suit:
            break
        end += 1
    
    var length = end - start + 1
    if length < 3:
        return {}
    
    return {
        "start": start,
        "end": end,
        "length": length
    }

# 练习题：
# 1. 实现检测所有可能的匹配位置
# 2. 实现检测"碰撞点"（两个同花色之间隔着空位或白牌）
# 3. 优化：用 while 循环替代递归处理连消
```

### 练习 4：游戏主逻辑

```gdscript
# src/game_logic/GameManager.gd

class_name GameManager
extends Node

# 游戏状态枚举
enum State {
    IDLE,           # 等待玩家操作
    PROCESSING,     # 处理中（动画播放）
    GAME_OVER
}

signal score_changed(new_score: int)
signal level_cleared(level: int)

@export var hand_size: int = 15

var current_state: State = State.IDLE
var hand: Array[CardData] = []
var active_card: CardData = null
var score: int = 0
var level: int = 1

@onready var deck_manager = $DeckManager
@onready var match_detector = MatchDetector.new()

func _ready():
    start_new_game()

func start_new_game() -> void:
    deck_manager.create_standard_deck()
    score = 0
    level = 1
    deal_initial_cards()

func deal_initial_cards() -> void:
    # 发 hand_size + 1 张牌
    var cards = deck_manager.draw_multiple(hand_size + 1)
    
    # 最后一张作为激活牌
    active_card = cards.pop_back()
    
    # 其余作为手牌
    hand = cards
    
    print("手牌: ", hand)
    print("激活牌: ", active_card)

func insert_card(card: CardData, position: int) -> void:
    """将卡牌插入指定位置"""
    if current_state != State.IDLE:
        return
    
    current_state = State.PROCESSING
    
    # 插入
    hand.insert(position, card)
    
    # 检测匹配
    var match = MatchDetector.get_suit_segment(hand, position)
    
    if match.is_empty():
        # 没有匹配，回合结束
        end_turn()
    else:
        # 有匹配，处理消除
        process_match(match)
    
    current_state = State.IDLE

func process_match(match: Dictionary) -> void:
    # 移除匹配的牌
    var matched_cards = []
    for i in range(match.start, match.end + 1):
        matched_cards.append(hand[i])
    
    # 从手牌中移除（注意：要从后往前删，避免索引变化）
    for i in range(match.end, match.start - 1, -1):
        hand.remove_at(i)
    
    # 计算分数
    var points = calculate_score(matched_cards)
    add_score(points)
    
    # 补牌
    refill_cards(matched_cards.size())

func refill_cards(count: int) -> void:
    var new_cards = deck_manager.draw_multiple(count)
    # 新牌插入到最左边
    for card in new_cards:
        hand.insert(0, card)

func end_turn() -> void:
    # 从手牌右边取一张作为新的激活牌
    if hand.size() > 0:
        active_card = hand.pop_back()

func add_score(points: int) -> void:
    score += points
    score_changed.emit(score)

func calculate_score(cards: Array[CardData]) -> int:
    # 基础实现：每张牌的分值相加
    var total = 0
    for card in cards:
        total += card.get_value()
    return total

# 练习题：
# 1. 实现连消逻辑（消除后补牌可能产生新的匹配）
# 2. 添加白牌处理（白牌插入不消耗回合）
# 3. 实现游戏结束检测
```

---

## 六、调试技巧

### 6.1 打印调试

```gdscript
func some_function():
    # 基本打印
    print("Debug message")
    
    # 打印变量（类似 Python 的 print）
    print("Score: ", score, ", Level: ", level)
    
    # 打印数组/字典
    print("Hand: ", hand)
    
    # 格式化打印
    print("Player has %d cards" % hand.size())
```

### 6.2 断点调试

1. 在 Godot 编辑器中点击代码行号左侧，设置断点（红点）
2. 按 **F9** 运行项目
3. 当程序停在断点时：
   - **F10**: 执行当前行（不进入函数内部）
   - **F11**: 进入函数内部
   - **Shift+F11**: 跳出当前函数
   - **F7**: 继续运行
4. 在"调试器"面板查看变量值

### 6.3 检查场景树

```gdscript
func _ready():
    print_tree()  # 打印整个场景树结构
    
    # 检查子节点
    for child in get_children():
        print(child.name, " - ", child.get_class())
```

---

## 七、推荐的学习路径

```
第1天：熟悉 GDScript
        - 创建简单的脚本，测试语法
        - 实现 CardData 类
        
第2天：牌堆系统
        - 实现 DeckManager
        - 测试洗牌和抽牌
        
第3天：游戏逻辑框架
        - 实现 GameManager
        - 实现基本的插入和匹配检测
        
第4天：UI连接
        - 创建卡牌场景
        - 连接按钮点击和信号
        
第5天：动画和效果
        - 使用 Tween 实现移动动画
        - 添加分数显示
        
第6-7天：完善功能
        - 连消逻辑
        - 白牌和变色龙
        - 计分系统
```

---

## 八、常用快捷键

| 快捷键 | 功能 |
|-------|------|
| **F9** | 运行项目 |
| **F7** | 继续（断点调试） |
| **F10** | 单步跳过 |
| **F11** | 单步进入 |
| **Ctrl+K** | 搜索文档 |
| **F12** | 跳转到定义 |
| **Ctrl+Shift+F** | 全局搜索 |
| **Ctrl+Space** | 代码补全 |

---

## 九、QA 清单

写代码时检查：

- [ ] 是否加了类型注解？（`var x: int` 而不是 `var x`）
- [ ] 函数是否标注了返回类型？（`func foo() -> int:`）
- [ ] 是否用 `@onready` 获取了节点引用？
- [ ] 修改数组前是否考虑了引用问题？
- [ ] 是否处理了可能的 null 值？
- [ ] 信号是否正确连接和断开？

---

祝你学习愉快！有任何问题随时问我。
