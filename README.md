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
- **门**：`Room/Door` —— 后墙拆成三段留出 1.1 × 2.1 m 门洞，含门框、门板、三只铰链、把手、门缝灯带与门头灯
  - **可开启**：对着把手按 `E`，把手先绕自身轴顺时针转 45°，随后整扇门绕合页竖轴向外推开 110°
  - 门与墙体碰撞都拆好了，门开后人可以走出去；**门外没有地面**，走出去会直接掉下去
  - 掉出世界时发出 `fell_out_of_world` 信号，并播放 `Character/FallVoice` 上挂的音频；期间一直下坠，**等语音播完**（没挂语音时等 6 秒）再黑屏复位到出生点
- **旁白与字幕**：`Character/FallVoice` 播 `audio/voice/fall_01.mp3`（24 秒），字幕时间轴在 `audio/voice/fall_01.json`，按秒数逐句推到 `HUD/UIRoot/Subtitle`
- **转场**：`ScreenFade`（autoload）用 `shaders/iris_fade.gdshader` 做睁眼式黑幕——开场自动张开一次，掉出世界回来时再播一次；**黑幕没完全退开之前鼠标不能转视角**
- **顶灯**：吊顶灯罩 + `SpotLight3D`，灯罩内侧有自发光表面
- **书桌**：桌面与四条桌腿，桌面为木纹材质，桌面带碰撞体（可以跳上去）
- **电脑**：仿 90 年代卧式主机 + 大头 CRT（机箱带软驱/光驱面板与散热格栅，显示器有底座、后凸显像管、凹陷屏面与调节旋钮），键盘，以及沿 `Path3D` 程序化生成的键盘线与电源线
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
│   └── main.tscn          # 主场景：房间 / 书桌 / 电脑 / 台灯
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
│   ├── fall_01.mp3        # 坠落旁白（由 m4a 转码而来）
│   └── fall_01.json       # 字幕时间轴：每句的起止秒数
├── texture/
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

## 素材说明

`texture/` 下的 PBR 贴图取自公开素材库（ambientCG / Poly Haven 系列命名格式），主体为 CC0 授权。由于本仓库为公开仓库，**如需再分发或商用，请自行核对其原始授权条款**；`texture/*.tres` 材质与场景文件均为本项目原创。

## License

代码以 [MIT License](LICENSE) 开源，随便用，不必打招呼。

需要说明的是，MIT 只覆盖本仓库中的原创部分（脚本、场景、材质资源等）；`texture/` 下的第三方贴图仍遵循其原始授权条款，不在 MIT 覆盖范围内。

---

*这是一个个人兴趣项目，代码与结构会持续变动，不保证稳定性。*
