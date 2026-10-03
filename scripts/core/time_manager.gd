extends Node

## autoload: TimeManager —— 「天」的推进器。
##
## 规则:作物只在当天浇过水才会长一级,然后水会干(每天都要重浇)。
## 自动过一天(SECONDS_PER_DAY),也可以按 T 手动跳过(调 advance_day())。
## 注意:这里不实现昼夜光照,只推进日期 —— 见 docs/DECISIONS.md#no-daynight。

signal day_changed(day: int)

const SECONDS_PER_DAY := 45.0

var day: int = 1
var day_progress: float = 0.0
var auto_advance: bool = true


func _process(delta: float) -> void:
	if not auto_advance:
		return
	day_progress += delta
	if day_progress >= SECONDS_PER_DAY:
		day_progress -= SECONDS_PER_DAY
		advance_day()


func advance_day() -> void:
	day += 1
	day_progress = 0.0
	day_changed.emit(day)


func day_fraction() -> float:
	return clampf(day_progress / SECONDS_PER_DAY, 0.0, 1.0)
