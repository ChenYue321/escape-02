# ESCAPE_02

一个**纯兴趣驱动的个人 Godot 项目** —— 没有排期、没有甲方，纯粹因为想做一个密室逃脱/环境叙事向的场景而写。

目前处于早期原型阶段：以手工搭建的 3D 室内场景为主体，探索程序化生成几何体（电线、管道）与写实 PBR 材质的组合效果。尚未进入玩法逻辑开发。

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

## 当前进度

已完成的是一间可自由行走的封闭房间场景（`Scenes/main.tscn`，129 个节点）：

- **房间**：地板、天花板、四面墙，混凝土与砖墙材质，踢脚线处的电源插座；`RoomCollision` 提供 6 个盒形碰撞体（地面/天花板/四面墙）
- **门**：`Room/Door` —— 后墙拆成三段留出 1.1 × 2.1 m 门洞，含门框、门板、三只铰链、把手与门头灯
  - **可开启**：对着把手按 `E`，把手先绕自身轴顺时针转 45°，随后整扇门绕合页竖轴向外推开 110°
  - 按下 `E` 的同时播放 `audio/sfx/door_knob.mp3`，录音开头的静音已剪掉，所以咔哒声和把手转动是同步的
  - **每次从虚空被送回，门都会自动关回原位**（把手归零、恢复可交互）
  - 第一次被送回之后，门上会出现一块**吊在钉子上的告示牌**（`Room/Door/DoorPivot/Hanging Sign`）：木板 + 纸面 + 手写文字 + 钉头 + 两根由 `wire.gd` 生成的吊绳（系在钉头后面的钉杆上）；此前不可见
  - 纸上的字是 `texture/door/notice_dont_open.png`——用 Bradley Hand 手写体渲染的「Don't open!」，带轻微倾斜和墨迹扩散，透明背景叠在纸面上
  - 门与墙体碰撞都拆好了，门开后人可以走出去；**门外没有地面**，走出去会直接掉下去
  - 掉出世界时发出 `fell_out_of_world` 信号，并播放 `Character/FallVoice` 上挂的音频；期间一直下坠，**等语音播完**再黑屏复位到出生点，复位时位置、朝向、俯仰和蹲姿全部重置
  - 旁白只有前两次坠落有；**第三次起没有语音，掉落 4 秒后直接送回**
- **旁白与字幕**：`Character/FallVoice` 按**第几次掉下去**依次播 `fall_voices` 里的音频——第 1 次 `fall_01.mp3`（24 秒）、第 2 次起 `fall_02.mp3`（12 秒），再往后重复最后一条；每条的字幕时间轴在同名 JSON 里，按秒数逐句推到 `HUD/UIRoot/Subtitle`
- **彩蛋房间**：第二次坠落时玩家会被送进 `Scenes/escape01_room.tscn`。房间实例化在 `(2000, 0, 0)` 的独立空间里，不与主场景重叠；18 个网格全部生成了凸包碰撞体
  - **睁眼之后**才开始播放 `audio/voice/easter_01.mp3`（旁白吐槽这个房间），**说完之后**房间中央才升起展台：金色底座 + 黑漆柱 + 发光红环 + 红色亮面按钮
  - 展台和按钮都有实体碰撞（底座 / 柱身 / 按钮球三个形状，层 1），玩家撞得到；按钮另有层 2 的交互球
  - 对着按钮按 `E` 就送回主场景并销毁房间实例（`easter_egg_duration` 设为 0 表示只能靠按钮出来）
- **转场**：`ScreenFade`（autoload）用 `shaders/iris_fade.gdshader` 做睁眼式黑幕——开场自动张开一次，掉出世界回来时再播一次；**黑幕完全退开之前不能移动、不能交互、不能转视角**（`ScreenFade.is_busy()` 统一判断，只保留 ESC 放光标）
- **顶灯**：吊顶灯罩 + `SpotLight3D`，灯罩内侧有自发光表面
- **开关音效**：`lamp_switch.gd` 在运行时给每个开关挂一个 `AudioStreamPlayer3D`，**开灯放 `switch_on`、关灯放 `switch_off`**，与初始状态无关（开局同步状态时不发声）
- **书桌**：桌面与四条桌腿，桌面为木纹材质，桌面带碰撞体（可以跳上去）
- **电脑**：仿 90 年代卧式主机 + 大头 CRT（机箱带软驱/光驱面板与散热格栅，显示器有底座、后凸显像管、凹陷屏面与调节旋钮），键盘，以及沿 `Path3D` 程序化生成的键盘线与电源线
  - 外壳材质用面粉微距贴图冒充老塑料——diffuse 做 albedo、GL 法线做表面颗粒、roughness 做哑光，世界坐标三平面映射（2.5 次/米），所以机箱、显示器、键盘的颗粒粗细一致
  - 两档泛黄：`pc_plastic.tres`（显示器/键盘，轻微氧化）与 `pc_plastic_aged.tres`（机箱本体与前面板，更黄的旧塑料）；泛黄靠 `albedo_color` 乘在贴图上实现
  - 屏幕底噪 `Static Noise`：6 秒无缝循环的雪花声，以显示器为球心，半径 = 到门那面墙的垂直距离（6.43 m），球内用 Godot 内置的**反比衰减**（`unit_size` 1 m），超出半径即静音
  - 屏幕是**无信号雪花屏**：`shaders/crt_static.gdshader` 程序化生成噪点 + 扫描线 + 滚动亮带 + 暗角，屏幕前另有一盏冷光把桌面照亮
- **台灯**：灯罩、支架、底座 + `SpotLight3D`
- **第一人称控制器**：`Character`（`CharacterBody3D`）+ 胶囊碰撞体 + `script/player.gd`，相机位于 1.6 m 眼高
- **凳子**：`Stool`（紧贴桌前，凳沿与桌沿相距 10 cm，人挤不过去）——凳面用桌面木纹材质、凳腿用桌腿材质，无靠背；按 `E` 平滑坐下，坐着时只能转视角（仍可对别的东西按 `E`），按 `Shift` 平滑起身
- **准星**：`HUD/UIRoot/Crosshair`（`CanvasLayer` + 自绘 `Control`），屏幕正中的圆点与四段短线，指到可交互物体时变金色并张开
- **交互**：`Camera3D/InteractRay`（`RayCast3D`，2.5 m）命中带 `interact()` 方法的碰撞体后弹出 `[E]` 提示
  - 吊灯：按门边墙上的按钮 `Room/Wall1 Right/Top Light Switch`（开局**默认亮着**）
  - 台灯：直接对着台灯按 `E`（开局**默认熄灭**）
  - 灯的默认状态直接由场景里 `SpotLight3D` 的 `visible` 决定，开关在 `_ready()` 时按它同步自发光灯片
- **环境**：`WorldEnvironment`（Filmic 色调映射、微弱冷色环境光、SSAO、辉光），见 `environment/room_env.tres`

> 说明：角色**没有可见的身体模型**——相机位于胶囊体内部，第一人称下本来就看不到自己，只有投影会落在地上。交互与解谜逻辑尚未开始。

## 操作方式

| 输入 | 行为 |
| --- | --- |
| `W` / `A` / `S` / `D` | 前 / 左 / 后 / 右移动（默认 4 m/s） |
| `空格` | 跳跃（0.5 m） |
| `Shift`（按住） | 蹲下：胶囊 1.8 → 1.15 m，眼高 1.6 → 0.95 m，移速降到 45% |
| `E`（对准凳子） | 坐下：0.4 秒补间挪到座位，视点降到座面以上 0.65 m，只能转视角不能移动 |
| `Shift`（坐着时） | 起身，**不需要对准凳子**；坐上后屏幕下方会弹出 5 秒的字幕提示 `Press [shift] to stand up`，这一次按键不会触发蹲下 |
| 移动鼠标 | 转动视角（左右转身体，上下只转相机，俯仰限制 ±89°） |
| `ESC` | 释放鼠标，方便切出窗口 |
| 鼠标左键 | 重新捕获鼠标 |
| `E` | 与准星指着的物体交互（门把手、门边的电灯按钮、台灯本身） |

准星位于屏幕正中，形状由 `script/crosshair.gd` 的导出参数控制（点半径、四段短线长度、颜色），改完在 Inspector 里立即生效。

### 给新物体加交互

不需要继承任何基类：只要一个 `CollisionObject3D` 实现了 `interact(user)` 方法，就会被射线识别。

1. 在目标物体旁建一个 `StaticBody3D`，加 `CollisionShape3D`，碰撞层设为 **2（interactable）**、mask 设为 0 —— 玩家撞不到它，但射线看得到
2. 挂一个脚本，实现 `func interact(user: Node3D) -> void:`
3. 想改提示文字，改 `HUD/UIRoot/Prompt` 的 `text`


按键映射定义在项目设置的 `input/` 段，可在 `项目 → 项目设置 → 输入映射` 中改键或加重绑定（比如手柄）。

## 目录结构

```
escape-02/
├── project.godot          # 项目配置（渲染后端、物理引擎）
├── Scenes/
│   ├── main.tscn          # 主场景：房间 / 书桌 / 电脑 / 台灯
│   └── escape01_room.tscn # 彩蛋房间（由 escape-01 导入，已补 18 个碰撞体）
├── script/
│   ├── player.gd          # 第一人称控制器：WASD 移动、跳跃、鼠标视角、交互射线
│   ├── hud.gd             # HUD：把交互焦点翻译成准星高亮与 [E] 提示
│   ├── lamp_switch.gd      # 交互示例：开关灯（切换 SpotLight3D 与自发光灯片）
│   ├── crosshair.gd       # 屏幕准星：用 _draw() 画的圆点与短线
│   ├── screen_fade.gd     # autoload：睁眼式全屏转场
│   ├── door.gd            # 门把手交互：先转把手，再推开门
│   └── wire.gd            # @tool 脚本：把 Path3D 曲线生成为管状网格
├── environment/
│   └── room_env.tres      # 环境资源：环境光、色调映射、SSAO、辉光
├── shaders/
│   ├── iris_fade.gdshader # 转场用：从中心张开的椭圆黑幕
│   └── crt_static.gdshader # 显示器雪花屏
├── audio/voice/
│   ├── fall_01.mp3        # 第 1 次坠落的旁白
│   ├── fall_01.json       # 对应字幕时间轴
│   ├── fall_02.mp3        # 第 2 次起的旁白
│   ├── fall_02.json       # 对应字幕时间轴
│   ├── easter_01.mp3      # 彩蛋房间里的吐槽
│   └── easter_01.json     # 对应字幕时间轴
├── audio/sfx/
│   ├── switch_on.mp3      # 灯亮音效（CC0）
│   ├── switch_off.mp3     # 灯灭音效（CC0）
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

1. 安装 **Godot 4.7**（标准版即可，无需 .NET 版本）
2. 在项目管理器中导入本仓库根目录的 `project.godot`
3. 首次打开时等待资源导入（约 20MB 贴图）
4. 按 `F5` 运行，或 `F6` 仅运行当前场景

`.godot/` 为引擎生成的导入缓存，已被 `.gitignore` 排除，无需提交。

## 已知限制

- 门不可开启：`RoomCollision` 的 Wall1 仍是一整块，所以门洞被碰撞挡住（正好符合“关着”的状态）；要开门时需要把这块碰撞也拆开
- 无拾取、门锁等解谜逻辑（开关灯已实现）
- 场景全部使用基础几何体拼装，尚无自建模型
- 未做性能与多平台验证，目前仅在 macOS 上开发

## Roadmap（想到哪做到哪）

- [x] 第一人称控制 + 碰撞体
- [x] 射线交互系统（开关灯已实现；拾取、观察尚未做）
- [ ] 至少一条完整的解谜链路
- [ ] 音效与氛围音乐
- [ ] 光照与后处理调优（SSAO、体积雾）

## 人声处理约定

所有旁白/人声统一走 `tools/process_voice.sh`，处理链固定为：

1. 降调 1.5 个半音（速度不变）——让录音不那么"像自己"
2. 80 Hz 高通，去掉手持和房间低频
3. 4 kHz 以上 -3 dB，压齿音与手机麦克风的尖锐感
4. 60 / 95 ms 两道短回声，制造房间感
5. 响度归一到 **-25 LUFS / 峰值 -3 dB**——比音效低几 dB，落在"旁白"而不是"贴耳说话"的位置
6. 160 kbps 单声道 48 kHz MP3 输出（Godot 不认 `.m4a`）

```bash
tools/process_voice.sh ~/Downloads/某句台词.m4a audio/voice/xxx.mp3
```

脚本里的 `PITCH`（降调比例）和 `TARGET_LUFS`（目标响度）可以直接改；除非某句台词另有要求，否则沿用这套默认值。

## 素材说明

`texture/` 下的 PBR 贴图取自公开素材库（ambientCG / Poly Haven 系列命名格式），主体为 CC0 授权。由于本仓库为公开仓库，**如需再分发或商用，请自行核对其原始授权条款**；`texture/*.tres` 材质与场景文件均为本项目原创。

## License

代码以 [MIT License](LICENSE) 开源，随便用，不必打招呼。

需要说明的是，MIT 只覆盖本仓库中的原创部分（脚本、场景、材质资源等）；`texture/` 下的第三方贴图仍遵循其原始授权条款，不在 MIT 覆盖范围内。

---

*这是一个个人兴趣项目，代码与结构会持续变动，不保证稳定性。*
