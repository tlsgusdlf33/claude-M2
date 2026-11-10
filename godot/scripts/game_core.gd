class_name GameCore
extends RefCounted
## prototype/index.html 의 CORE 구간을 GDScript로 옮긴 전투 로직입니다.
## 화면 출력과 입력은 main.gd가 맡고, 이 클래스는 상태 갱신만 합니다.
## 미검증: Godot에서 실행해 보지 못했습니다. tools/sim.js 와 같은 입력으로 결과를 비교해 확인하세요.
## 난수는 같은 식(mulberry32)을 썼지만 부동소수 처리 차이로 스폰 위치가 JS와 조금 다를 수 있습니다.

const W := 360.0
const H := 640.0
const PY := 560.0
const DEF := 598.0

const TYPES := {
	"rat": {"hp": 1.0, "spd": 1.0, "r": 15.0, "dmg": 1.0, "shoots": false},
	"bat": {"hp": 0.8, "spd": 1.25, "r": 14.0, "dmg": 1.0, "shoots": false},
	"boar": {"hp": 2.4, "spd": 0.7, "r": 19.0, "dmg": 1.6, "shoots": false},
	"snake": {"hp": 1.4, "spd": 0.9, "r": 15.0, "dmg": 1.0, "shoots": true},
}

const DOGS := {
	"jin": {"name": "진돗개", "atk_m": 1.3, "iv_m": 1.25, "hp_m": 1.5, "range": 440.0, "pierce": 2, "homing": false, "ult": "slash"},
	"beagle": {"name": "비글", "atk_m": 1.0, "iv_m": 1.0, "hp_m": 1.0, "range": 9999.0, "pierce": 0, "homing": false, "ult": "all"},
	"poodle": {"name": "푸들", "atk_m": 0.85, "iv_m": 0.9, "hp_m": 1.0, "range": 9999.0, "pierce": 0, "homing": true, "ult": "all"},
}

# ---- 상태
var stage: int
var dog: Dictionary
var st: Dictionary
var is_boss_stage: bool
var boss_name: String
var spawn_list: Array = []
var t := 0.0
var px := W / 2.0
var hp: float
var max_hp: float
var cd := 0.0
var bones: Array = []
var en: Array = []
var shots: Array = []
var zones: Array = []
var fx: Array = []
var gauge := 0.0
var qi := 0
var status := "play"  # play | won | lost
var kills := 0
var coins := 0
var manual := false
var boss = null
var boss_spawned := false
var flash := 0.0
var _a: int = 0
var _next_id := 1


# ---- 수치 함수 (JS와 동일)
static func base_hp(s: int) -> float:
	return 14.0 * pow(1.22, s - 1)

static func reward(s: int) -> int:
	return int(round(60.0 * pow(1.2, s - 1)))

static func cost(lv: int) -> int:
	return int(round(35.0 * pow(1.32, lv)))

static func offline_reward(cleared_max: int, minutes: float, club: bool) -> int:
	var rate := reward(maxi(1, cleared_max)) * 0.02
	var cap := 360.0 if club else 180.0
	return int(floor(rate * maxf(0.0, minf(minutes, cap))))

static func make_stats(up: Dictionary, d: Dictionary) -> Dictionary:
	return {
		"atk": 10.0 * (1.0 + 0.2 * up["atk"]) * d["atk_m"],
		"iv": 0.65 / (1.0 + 0.08 * up["spd"]) * d["iv_m"],
		"hp": 100.0 * (1.0 + 0.3 * up["hp"]) * d["hp_m"],
	}


func _rand() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var x := _a
	x = ((x ^ (x >> 15)) * (x | 1)) & 0xFFFFFFFF
	x = (x ^ (x + (((x ^ (x >> 7)) * (x | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF
	return float((x ^ (x >> 14)) & 0xFFFFFFFF) / 4294967296.0


func setup(p_stage: int, up: Dictionary, seed_value: int, dog_key: String = "beagle") -> void:
	stage = p_stage
	dog = DOGS[dog_key]
	st = make_stats(up, dog)
	hp = st["hp"]
	max_hp = st["hp"]
	_a = seed_value if seed_value != 0 else stage * 131 + 7
	_build_stage()


func _build_stage() -> void:
	is_boss_stage = (stage == 5 or stage == 10)
	boss_name = "쥐대왕" if stage == 5 else "불꽃 용"
	var n := (6 + stage) if is_boss_stage else (10 + int(round(stage * 1.8)))
	var dur := 16.0 if is_boss_stage else float(20 + stage)
	var avail: Array = ["rat"]
	if stage >= 2: avail.append("bat")
	if stage >= 3: avail.append("boar")
	if stage >= 4: avail.append("snake")
	# 스테이지 목록은 고정 시드로 만들어 JS 버전과 같은 구성이 되게 한다
	var saved := _a
	_a = 1000 + stage * 77
	spawn_list.clear()
	for i in n:
		spawn_list.append({
			"t": 1.0 + i * (dur / n) + _rand() * 0.6,
			"type": avail[int(floor(_rand() * avail.size()))],
			"x": 30.0 + _rand() * 300.0,
		})
	_a = saved


func _take_id() -> int:
	_next_id += 1
	return _next_id


func _spawn(type: String, x: float) -> Dictionary:
	var T: Dictionary = TYPES[type]
	var h := base_hp(stage) * T["hp"]
	var e := {
		"id": _take_id(), "type": type, "x": x, "x0": x, "y": -20.0, "hp": h, "max_hp": h,
		"spd": (34.0 + stage * 2.5) * T["spd"], "r": T["r"], "dmg": T["dmg"],
		"ph": _rand() * 6.0, "sc": 1.2 + _rand() * 1.5, "boss": false,
	}
	en.append(e)
	return e


func _spawn_boss() -> void:
	var h := base_hp(stage) * 16.0
	var b := {
		"id": _take_id(), "type": "boss", "x": W / 2.0, "x0": W / 2.0, "y": -60.0, "hp": h, "max_hp": h,
		"spd": 0.0, "r": 40.0 if stage == 5 else 46.0, "dmg": 0.0, "boss": true,
		"at": 2.0, "sm": 6.0, "big": 2 if stage == 5 else 3,
	}
	boss_spawned = true
	boss = b
	en.append(b)


func _kill(i: int) -> void:
	en.remove_at(i)
	kills += 1
	coins += int(round(2.0 + stage * 0.5))
	gauge = minf(100.0, gauge + 4.0)


## input: {"down": bool, "x": float, "ult": bool}
func update(dt: float, input: Dictionary) -> void:
	if status != "play":
		return
	dt = minf(dt, 0.05)
	t += dt
	manual = input["down"]
	if flash > 0.0:
		flash -= dt

	# 이동
	var tx := px
	if manual:
		tx = input["x"]
	else:
		var best := -1e9
		for e in en:
			if e["y"] > best:
				best = e["y"]
				tx = e["x"]
		if best == -1e9:
			tx = W / 2.0
	var sp := (360.0 if manual else 120.0) * dt
	px = clampf(px + clampf(tx - px, -sp, sp), 20.0, W - 20.0)

	# 스폰
	while qi < spawn_list.size() and spawn_list[qi]["t"] <= t:
		_spawn(spawn_list[qi]["type"], spawn_list[qi]["x"])
		qi += 1
	if is_boss_stage and not boss_spawned and t >= 2.0:
		_spawn_boss()

	# 자동 발사
	cd -= dt
	if cd <= 0.0:
		var seen := false
		for e in en:
			if e["y"] > 0.0:
				seen = true
				break
		if seen:
			bones.append({"x": px, "y": PY - 22.0, "vx": 0.0, "dist": 0.0, "hit": [],
				"pierce": dog["pierce"], "d": st["atk"] * (1.3 if manual else 1.0)})
			cd = st["iv"] * (0.85 if manual else 1.0)

	# 필살기
	gauge = minf(100.0, gauge + (2.2 if manual else 0.6) * dt)
	if input["ult"] and gauge >= 100.0:
		gauge = 0.0
		fx.append({"t": 0.0})
		var i := en.size() - 1
		while i >= 0:
			var e: Dictionary = en[i]
			var dmg := 0.0
			var hit := true
			if dog["ult"] == "slash":
				hit = absf(e["x"] - px) <= e["r"] + 80.0
				dmg = st["atk"] * (14.0 if e["boss"] else 16.0)
			else:
				dmg = st["atk"] * (12.0 if e["boss"] else 10.0)
			if hit:
				e["hp"] -= dmg
				if e["hp"] <= 0.0:
					if e["boss"]: boss = null
					_kill(i)
			i -= 1

	_update_bones(dt)
	_update_enemies(dt)
	_update_shots_and_zones(dt)

	var k := fx.size() - 1
	while k >= 0:
		fx[k]["t"] += dt
		if fx[k]["t"] > 0.45:
			fx.remove_at(k)
		k -= 1

	if hp <= 0.0:
		hp = 0.0
		status = "lost"
		coins = int(floor(coins * 0.5))
		return
	if qi >= spawn_list.size() and en.is_empty() and (not is_boss_stage or boss_spawned):
		status = "won"
		coins += reward(stage)


func _update_bones(dt: float) -> void:
	var i := bones.size() - 1
	while i >= 0:
		var b: Dictionary = bones[i]
		b["y"] -= 480.0 * dt
		b["dist"] += 480.0 * dt
		if dog["homing"]:
			var tg = null
			var bd := 1e9
			for e in en:
				if e["y"] < b["y"] and e["y"] > 0.0:
					var dd: float = absf(e["x"] - b["x"]) + (b["y"] - e["y"]) * 0.3
					if dd < bd:
						bd = dd
						tg = e
			if tg != null:
				b["vx"] += clampf((tg["x"] - b["x"]) / 20.0, -1.0, 1.0) * 900.0 * dt
				b["vx"] = clampf(b["vx"], -170.0, 170.0)
		b["x"] += b["vx"] * dt
		if b["y"] < -10.0 or b["dist"] > dog["range"]:
			bones.remove_at(i)
			i -= 1
			continue
		var j := 0
		while j < en.size():
			var e: Dictionary = en[j]
			if b["hit"].has(e["id"]):
				j += 1
				continue
			if absf(b["x"] - e["x"]) < e["r"] + 5.0 and absf(b["y"] - e["y"]) < e["r"] + 5.0:
				e["hp"] -= b["d"]
				b["hit"].append(e["id"])
				var dead: bool = e["hp"] <= 0.0
				if dead:
					if e["boss"]: boss = null
					_kill(j)
				if b["pierce"] <= 0:
					bones.remove_at(i)
					break
				b["pierce"] -= 1
				if dead:
					continue  # 같은 인덱스에 다음 적이 들어왔으므로 j를 올리지 않는다
			j += 1
		i -= 1


func _update_enemies(dt: float) -> void:
	var i := en.size() - 1
	while i >= 0:
		if i >= en.size():
			i = en.size() - 1
			if i < 0:
				break
		var e: Dictionary = en[i]
		if e["boss"]:
			if e["y"] < 95.0:
				e["y"] += 60.0 * dt
			else:
				e["x"] = W / 2.0 + sin(t * 0.7) * 105.0
				e["at"] -= dt
				if e["at"] <= 0.0:
					e["at"] = 3.2 if stage == 5 else 2.6
					for j in e["big"]:
						var zx := (px + (_rand() - 0.5) * 30.0) if j == 0 else (30.0 + _rand() * 300.0)
						zones.append({"x": clampf(zx, 45.0, W - 45.0), "w": 80.0, "warn": 1.1, "act": 0.5, "age": 0.0, "hit": false})
				e["sm"] -= dt
				if e["sm"] <= 0.0:
					e["sm"] = 9.0
					var m1 := _spawn("rat", e["x"] - 30.0)
					var m2 := _spawn("rat", e["x"] + 30.0)
					m1["y"] = e["y"] + 40.0
					m2["y"] = e["y"] + 40.0
			i -= 1
			continue
		if e["type"] == "snake":
			if e["y"] < 110.0:
				e["y"] += e["spd"] * dt
			else:
				e["sc"] -= dt
				if e["sc"] <= 0.0:
					e["sc"] = 2.4
					var dx: float = px - e["x"]
					var dy: float = PY - e["y"]
					var ln := maxf(sqrt(dx * dx + dy * dy), 0.0001)
					shots.append({"x": e["x"], "y": e["y"], "vx": dx / ln * 150.0, "vy": dy / ln * 150.0, "dmg": 6.0 + stage})
		else:
			e["y"] += e["spd"] * dt
			if e["type"] == "bat":
				e["x"] = e["x0"] + sin(t * 3.0 + e["ph"]) * 38.0
		e["x"] = clampf(e["x"], 16.0, W - 16.0)
		if e["y"] >= DEF:
			hp -= e["dmg"] * (5.0 + stage * 1.2)
			flash = 0.25
			en.remove_at(i)
		i -= 1


func _update_shots_and_zones(dt: float) -> void:
	var i := shots.size() - 1
	while i >= 0:
		var s: Dictionary = shots[i]
		s["x"] += s["vx"] * dt
		s["y"] += s["vy"] * dt
		if absf(s["x"] - px) < 16.0 and absf(s["y"] - PY) < 18.0:
			hp -= s["dmg"]
			flash = 0.25
			shots.remove_at(i)
		elif s["y"] > H + 10.0 or s["x"] < -10.0 or s["x"] > W + 10.0:
			shots.remove_at(i)
		i -= 1
	i = zones.size() - 1
	while i >= 0:
		var z: Dictionary = zones[i]
		z["age"] += dt
		if z["age"] >= z["warn"] and z["age"] < z["warn"] + z["act"] and not z["hit"] and absf(px - z["x"]) < z["w"] / 2.0 + 10.0:
			hp -= 14.0 + stage * 1.6
			z["hit"] = true
			flash = 0.25
		if z["age"] >= z["warn"] + z["act"]:
			zones.remove_at(i)
		i -= 1
