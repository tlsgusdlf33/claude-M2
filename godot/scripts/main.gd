extends Node2D
## 전투 화면 최소 뼈대. 이모지 대신 도형으로 그립니다. 메뉴, 강화, 저장은 아직 없습니다.
## 미검증: Godot에서 실행해 보지 못했습니다.

@export var stage_no: int = 1
@export_enum("jin", "beagle", "poodle") var dog_key: String = "beagle"
@export var up_atk: int = 0
@export var up_spd: int = 0
@export var up_hp: int = 0

const ULT_RECT := Rect2(236, 604, 116, 32)

var core: GameCore
var down := false
var touch_x := 180.0
var ult_pressed := false


func _ready() -> void:
	start_stage(stage_no)


func start_stage(s: int) -> void:
	core = GameCore.new()
	core.setup(s, {"atk": up_atk, "spd": up_spd, "hp": up_hp}, randi() % 65535 + 1, dog_key)


func _process(delta: float) -> void:
	if core == null:
		return
	core.update(delta, {"down": down, "x": touch_x, "ult": ult_pressed})
	ult_pressed = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and ULT_RECT.has_point(event.position):
			ult_pressed = true
			return
		down = event.pressed
		touch_x = event.position.x
		if not down and core != null and core.status != "play":
			start_stage(core.stage)  # 결과 화면 없이 탭으로 다시 시작
	elif event is InputEventMouseMotion and down:
		touch_x = event.position.x


func _draw() -> void:
	if core == null:
		return
	var g := core
	draw_rect(Rect2(0, 0, GameCore.W, GameCore.H), Color("1b3f36"))
	draw_dashed_line(Vector2(0, GameCore.DEF), Vector2(GameCore.W, GameCore.DEF), Color(1, 0.81, 0.29, 0.6), 2.0, 8.0)
	for z in g.zones:
		var active: bool = z["age"] >= z["warn"]
		var c := Color(1, 0.36, 0.3, 0.6) if active else Color(1, 0.36, 0.3, 0.1 + 0.2 * (z["age"] / z["warn"]))
		draw_rect(Rect2(z["x"] - z["w"] / 2.0, 0, z["w"], GameCore.DEF), c)
	for e in g.en:
		var col := Color("ff5d4d") if e["boss"] else Color("d9c2a0")
		draw_circle(Vector2(e["x"], e["y"]), e["r"], col)
	for s in g.shots:
		draw_circle(Vector2(s["x"], s["y"]), 6.0, Color("b6ff6a"))
	for b in g.bones:
		draw_rect(Rect2(b["x"] - 3, b["y"] - 8, 6, 16), Color.WHITE)
	if g.manual:
		draw_arc(Vector2(g.px, GameCore.PY), 28.0, 0.0, TAU, 32, Color("ffcf4a"), 3.0)
	draw_circle(Vector2(g.px, GameCore.PY), 18.0, Color("ffcf4a"))
	# HUD
	draw_rect(Rect2(8, 612, 200, 12), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(8, 612, 200.0 * maxf(0.0, g.hp / g.max_hp), 12), Color("7bd88f"))
	var ult_ready := g.gauge >= 100.0
	draw_rect(ULT_RECT, Color("ffcf4a") if ult_ready else Color(1, 1, 1, 0.12))
	draw_rect(Rect2(ULT_RECT.position, Vector2(ULT_RECT.size.x * g.gauge / 100.0, ULT_RECT.size.y)), Color(1, 0.81, 0.29, 0.45))
	if g.boss != null:
		draw_rect(Rect2(60, 14, 240.0 * maxf(0.0, g.boss["hp"] / g.boss["max_hp"]), 12), Color("ff5d4d"))
	if g.status != "play":
		var msg := "클리어 (탭하면 다시)" if g.status == "won" else "실패 (탭하면 다시)"
		draw_string(ThemeDB.fallback_font, Vector2(60, 300), msg, HORIZONTAL_ALIGNMENT_CENTER, 240, 22)
