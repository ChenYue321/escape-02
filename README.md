# ESCAPE_02

一个**纯兴趣驱动的个人 Godot 项目** —— 没有排期、没有甲方，纯粹因为想做一个密室逃脱/环境叙事向的场景而写。

目前仍是早期原型：以手工搭建的 3D 室内场景为主体，探索程序化生成几何体（电线、管道）与写实 PBR 材质的组合效果。已经能走动、开关灯、开门、坐下，还有一小段"盯着屏幕看"的过场，但离完整的解谜游戏还很远。

> 可玩的 demo：[Releases](https://github.com/ChenYue321/escape-02/releases)（macOS / Windows / Linux）。

![Godot](https://img.shields.io/badge/Godot-4.7-478cbf)
![Status](https://img.shields.io/badge/status-prototype-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 技术栈

| 项 | 配置 |
| --- | --- |
| 引擎 | Godot 4.7（Forward+ 渲染后端） |
| 物理 | Jolt Physics |
| 语言 | GDScript |
| 美术 | 手工搭建的低多边形几何 + 公开 PBR 贴图 |

## 当前进度（以下包含剧透）

<details>
<summary>点开查看当前进度</summary>

目前的主体是一间可自由行走的封闭房间（`Scenes/main.tscn`，152 个节点），外加菜单、暂停、单存档和一小段屏幕过场：

- **房间**：地板、天花板、四面墙，混凝土与砖墙材质，踢脚线处的电源插座；`RoomCollision` 提供 8 个盒形碰撞体（地面/天花板/四面墙；门那面墙拆成左右两段 + 门楣）
- **门**：`Room/Door` —— 后墙拆成三段留出 1.1 × 2.1 m 门洞，含门框、门板、三只铰链、把手与门头灯
  - **可开启**：对着把手按 `E`，把手先绕自身轴顺时针转 45°，随后整扇门绕合页竖轴向外推开 110°
  - 按下 `E` 的同时播放 `audio/sfx/door_knob.mp3`，录音开头的静音已剪掉，所以咔哒声和把手转动是同步的
  - **每次从虚空被送回，门都会自动关回原位**（把手归零、恢复可交互）
  - 第一次被送回之后，门上会出现一块**吊在钉子上的告示牌**（`Room/Door/DoorPivot/Hanging Sign`）：木板 + 纸面 + 手写文字 + 钉头 + 两根由 `wire.gd` 生成的吊绳（系在钉头后面的钉杆上）；此前不可见
  - 纸上的字是 `texture/door/notice_dont_open.png`——用 Bradley Hand 手写体渲染的「Don't open!」，带轻微倾斜和墨迹扩散，透明背景叠在纸面上
  - 门与墙体碰撞都拆好了，门开后人可以走出去；**门外没有地面**，走出去会直接掉下去
  - 掉出世界时发出 `fell_out_of_world` 信号，并播放 `Character/FallVoice` 上挂的音频；期间一直下坠，**等语音播完**再黑屏复位到出生点，复位时位置、朝向、俯仰和蹲姿全部重置
  - 旁白只有前两次坠落有；**第三次起没有语音，掉落 4 秒后直接送回**
- **旁白与字幕**：`Character/FallVoice` 按**第几次掉下去**依次播 `fall_voices` 里的音频——第 1 次 `fall_01.mp3`（24 秒）、第 2 次 `fall_02.mp3`（12 秒），两条用完后第三次起就没有旁白；每条的字幕时间轴在同名 JSON 里，按秒数逐句推到 `HUD/UIRoot/Subtitle`
- **主菜单**：`Scenes/menu.tscn` 是项目启动场景。背景不是图片，而是把 `main.tscn` 整个实例化进来——删掉玩家、HUD、暂停菜单和 `WorldState`，隐藏所有 `Light3D`，只留显示器在黑暗里闪，所以背景是活的
  - 布局按参考图：左上角手写体标题 `ESCAPE-02`，下面 `START / CONTINUE / SETTING / EXIT` 左对齐，选中项前面加箭头
  - `CONTINUE` 只在 `user://save.cfg` 存在时插到 `START` 下面；新游戏按 `START` 会把旧存档清掉
  - 字体优先用 `SystemFont` 请求系统里的 Bradley Hand（回退 Chalkboard / Marker Felt / Comic Sans）；Linux 上这些通常都没有，会换成随包携带的 Patrick Hand（OFL）
  - `SETTING` 是**整页切换**（不是弹出小窗），里面是一组入口：`AUDIO` / `DISPLAY` / `CONTROLS` / `ACCESSIBILITY` / `KEY BINDING` / `BACK`；页面切换时交叉淡入 0.18 秒。这些页的行全部由 `menu.gd` 顶部的 `PAGES` 表驱动生成，加一项设置只要往表里加一行
  - **AUDIO**：`MASTER` / `VOICE` / `SFX` / `AMBIENCE` 四条滑条。后三条总线在运行时由 `Settings` 创建（`AudioServer.add_bus`），旁白走 Voice、开关和门走 SFX、雪花底噪走 Ambience
  - **DISPLAY**：`BRIGHTNESS`（相机曝光 0.6~1.8，菜单背景会实时预览）、`FOV`（65~100）、`3D QUALITY`（PERFORMANCE / BALANCED / SHARP）、`MAX FPS`（UNLIMITED / 30 / 60 / 120 / 144 循环）、`V-SYNC`、`FULLSCREEN`
  - **CONTROLS**：`SENSITIVITY`、`INVERT Y`、`CROUCH`（HOLD / TOGGLE）、以及通往 `KEY BINDING` 的入口
  - **ACCESSIBILITY**：`REDUCE FLICKER`（把 CRT 闪烁最低亮度抬到 75% 并禁用连闪，对光敏人群更安全）、`SUBTITLE BG`（字幕底衬不透明度，0 = 不加底）
  - `KEY BINDING`：`MOVE FORWARD / BACK / LEFT / RIGHT / JUMP / INTERACT / CROUCH` 七个动作各占一行，点当前按键开始监听，按下新键立刻生效并落盘；监听时按 Esc 撤销。用的是**物理键码**（`physical_keycode`），换键盘布局不会错位。底部有 `RESTORE DEFAULTS`，把所有动作还原成 `project.godot` 里的原始键位（默认值在 `Settings` 启动时快照下来）
  - 所有设置即时生效并写进 `user://settings.cfg`；相机 FOV / 曝光 / 反转 Y / 蹲下方式在进入游戏时由 `player.gd` 读取，字幕底衬由 `hud.gd` 读取
  - 相机取景由 `menu.gd` 的导出参数控制：`camera_position` / `camera_target` / `camera_fov`
- **暂停菜单**：游戏里按 `Esc` 打开 `PauseMenu`（`CanvasLayer`，layer 100），`RESUME / SETTING / EXIT`，背后压一层半透明灰罩；`SETTING` 直接复用主菜单的设置页（`settings_only` 模式，不建 3D 背景）。推镜过场期间暂停被临时禁用，到了 2D 黑屏里恢复可用
- **单存档**：暂停菜单的 `EXIT` 把玩家位姿、两盏灯和门的状态写进 `user://save.cfg`，然后回标题页；标题页检测到存档才生成 `CONTINUE`，按下读回。游戏里直接关窗口（`Cmd+Q` / 红叉）也会先落一份档。没有多存档槽，`START` 会清掉旧档
  - 进入屏幕过场前也会先存一次，所以从黑屏退出再 `CONTINUE`，会回到坐下之前的房间
  - 黑屏场景里没有 `Character`，那里的 `EXIT` 不会覆盖存档，保留的就是进入过场前的那一份
- **VHS 覆盖层**：`HUD/VHS` 是一个常驻的全屏 CanvasItem 着色器（`shaders/vhs.gdshader`）——轻微扫描线、色差、抖动、跟踪带、暗角和鱼眼；平时很淡，屏幕过场时由 `screen_trance.gd` 把参数推到满
- **屏幕过场**：坐上凳子、准星对准显示器屏幕并保持 **3 秒**——前 3 秒只有 VHS glitch 逐渐增强，相机不推进（视角仍然自由，移开就会中断）；中途移开视线或起身，glitch 会在 0.25 秒内退回去。满 3 秒后 glitch 拉满，相机在 2.8 秒内推到屏幕前 0.1 m，然后切到 `Scenes/screen_void.tscn`
- **2D 黑屏**：`screen_void.tscn` 一开始是与屏幕一致的雪花噪点；雪花先退成黑色，再"通电"成一块全屏的老 CRT：整屏的绿色荧光屏、扫描线、暗角和轻微球面弯曲，没有边框、指示灯或屏幕上的文字。屏幕上没有命令行或可操作内容，只是纯画面。屏幕里鼠标会释放，并换成绿色、3 像素块的像素箭头光标（参考那张向右的箭头图）；底部会像旁白一样显示 5 秒 `Hold [shift] to leave the computer`，暂停菜单仍然可用。按住 `Shift` 会倒放整个过程：CRT 断电、黑幕退掉、雪花和底噪回来 → 切回 3D、相机从屏幕前退回坐姿 → 人站起来（回到坐下前的位置），避免又被吸回去。黑屏之后的新内容还没做
- **彩蛋房间**：第二次坠落时玩家会被送进 `Scenes/escape01_room.tscn`。房间实例化在 `(2000, 0, 0)` 的独立空间里，不与主场景重叠；原场景的 18 个网格各有凸包碰撞体，展台和按钮另有自己的碰撞
  - **睁眼之后**才开始播放 `audio/voice/easter_01.mp3`（旁白吐槽这个房间），**说完之后**房间中央才升起展台：金色底座 + 黑漆柱 + 发光红环 + 红色亮面按钮
  - 展台和按钮都有实体碰撞（底座 / 柱身 / 按钮球三个形状，层 1），玩家撞得到；按钮另有层 2 的交互球
  - 对着按钮按 `E` 就送回主场景并销毁房间实例（`easter_egg_duration` 设为 0 表示只能靠按钮出来）
- **转场**：`ScreenFade`（autoload）用 `shaders/iris_fade.gdshader` 做睁眼式黑幕，**初始是全黑的**，由每个场景自己决定何时睁眼——菜单在 `menu.gd` 里张开，游戏场景由 `player.gd` 的 `_ready()` 张开（所以从菜单进来的转场是黑幕合上 → 换场景 → 睁开，中间不会漏出黑屏）；**黑幕完全退开之前不能移动、不能交互、不能转视角**（`ScreenFade.is_busy()` 统一判断，只保留 ESC 放光标）
- **顶灯**：吊在电线上的开放式灯罩（外罩 + 朝内的自发光内衬 + 圆环边框）、灯泡和 `SpotLight3D`；灯罩带 `CylinderShape3D` 碰撞，跳起来会撞到
- **开关音效与按键**：`lamp_switch.gd` 在运行时给每个开关挂一个 `AudioStreamPlayer3D`，**开灯放 `switch_on`、关灯放 `switch_off`**，与初始状态无关（开局同步状态时不发声）。两个录音开头的空白都已剪掉，按 E 和"咔哒"是同一帧；墙上开关的按键会随状态缩进/凸出（不做补间）
- **书桌**：桌面与四条桌腿，桌面为木纹材质，桌面带碰撞体（可以跳上去）
- **电脑**：仿 90 年代卧式主机 + 大头 CRT（机箱带软驱/光驱面板与散热格栅，显示器有底座、后凸显像管、凹陷屏面与调节旋钮），键盘，以及沿 `Path3D` 程序化生成的键盘线与电源线
  - 外壳材质用面粉微距贴图冒充老塑料——diffuse 做 albedo、GL 法线做表面颗粒、roughness 做哑光，世界坐标三平面映射（2.5 次/米），所以机箱、显示器、键盘的颗粒粗细一致
  - 两档泛黄：`pc_plastic.tres`（显示器/键盘，轻微氧化）与 `pc_plastic_aged.tres`（机箱本体与前面板，更黄的旧塑料）；泛黄靠 `albedo_color` 乘在贴图上实现
  - 屏幕底噪 `Static Noise`：6 秒无缝循环的雪花声，以显示器为球心，半径 = 到门那面墙的垂直距离（6.43 m），球内用 Godot 内置的**反比衰减**（`unit_size` 1 m），超出半径即静音
  - 屏幕是**无信号雪花屏**：`shaders/crt_static.gdshader` 程序化生成噪点 + 扫描线 + 滚动亮带 + 暗角
  - **会不定时抽一下**：`Desk/Computer/Monitor` 挂 `crt_flicker.gd`，只驱动屏幕着色器的 `brightness`（不照亮周围）。脚本里还留了可选的 `light_path`，指一盏灯就能连它一起闪
- **台灯**：灯罩、支架、底座 + `SpotLight3D`
- **第一人称控制器**：`Character`（`CharacterBody3D`）+ 胶囊碰撞体 + `script/player.gd`，相机位于 1.6 m 眼高
- **凳子**：`Stool`（紧贴桌前，凳沿与桌沿相距 10 cm，人挤不过去）——凳面用桌面木纹材质、凳腿用桌腿材质，无靠背；按 `E` 平滑坐下，坐着时只能转视角（仍可对别的东西按 `E`），按 `Shift` 平滑起身；坐下后把准星对准屏幕并保持 3 秒会触发屏幕过场
- **准星**：`HUD/UIRoot/Crosshair`（`CanvasLayer` + 自绘 `Control`），屏幕正中的圆点与四段短线，指到可交互物体时变金色并张开
- **交互**：`Camera3D/InteractRay`（`RayCast3D`，2.5 m）命中带 `interact()` 方法的碰撞体后弹出 `[E]` 提示
  - 吊灯：按门边墙上的按钮 `Room/Wall1 Right/Top Light Switch`（开局**默认亮着**）
  - 台灯：直接对着台灯按 `E`（开局**默认熄灭**）
  - 灯的默认状态直接由场景里 `SpotLight3D` 的 `visible` 决定，开关在 `_ready()` 时按它同步自发光灯片和按键位置
- **环境**：`WorldEnvironment`（Filmic 色调映射、微弱冷色环境光、SSAO、辉光），见 `environment/room_env.tres`

> 说明：角色**没有可见的身体模型**——相机位于胶囊体内部，第一人称下本来就看不到自己，只有投影会落在地上。交互已经能用，但还没有真正的解谜目标；黑屏之后的内容也还没接上。

</details>

## 操作方式

| 输入 | 行为 |
| --- | --- |
| `W` / `A` / `S` / `D` | 前 / 左 / 后 / 右移动（默认 4 m/s） |
| `空格` | 跳跃（0.5 m） |
| `Shift`（按住） | 蹲下：胶囊 1.8 → 1.15 m，眼高 1.6 → 0.95 m，移速降到 45%（设置里可改成 TOGGLE） |
| `E`（对准凳子） | 坐下：0.4 秒补间挪到座位，视点降到座面以上 0.65 m，只能转视角不能移动 |
| `Shift`（坐着时） | 起身，**不需要对准凳子**；坐上后屏幕下方会弹出 5 秒的字幕提示 `Press [shift] to stand up`，这一次按键不会触发蹲下 |
| 移动鼠标 | 转动视角（左右转身体，上下只转相机，俯仰限制 ±89°） |
| `ESC` | 打开/关闭暂停菜单（`RESUME / SETTING / EXIT`）；转场黑幕期间只释放鼠标 |
| 鼠标左键 | 在游戏里重新捕获鼠标 |
| `E` | 与准星指着的物体交互（门把手、门边的电灯按钮、台灯本身、凳子） |
| 坐着并对准屏幕 3 秒 | 触发屏幕过场：glitch → 相机推近 → 2D 黑屏 |
| 黑屏里按住 `Shift` | 倒放回房间：雪花回来 → 相机退出屏幕 → 起身 |

准星位于屏幕正中，形状由 `script/crosshair.gd` 的导出参数控制（点半径、四段短线长度、颜色），改完在 Inspector 里立即生效。

### 给新物体加交互

不需要继承任何基类：只要一个 `CollisionObject3D` 实现了 `interact(user)` 方法，就会被射线识别。

1. 在目标物体旁建一个 `StaticBody3D`，加 `CollisionShape3D`，碰撞层设为 **2（interactable）**、mask 设为 0 —— 玩家撞不到它，但射线看得到
2. 挂一个脚本，实现 `func interact(user: Node3D) -> void:`
3. 提示文字目前固定为 `[E]`，由 `player.gd` 的 `_update_focus()` 通过 `prompt_text_changed` 信号发出；要定制就从那里改


按键映射定义在项目设置的 `input/` 段，可在 `项目 → 项目设置 → 输入映射` 中改键或加重绑定（比如手柄）。

## 目录结构

```
escape-02/
├── project.godot          # 项目配置（渲染后端、物理引擎、ETC2/ASTC 导入）
├── export_presets.cfg     # macOS / Windows / Linux 导出预设
├── Scenes/
│   ├── menu.tscn          # 主菜单（项目启动场景）
│   ├── main.tscn          # 游戏场景：房间 / 书桌 / 电脑 / 灯 / 凳子
│   ├── pause_menu.tscn    # 暂停菜单（CanvasLayer）
│   ├── screen_void.tscn   # 屏幕过场之后的 CRT 终端
│   └── escape01_room.tscn # 彩蛋房间（由 escape-01 导入，已补 18 个碰撞体）
├── script/
│   ├── player.gd          # 第一人称控制器：移动、跳跃、蹲/坐、坠落、交互射线
│   ├── hud.gd             # HUD：准星高亮、[E] 提示、字幕
│   ├── crosshair.gd       # 屏幕准星：用 _draw() 画的圆点与短线
│   ├── lamp_switch.gd     # 开关灯：SpotLight3D、自发光灯片、按键缩进、音效
│   ├── door.gd            # 门把手交互：先转把手，再推开门
│   ├── sit_spot.gd        # 凳子：按 E 坐下
│   ├── screen_trance.gd   # 坐姿 + 盯着屏幕 3 秒 → glitch / 推镜 / 切场景
│   ├── screen_void.gd     # 2D 雪花淡出成纯黑
│   ├── menu.gd            # 主菜单：3D 背景 + START/CONTINUE/SETTING/EXIT
│   ├── pause_menu.gd      # 暂停菜单：RESUME / SETTING / EXIT
│   ├── save_game.gd       # autoload SaveGame：单存档读写
│   ├── screen_fade.gd     # autoload：睁眼式全屏转场
│   ├── game_settings.gd   # autoload Settings：音频/显示/控制/辅助/键位
│   ├── crt_flicker.gd     # 显示器闪烁：只驱动屏幕着色器亮度（可选带一盏灯）
│   ├── pedestal.gd        # 彩蛋房间展台：说完旁白后升起
│   ├── easter_button.gd   # 彩蛋按钮：按 E 送回主场景
│   └── wire.gd            # @tool：把 Path3D 曲线生成为管状网格
├── tools/
│   └── process_voice.sh   # 旁白批处理：降调 / 滤波 / 回声 / 响度归一
├── fonts/
│   ├── PatrickHand-Regular.ttf # Linux 上替代 Bradley Hand 的手写字体（OFL）
│   └── OFL.txt
├── environment/
│   └── room_env.tres      # 环境资源：环境光、色调映射、SSAO、辉光
├── shaders/
│   ├── iris_fade.gdshader # 转场用：从中心张开的椭圆黑幕
│   ├── crt_static.gdshader # 显示器雪花屏
│   ├── vhs.gdshader       # 全屏 VHS：扫描线 / 色差 / 抖动 / 鱼眼
│   ├── snow_2d.gdshader   # 2D 黑屏用的雪花
│   └── void_crt.gdshader  # 屏幕过场后的 CRT：荧光屏 / 扫描线 / 边框 / 电源灯
├── audio/voice/
│   ├── fall_01.mp3        # 第 1 次坠落的旁白
│   ├── fall_01.json       # 对应字幕时间轴
│   ├── fall_02.mp3        # 第 2 次坠落的旁白
│   ├── fall_02.json       # 对应字幕时间轴
│   ├── easter_01.mp3      # 彩蛋房间里的吐槽
│   └── easter_01.json     # 对应字幕时间轴
├── audio/sfx/
│   ├── switch_on.mp3      # 灯亮音效（CC0，已剪掉开头空白）
│   ├── switch_off.mp3     # 灯灭音效（CC0，已剪掉开头空白）
│   ├── door_knob.mp3      # 门把手音效（自录，已剪掉开头 1.26 秒空白）
│   └── tv_static.wav      # 显示器雪花底噪（6 秒无缝循环，取原素材中段）
├── texture/
│   ├── computer/          # 电脑外壳的米色粗塑料（albedo / normal / roughness）
│   ├── door/              # 门上告示牌的手写文字贴图（透明背景）
│   ├── wall/              # 砖墙 PBR 贴图
│   ├── ceiling/           # 天花板 PBR 贴图
│   ├── table/             # 木纹桌面 PBR 贴图
│   ├── concrete_floor_1k/ # 混凝土地面（含位移贴图）
│   ├── concrete_floor_worn_001_1k/
│   └── *.tres             # StandardMaterial3D 材质资源
└── icon.svg
```

## 核心脚本：`script/wire.gd`

场景里所有的电线、电源线都由这一个脚本生成，思路是"给定一条曲线，输出一根管子"：

- 标注 `@tool`，在编辑器内即可实时预览，无需运行游戏
- 沿 `Path3D` 的贝塞尔曲线等距采样（`rings` 段），每段按圆周切分（`sides` 边）生成顶点环
- 用切线 × 向上向量的正交基构建截面，并对切线近似垂直向上的情况做了退化处理
- 通过 `SurfaceTool` 提交三角面，支持在 Inspector 中调整 `radius` / `rings` / `sides`
- 改动曲线后点击 **Refresh Wire** 按钮重新生成网格

扩展用法：任意场景中新建 `Path3D` → 挂上该脚本 → 调整曲线控制点即可。

## 运行方式

不想自己开引擎的话，可以直接到 [Releases](https://github.com/ChenYue321/escape-02/releases) 下载 macOS / Windows / Linux（x86_64 与 arm64）demo 包。

1. 安装 **Godot 4.7**（标准版即可，无需 .NET 版本）
2. 在项目管理器中导入本仓库根目录的 `project.godot`
3. 首次打开时等待资源导入（`texture/` 约 25MB，会同时生成 S3TC 与 ETC2/ASTC 版本）
4. 按 `F5` 运行，或 `F6` 仅运行当前场景

`.godot/` 为引擎生成的导入缓存，已被 `.gitignore` 排除，无需提交。

## 已知限制

- 还没有完整的解谜链路：门、灯、凳子和屏幕过场之外，暂时没有可推进的目标
- 黑屏之后的新内容还没做；现在按住 `Shift` 只能倒放回房间
- 没有拾取、背包、门锁等系统
- 场景以基础几何体 + 少量程序化网格拼装，尚无自建模型
- 主要在 macOS 上开发；macOS 与 Linux arm64 已实机验证，Windows 与 Linux x86_64 还没有在对应系统上跑过
- 只做了键鼠，没有手柄支持

## Roadmap（想到哪做到哪）

- [x] 第一人称控制 + 碰撞体
- [x] 射线交互系统（灯、门、凳子）
- [x] 暂停菜单 + 单存档 + CONTINUE
- [x] 屏幕过场 / 2D 黑屏
- [x] 环境音效与旁白（开关、门、雪花底噪、坠落语音）
- [ ] 黑屏之后的内容
- [ ] 至少一条完整的解谜链路
- [ ] 氛围音乐
- [ ] 体积雾 / 更细的光照调优
- [ ] Windows / Linux x86_64 实机验证 / 手柄支持

## 人声处理约定

所有旁白/人声统一走 `tools/process_voice.sh`，现在是"老式座机听筒里的旁白"：

1. 降调 1.5 个半音（速度不变）——让录音不那么"像自己"
2. 340 Hz 高通 + 3.2 kHz 低通——老式电话的窄频带，去掉低频和齿音
3. 1.6 kHz +6 dB、2.5 kHz +3 dB——电话听筒的中频鼻音/箱声
4. 4:1 压缩 + tanh 软削波——像听筒被推得很响，带一点轻微失真
5. 削波后再收一次 330 Hz–3.1 kHz——不要带外高频
6. 单条 12 ms、5% 的极短反射——一点点听筒腔体感，不是房间混响
7. 很轻的 pink noise 线路底噪
8. 响度归一到 **-25 LUFS / 峰值 -3 dB**
9. 112 kbps 单声道 48 kHz MP3 输出（Godot 不认 `.m4a`）

```bash
tools/process_voice.sh ~/Downloads/某句台词.m4a audio/voice/xxx.mp3
```

脚本里的 `PITCH`、`TARGET_LUFS`、`HIGHPASS` / `LOWPASS`、`PHONE_PEAK_GAIN`、`ECHO_DECAY` 都可以直接改；`fall_01` / `fall_02` / `easter_01` 已经按这条链从原始 m4a 重新处理过。

## 素材说明

`texture/` 下的 PBR 贴图取自公开素材库（ambientCG / Poly Haven 系列命名格式），主体为 CC0 授权。由于本仓库为公开仓库，**如需再分发或商用，请自行核对其原始授权条款**；`texture/*.tres` 材质与场景文件均为本项目原创。

`fonts/PatrickHand-Regular.ttf` 为 Patrick Hand 字体，遵循 SIL Open Font License 1.1，完整许可见 `fonts/OFL.txt`。

## License

代码以 [MIT License](LICENSE) 开源，随便用，不必打招呼。

需要说明的是，MIT 只覆盖本仓库中的原创部分（脚本、场景、材质资源等）；`texture/` 下的第三方贴图与 `fonts/` 下的 Patrick Hand 仍遵循其原始授权条款，不在 MIT 覆盖范围内。

---

*这是一个个人兴趣项目，代码与结构会持续变动，不保证稳定性。*
