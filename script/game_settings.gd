extends Node

## 全局设置（autoload 名 Settings）：鼠标灵敏度倍率 + 主音量，
## 写在 user://settings.cfg 里，下次启动自动读回来。

const PATH := "user://settings.cfg"

## 鼠标灵敏度倍率（1.0 = 脚本里的默认值）
var mouse_scale: float = 1.0
## 主音量（线性 0~1）
var volume: float = 1.0


func _ready() -> void:
	load_settings()
	apply()


## 立刻作用到引擎：主音量走 Master 总线
func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var db := linear_to_db(maxf(volume, 0.0001)) if volume > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus, db)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_scale = clampf(float(cfg.get_value("input", "mouse_scale", mouse_scale)), 0.1, 5.0)
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_scale", mouse_scale)
	cfg.set_value("audio", "volume", volume)
	cfg.save(PATH)
