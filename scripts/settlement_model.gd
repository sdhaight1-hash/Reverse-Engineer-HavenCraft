extends RefCounted
class_name SettlementModel

## Original simulation designed from publicly documented gameplay ideas.
## All simulation logic is deterministic and independent of rendering.

const SIZE := 32
const MAX_DRAG := 12
const DEFINITIONS := {
	"path": {"label": "Stone path", "layer": "ground", "cost": {"stone": 1}},
	"floor": {"label": "Wood floor", "layer": "ground", "cost": {"wood": 1}},
	"wall": {"label": "Timber wall", "layer": "wall", "cost": {"wood": 2}},
	"roof": {"label": "Roof tile", "layer": "roof", "cost": {"wood": 2}},
	"forester": {"label": "Forester", "layer": "object", "cost": {"wood": 4, "stone": 2}},
	"quarry": {"label": "Quarry", "layer": "object", "cost": {"wood": 3, "stone": 2}},
	"farm": {"label": "Farm", "layer": "object", "cost": {"wood": 3}},
	"sawmill": {"label": "Sawmill", "layer": "object", "cost": {"wood": 5, "stone": 3}},
	"home": {"label": "Home", "layer": "object", "cost": {"wood": 6, "plank": 2}},
	"warehouse": {"label": "Warehouse", "layer": "object", "cost": {"wood": 5, "stone": 4}}
}
const RECIPES := {
	"forester": {"duration": 6.0, "output": "wood", "quantity": 2, "site": "tree"},
	"quarry": {"duration": 7.0, "output": "stone", "quantity": 2, "site": "rock"},
	"farm": {"duration": 9.0, "output": "food", "quantity": 3},
	"sawmill": {"duration": 5.0, "output": "plank", "quantity": 5, "input": {"wood": 1}}
}

var seed: int = 2026
var resources: Dictionary = {}
var sites: Dictionary = {}
var buildings: Dictionary = {}
# Each current workshop is a single-cell placeholder plot; its orders outlive worker assignments.
var plots: Dictionary = {}
var villagers: Array[Dictionary] = []
var elapsed: float = 0.0
var needs_elapsed: float = 0.0
var happiness: float = 65.0
var completed_orders: int = 0


func _init(world_seed: int = 2026) -> void:
	reset(world_seed)


func reset(world_seed: int = 2026) -> void:
	seed = world_seed
	resources = {"wood": 28, "stone": 18, "food": 18, "plank": 0}
	sites.clear()
	buildings.clear()
	plots.clear()
	villagers = [
		{"name": "Ayla", "job_key": "", "hunger": 0.0},
		{"name": "Bram", "job_key": "", "hunger": 0.0},
		{"name": "Cora", "job_key": "", "hunger": 0.0}
	]
	elapsed = 0.0
	needs_elapsed = 0.0
	happiness = 65.0
	completed_orders = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	# The central clearing is intentionally buildable.
	for i in range(170):
		var x := rng.randi_range(1, SIZE - 2)
		var z := rng.randi_range(1, SIZE - 2)
		if abs(x - 16) < 6 and abs(z - 16) < 6:
			continue
		var key := cell_key(x, z)
		if sites.has(key):
			continue
		var kind := "tree" if i % 3 != 0 else "rock"
		sites[key] = {"x": x, "z": z, "kind": kind, "amount": 2 + rng.randi_range(0, 3)}


static func cell_key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


static func build_key(x: int, z: int, layer: String) -> String:
	return "%d,%d,%s" % [x, z, layer]


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


static func rectangle_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0: int = mini(a.x, b.x)
	var x1: int = maxi(a.x, b.x)
	var z0: int = mini(a.y, b.y)
	var z1: int = maxi(a.y, b.y)
	if x1 - x0 + 1 > MAX_DRAG or z1 - z0 + 1 > MAX_DRAG:
		return result
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			result.append(Vector2i(x, z))
	return result


func capacity() -> int:
	var warehouses := 0
	for item in buildings.values():
		if item["id"] == "warehouse":
			warehouses += 1
	return 60 + warehouses * 40


func total_cost(kind: String, cells: Array[Vector2i]) -> Dictionary:
	var cost: Dictionary = {}
	if not DEFINITIONS.has(kind):
		return cost
	for item in DEFINITIONS[kind]["cost"].keys():
		cost[item] = int(DEFINITIONS[kind]["cost"][item]) * cells.size()
	return cost


func validate_placement(kind: String, cells: Array[Vector2i]) -> String:
	if not DEFINITIONS.has(kind):
		return "Unknown building"
	if cells.is_empty() or cells.size() > MAX_DRAG * MAX_DRAG:
		return "Selection exceeds 12 x 12"
	var seen := {}
	var layer: String = DEFINITIONS[kind]["layer"]
	for cell in cells:
		if not in_bounds(cell):
			return "Outside settlement"
		var key := build_key(cell.x, cell.y, layer)
		if seen.has(key) or buildings.has(key):
			return "Tile occupied"
		seen[key] = true
		# Natural sites must be gathered before constructing on their cells.
		if sites.has(cell_key(cell.x, cell.y)):
			return "Clear natural resource first"
	for material in total_cost(kind, cells):
		if int(resources.get(material, 0)) < int(total_cost(kind, cells)[material]):
			return "Not enough %s" % material
	return ""


func place(kind: String, cells: Array[Vector2i], rotation: int = 0) -> String:
	var reason := validate_placement(kind, cells)
	if reason != "":
		return reason
	var cost := total_cost(kind, cells)
	for material in cost:
		resources[material] -= int(cost[material])
	for cell in cells:
		var layer: String = DEFINITIONS[kind]["layer"]
		var key := build_key(cell.x, cell.y, layer)
		buildings[key] = {
			"id": kind, "x": cell.x, "z": cell.y,
			"rotation": posmod(rotation, 4), "progress": 0.0
		}
		if RECIPES.has(kind):
			plots[key] = _default_plot(key, kind)
	assign_workers()
	return ""


func remove_building(cell: Vector2i, layer: String) -> bool:
	var key := build_key(cell.x, cell.y, layer)
	if not buildings.has(key):
		return false
	buildings.erase(key)
	plots.erase(key)
	assign_workers()
	return true


func _default_plot(station_key: String, kind: String) -> Dictionary:
	return {
		"station_key": station_key, "type": kind,
		"orders": [{"recipe_id": kind, "active": true, "completed": 0}]
	}


func set_order_active(station_key: String, active: bool) -> bool:
	if not plots.has(station_key):
		return false
	var plot: Dictionary = plots[station_key]
	var orders: Array = plot["orders"]
	if orders.is_empty():
		return false
	var order: Dictionary = orders[0]
	order["active"] = active
	orders[0] = order
	plot["orders"] = orders
	plots[station_key] = plot
	return true


func order_for(station_key: String) -> Dictionary:
	if not plots.has(station_key):
		return {}
	var orders: Array = plots[station_key]["orders"]
	if orders.is_empty():
		return {}
	return orders[0]


func gather(cell: Vector2i) -> String:
	var key := cell_key(cell.x, cell.y)
	if not sites.has(key):
		return "Nothing to gather here"
	var material := "wood" if sites[key]["kind"] == "tree" else "stone"
	if int(resources[material]) >= capacity():
		return "Storage full"
	resources[material] += 1
	var site: Dictionary = sites[key]
	site["amount"] -= 1
	if int(site["amount"]) <= 0:
		sites.erase(key)
	else:
		sites[key] = site
	return ""


func _available_site(station: Dictionary, site_kind: String) -> String:
	var best_key := ""
	var best_distance := 100000
	for key in sites:
		var site: Dictionary = sites[key]
		if site["kind"] != site_kind or int(site["amount"]) <= 0:
			continue
		var distance: int = abs(int(station["x"]) - int(site["x"])) + abs(int(station["z"]) - int(site["z"]))
		if distance <= 7 and distance < best_distance:
			best_distance = distance
			best_key = key
	return best_key


func assign_workers() -> void:
	var stations: Array[String] = []
	for key in plots:
		if buildings.has(key) and RECIPES.has(plots[key]["type"]):
			stations.append(key)
	stations.sort()
	var taken := {}
	for villager in villagers:
		var current: String = villager["job_key"]
		if not stations.has(current) or taken.has(current):
			villager["job_key"] = ""
		else:
			taken[current] = true
	for villager in villagers:
		if villager["job_key"] != "":
			continue
		for key in stations:
			if not taken.has(key):
				villager["job_key"] = key
				taken[key] = true
				break


func worker_name(station_key: String) -> String:
	for villager in villagers:
		if villager["job_key"] == station_key:
			return villager["name"]
	return ""


func job_blocker(station_key: String) -> String:
	if not buildings.has(station_key):
		return "Missing workstation"
	var station: Dictionary = buildings[station_key]
	var kind: String = station["id"]
	if not RECIPES.has(kind) or not plots.has(station_key):
		return "Not a workplace"
	var order := order_for(station_key)
	if order.is_empty() or not bool(order.get("active", false)):
		return "Work order paused"
	if worker_name(station_key) == "":
		return "No worker assigned"
	var recipe_id: String = order["recipe_id"]
	if not RECIPES.has(recipe_id):
		return "Unknown work order"
	var recipe: Dictionary = RECIPES[recipe_id]
	var output: String = recipe["output"]
	if int(resources[output]) + int(recipe["quantity"]) > capacity():
		return "Output storage full"
	for input_kind in recipe.get("input", {}):
		if int(resources.get(input_kind, 0)) < int(recipe["input"][input_kind]):
			return "Missing %s" % input_kind
	if recipe.has("site") and _available_site(station, recipe["site"]) == "":
		return "No nearby %s resources" % recipe["site"]
	return ""


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	assign_workers()
	elapsed += delta
	needs_elapsed += delta
	for key in buildings.keys():
		var station: Dictionary = buildings[key]
		var kind: String = station["id"]
		if not RECIPES.has(kind) or not plots.has(key):
			continue
		if job_blocker(key) != "":
			continue
		var recipe_id: String = order_for(key)["recipe_id"]
		var recipe: Dictionary = RECIPES[recipe_id]
		station["progress"] += delta
		var duration: float = recipe["duration"]
		while station["progress"] >= duration:
			# Recheck each order: sources, inputs, and storage can change.
			if job_blocker(key) != "":
				break
			station["progress"] -= duration
			for input_kind in recipe.get("input", {}):
				resources[input_kind] -= int(recipe["input"][input_kind])
			if recipe.has("site"):
				var site_key := _available_site(station, recipe["site"])
				if site_key != "":
					var site: Dictionary = sites[site_key]
					site["amount"] -= 1
					if int(site["amount"]) <= 0:
						sites.erase(site_key)
					else:
						sites[site_key] = site
			resources[recipe["output"]] += int(recipe["quantity"])
			completed_orders += 1
			var plot: Dictionary = plots[key]
			var orders: Array = plot["orders"]
			var order: Dictionary = orders[0]
			order["completed"] = int(order["completed"]) + 1
			orders[0] = order
			plot["orders"] = orders
			plots[key] = plot
		buildings[key] = station
	while needs_elapsed >= 35.0:
		needs_elapsed -= 35.0
		_apply_needs()


func _apply_needs() -> void:
	var required := villagers.size()
	var beds := 0
	for item in buildings.values():
		if item["id"] == "home":
			beds += 2
	if int(resources["food"]) >= required:
		resources["food"] -= required
		happiness += 2.0 if beds >= required else -1.0
	else:
		resources["food"] = 0
		happiness -= 9.0
	happiness = clampf(happiness, 0.0, 100.0)


func worker_summary() -> Array[String]:
	var rows: Array[String] = []
	for villager in villagers:
		var key: String = villager["job_key"]
		if key == "" or not buildings.has(key):
			rows.append("%s: Idle (no workstation)" % villager["name"])
			continue
		var building: Dictionary = buildings[key]
		var blocker := job_blocker(key)
		var job: String = DEFINITIONS[building["id"]]["label"]
		rows.append("%s: %s — %s" % [villager["name"], job, "Working" if blocker == "" else blocker])
	return rows


func snapshot() -> Dictionary:
	return {
		"schema": 2, "seed": seed, "resources": resources.duplicate(true),
		"sites": sites.duplicate(true), "buildings": buildings.duplicate(true),
		"plots": plots.duplicate(true),
		"villagers": villagers.duplicate(true), "elapsed": elapsed,
		"needs_elapsed": needs_elapsed, "happiness": happiness,
		"completed_orders": completed_orders
	}


func restore(data: Dictionary) -> bool:
	var schema_version := int(data.get("schema", -1))
	if schema_version != 1 and schema_version != 2:
		return false
	if schema_version == 2 and not data.get("plots") is Dictionary:
		return false
	if not data.get("resources") is Dictionary or not data.get("sites") is Dictionary:
		return false
	if not data.get("buildings") is Dictionary or not data.get("villagers") is Array:
		return false
	seed = int(data.get("seed", 2026))
	resources = data["resources"].duplicate(true)
	for material in resources:
		resources[material] = int(resources[material])
	sites = data["sites"].duplicate(true)
	for key in sites:
		var site: Dictionary = sites[key]
		site["x"] = int(site["x"])
		site["z"] = int(site["z"])
		site["amount"] = int(site["amount"])
		sites[key] = site
	buildings = data["buildings"].duplicate(true)
	for key in buildings:
		var building: Dictionary = buildings[key]
		building["x"] = int(building["x"])
		building["z"] = int(building["z"])
		building["rotation"] = int(building["rotation"])
		building["progress"] = float(building["progress"])
		buildings[key] = building
	plots.clear()
	if schema_version == 1:
		for key in buildings:
			var kind: String = buildings[key]["id"]
			if RECIPES.has(kind):
				plots[key] = _default_plot(key, kind)
	else:
		for key in data["plots"]:
			var plot: Dictionary = data["plots"][key].duplicate(true)
			if not buildings.has(key) or not RECIPES.has(plot.get("type", "")):
				return false
			if not plot.get("orders") is Array or plot["orders"].is_empty():
				return false
			var orders: Array = plot["orders"]
			for order in orders:
				if not order is Dictionary or not RECIPES.has(order.get("recipe_id", "")):
					return false
				order["active"] = bool(order.get("active", false))
				order["completed"] = int(order.get("completed", 0))
			plots[key] = plot
	villagers.clear()
	for v in data["villagers"]:
		if v is Dictionary:
			var person: Dictionary = v.duplicate(true)
			person["hunger"] = float(person.get("hunger", 0.0))
			villagers.append(person)
	elapsed = float(data.get("elapsed", 0.0))
	needs_elapsed = float(data.get("needs_elapsed", 0.0))
	happiness = float(data.get("happiness", 65.0))
	completed_orders = int(data.get("completed_orders", 0))
	assign_workers()
	return true
