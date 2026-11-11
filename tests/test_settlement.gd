extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	_test_seed_determinism()
	_test_atomic_construction()
	_test_finite_harvesting()
	_test_production_and_blockers()
	_test_auto_assignment()
	_test_plot_owned_orders()
	_test_legacy_save_migration()
	_test_needs()
	_test_save_roundtrip()
	if failures > 0:
		printerr("FAILED: %d / %d checks" % [failures, checks])
		quit(1)
	else:
		print("PASS: %d settlement model checks" % checks)
		quit(0)


func check(actual: bool, description: String) -> void:
	checks += 1
	if not actual:
		failures += 1
		printerr("FAIL: " + description)


func _test_seed_determinism() -> void:
	var a := SettlementModel.new(44)
	var b := SettlementModel.new(44)
	check(a.sites == b.sites, "same seed generates identical harvest sites")
	check(a.sites.size() > 40, "map contains natural resources")
	check(not a.sites.has(SettlementModel.cell_key(16, 16)), "spawn clearing is open")


func _test_atomic_construction() -> void:
	var model := SettlementModel.new()
	var cell := Vector2i(16, 16)
	var nearby := Vector2i(17, 16)
	var before := model.resources.duplicate()
	var oversized := SettlementModel.rectangle_cells(Vector2i(1, 1), Vector2i(15, 15))
	check(oversized.is_empty(), "drag larger than 12x12 rejected")
	check(model.place("floor", [cell, nearby]) == "", "valid two-cell drag succeeds")
	check(model.resources["wood"] == int(before["wood"]) - 2, "construction debits per-cell cost")
	check(model.place("floor", [cell]) == "Tile occupied", "same layer cannot overlap")
	check(model.place("wall", [cell]) == "", "walls and floors use different build layers")
	var already_built := model.buildings.size()
	var old_wood: int = model.resources["wood"]
	check(model.place("roof", [Vector2i(14, 14), cell]) == "", "new roof layer allows modular construction")
	var invalid: Array[Vector2i] = [Vector2i(15, 15), Vector2i(-1, 15)]
	check(model.place("floor", invalid) == "Outside settlement", "out-of-world cell blocks entire batch")
	check(model.buildings.size() == already_built + 2, "failed batch placed no partial tiles")
	check(model.resources["wood"] == old_wood - 4, "failed batch spent no resources")
	var too_expensive := SettlementModel.rectangle_cells(Vector2i(6, 6), Vector2i(14, 14))
	check(model.place("floor", too_expensive) != "", "insufficient bulk material stops placement")


func _test_finite_harvesting() -> void:
	var model := SettlementModel.new(23)
	var site: Dictionary = model.sites.values()[0]
	var cell := Vector2i(int(site["x"]), int(site["z"]))
	var original: int = site["amount"]
	var material := "wood" if site["kind"] == "tree" else "stone"
	var before: int = model.resources[material]
	for i in range(original):
		check(model.gather(cell) == "", "manual gather can harvest resource unit %d" % i)
	check(not model.sites.has(SettlementModel.cell_key(cell.x, cell.y)), "site disappears when depleted")
	check(int(model.resources[material]) == before + original, "harvested materials conserved")
	check(model.gather(cell) == "Nothing to gather here", "depleted site cannot be harvested twice")


func _free_station_near_site(model: SettlementModel, site_kind: String) -> Vector2i:
	for site in model.sites.values():
		if site["kind"] != site_kind:
			continue
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cell: Vector2i = Vector2i(int(site["x"]), int(site["z"])) + offset
			if SettlementModel.in_bounds(cell) and not model.sites.has(SettlementModel.cell_key(cell.x, cell.y)):
				return cell
	return Vector2i(-1, -1)


func _test_production_and_blockers() -> void:
	var model := SettlementModel.new(14)
	var forest_pos := _free_station_near_site(model, "tree")
	check(SettlementModel.in_bounds(forest_pos), "find suitable forestry job site")
	if not SettlementModel.in_bounds(forest_pos):
		return
	check(model.place("forester", [forest_pos]) == "", "forester builds")
	var forest_key := SettlementModel.build_key(forest_pos.x, forest_pos.y, "object")
	check(model.job_blocker(forest_key) == "", "worker and nearby trees enable forestry")
	var initial_wood: int = model.resources["wood"]
	model.tick(6.1)
	check(int(model.resources["wood"]) == initial_wood + 2, "forester produces accounted timber")
	check(model.completed_orders == 1, "completed production order recorded")
	# Isolate the sawmill: otherwise the still-active forester would restock wood.
	check(model.remove_building(forest_pos, "object"), "remove forester for independent recipe gate test")
	# Sawmill must stop without ingredients and resume immediately when supplied.
	var mill_pos := Vector2i(16, 16)
	check(model.place("sawmill", [mill_pos]) == "", "sawmill builds")
	var mill_key := SettlementModel.build_key(16, 16, "object")
	model.resources["wood"] = 0
	check(model.job_blocker(mill_key) == "Missing wood", "job UI explains missing inputs")
	var plank_before: int = model.resources["plank"]
	model.tick(10.0)
	check(model.resources["plank"] == plank_before, "blocked sawmill does not make planks")
	model.resources["wood"] = 4
	model.tick(5.1)
	check(model.resources["plank"] == plank_before + 1, "unblocked sawmill consumes timber and produces planks")
	check(model.resources["wood"] <= 2, "sawmill spends input materials")


func _test_auto_assignment() -> void:
	var model := SettlementModel.new()
	for cell in [Vector2i(16, 16), Vector2i(17, 16), Vector2i(16, 17), Vector2i(17, 17)]:
		check(model.place("farm", [cell]) == "", "build staffing test farm")
	var working := 0
	for villager in model.villagers:
		if villager["job_key"] != "":
			working += 1
	check(working == 3, "three villagers fill only three jobs")
	var unstafed := 0
	for key in model.buildings:
		if model.job_blocker(key) == "No worker assigned":
			unstafed += 1
	check(unstafed == 1, "unassigned fourth farm reports reason")


func _test_plot_owned_orders() -> void:
	var model := SettlementModel.new(25)
	var station := Vector2i(16, 16)
	check(model.place("farm", [station]) == "", "farm creates working plot")
	var key := SettlementModel.build_key(station.x, station.y, "object")
	check(model.plots.has(key), "work orders belong to plot entity")
	check(model.order_for(key)["recipe_id"] == "farm", "default farm recipe persists on plot")
	check(model.set_order_active(key, false), "plot work order can be paused")
	check(model.job_blocker(key) == "Work order paused", "paused order is visibly blocked")
	var food_before: int = model.resources["food"]
	model.tick(20.0)
	check(int(model.resources["food"]) == food_before, "paused plot produces nothing")
	model.villagers.clear()
	model.assign_workers()
	check(model.plots.has(key), "orders survive all workers unassigning")
	check(model.order_for(key)["active"] == false, "paused order survives staffing loss")
	check(model.set_order_active(key, true), "plot order can resume without re-creation")
	check(model.job_blocker(key) == "No worker assigned", "unassigned order retains explicit blocker")
	model.villagers.append({"name": "Dara", "job_key": "", "hunger": 0.0})
	model.assign_workers()
	check(model.worker_name(key) == "Dara", "replacement worker inherits plot assignment")
	model.tick(9.1)
	check(model.order_for(key)["completed"] == 1, "completion count stored on plot order")
	var encoded := JSON.stringify(model.snapshot())
	var restored := SettlementModel.new()
	check(restored.restore(JSON.parse_string(encoded)), "plot order saves and loads")
	check(restored.order_for(key) == model.order_for(key), "work order state persists after roundtrip")
	check(restored.remove_building(station, "object"), "workshop can be removed")
	check(not restored.plots.has(key), "removing workshop removes its placeholder plot")


func _test_legacy_save_migration() -> void:
	var model := SettlementModel.new()
	var station := Vector2i(16, 16)
	check(model.place("farm", [station]) == "", "legacy test constructs workshop")
	var legacy: Dictionary = model.snapshot()
	legacy["schema"] = 1
	legacy.erase("plots")
	var migrated := SettlementModel.new()
	check(migrated.restore(JSON.parse_string(JSON.stringify(legacy))), "schema 1 save migrates")
	var key := SettlementModel.build_key(station.x, station.y, "object")
	check(migrated.plots.has(key), "legacy workshop receives default plot")
	check(migrated.order_for(key)["active"], "default migrated order remains active")


func _test_needs() -> void:
	var model := SettlementModel.new()
	model.resources["food"] = 0
	var initial_morale := model.happiness
	model.tick(35.0)
	check(model.happiness < initial_morale, "missing food reduces happiness")
	model.resources["food"] = 10
	model.tick(35.0)
	check(model.resources["food"] == 7, "three villagers consume three food per day cycle")


func _test_save_roundtrip() -> void:
	var model := SettlementModel.new(88)
	check(model.place("path", [Vector2i(16, 16)]) == "", "save test builds path")
	model.tick(9.0)
	var encoded := JSON.stringify(model.snapshot())
	var decoded = JSON.parse_string(encoded)
	var restored := SettlementModel.new()
	check(restored.restore(decoded), "JSON save loads")
	var original := model.snapshot()
	var loaded := restored.snapshot()
	for key in original:
		if original[key] != loaded.get(key):
			printerr("SAVE MISMATCH: %s (original=%s; loaded=%s)" % [str(key), str(original[key]).left(500), str(loaded.get(key)).left(500)])
	check(loaded == original, "snapshot matches after round trip")
	check(not restored.restore({"schema": 999}), "unsupported save schema rejected")
