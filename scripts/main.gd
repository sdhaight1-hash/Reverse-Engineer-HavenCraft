extends Node3D

## First playable 3D vertical slice. Procedural geometry is original placeholder art.
const WORLD_HALF := 16.0
const SAVE_FILE := "user://settlement-v1.json"
const PALETTE := [
	"gather", "path", "floor", "wall", "roof",
	"forester", "quarry", "farm", "sawmill", "home", "warehouse"
]

var sim := SettlementModel.new()
var current_tool := "floor"
var placement_rotation := 0
var drag_start := Vector2i(-1, -1)
var drag_end := Vector2i(-1, -1)
var dragging := false
var orbiting := false
var orbit_yaw := 0.65
var orbit_pitch := 0.65
var camera_distance := 13.0
var simulation_speed := 1.0
var player_pos := Vector3(0.0, 0.0, 0.0)
var props_root: Node3D
var builds_root: Node3D
var villagers_root: Node3D
var preview_root: Node3D
var camera: Camera3D
var avatar: Node3D
var resource_label: Label
var town_label: Label
var tool_label: Label
var workers_label: Label
var message_label: Label
var palette_buttons: Dictionary = {}
var villager_nodes: Array[Node3D] = []
var _last_site_count := -1
var _hud_clock := 0.0
var _preview_signature := ""


func _ready() -> void:
	_create_environment()
	_create_player_camera()
	_create_ui()
	_rebuild_sites()
	_rebuild_buildings()
	_create_villagers()
	_update_camera()
	_update_hud()
	_notify("Build a forester near trees, a quarry near rocks, and a sawmill to make planks.")


func _create_environment() -> void:
	var world := Node3D.new()
	world.name = "Environment"
	add_child(world)
	_add_box(world, Vector3(0, -0.24, 0), Vector3(32, 0.45, 32), Color("#56774b"))
	var grid_mesh := ImmediateMesh.new()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(33):
		var coordinate: float = float(i) - WORLD_HALF
		grid_mesh.surface_add_vertex(Vector3(coordinate, 0.015, -WORLD_HALF))
		grid_mesh.surface_add_vertex(Vector3(coordinate, 0.015, WORLD_HALF))
		grid_mesh.surface_add_vertex(Vector3(-WORLD_HALF, 0.015, coordinate))
		grid_mesh.surface_add_vertex(Vector3(WORLD_HALF, 0.015, coordinate))
	grid_mesh.surface_end()
	var grid_instance := MeshInstance3D.new()
	grid_instance.mesh = grid_mesh
	var grid_material := StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.83, 0.91, 0.72, 0.17)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_instance.material_override = grid_material
	world.add_child(grid_instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -35, -20)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)
	var environment := WorldEnvironment.new()
	var sky_env := Environment.new()
	sky_env.background_mode = Environment.BG_COLOR
	sky_env.background_color = Color("#a9cae0")
	sky_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky_env.ambient_light_color = Color("#c4d1c1")
	sky_env.ambient_light_energy = 0.65
	environment.environment = sky_env
	add_child(environment)
	props_root = Node3D.new()
	props_root.name = "NaturalResources"
	add_child(props_root)
	builds_root = Node3D.new()
	builds_root.name = "Construction"
	add_child(builds_root)
	villagers_root = Node3D.new()
	villagers_root.name = "Villagers"
	add_child(villagers_root)
	preview_root = Node3D.new()
	preview_root.name = "BuildPreview"
	add_child(preview_root)


func _create_player_camera() -> void:
	avatar = Node3D.new()
	avatar.name = "Player"
	add_child(avatar)
	_add_box(avatar, Vector3(0, 0.9, 0), Vector3(0.5, 0.9, 0.3), Color("#375878"))
	_add_sphere(avatar, Vector3(0, 1.65, 0), 0.27, Color("#e1b88a"))
	_add_box(avatar, Vector3(-0.17, 0.30, 0), Vector3(0.15, 0.6, 0.2), Color("#282d38"))
	_add_box(avatar, Vector3(0.17, 0.30, 0), Vector3(0.15, 0.6, 0.2), Color("#282d38"))
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62.0
	add_child(camera)


func _make_panel(at: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = Vector2(width, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172421e8")
	style.border_color = Color("#728369")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	$HUD.add_child(panel)
	return column


func _make_label(text_value: String, size: int = 15) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("#f3e6c9"))
	return label


func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var top_left := _make_panel(Vector2(12, 12), 285.0)
	top_left.add_child(_make_label("REVERSE HAVEN  •  PROTOTYPE", 18))
	resource_label = _make_label("")
	top_left.add_child(resource_label)
	town_label = _make_label("")
	top_left.add_child(town_label)
	var top_right := _make_panel(Vector2(945, 12), 320.0)
	top_right.add_child(_make_label("SETTLEMENT OPERATIONS", 18))
	workers_label = _make_label("", 13)
	top_right.add_child(workers_label)
	top_right.add_child(_make_label("Workers automatically staff available workshops. If production stops, the reason appears above.", 12))
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -126
	bottom.offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172421ed")
	style.border_color = Color("#728369")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(9)
	bottom.add_theme_stylebox_override("panel", style)
	canvas.add_child(bottom)
	var bottom_col := VBoxContainer.new()
	bottom.add_child(bottom_col)
	tool_label = _make_label("")
	bottom_col.add_child(tool_label)
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size.y = 49
	bottom_col.add_child(scroller)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	scroller.add_child(bar)
	for kind in PALETTE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(102, 38)
		button.text = "Gather" if kind == "gather" else SettlementModel.DEFINITIONS[kind]["label"]
		button.pressed.connect(_select_tool.bind(kind))
		bar.add_child(button)
		palette_buttons[kind] = button
	message_label = _make_label("WASD move • Right-drag orbit • Scroll zoom • Left-click/drag build • Q pipette • R rotate • P pause plot • F1 speed • F5 save • F9 load", 12)
	bottom_col.add_child(message_label)
	_select_tool(current_tool)


func _add_box(parent: Node3D, center: Vector3, box_size: Vector3, color: Color, translucent: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = 2.0 * radius
	mesh.radial_segments = 9
	mesh.rings = 5
	instance.mesh = mesh
	instance.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, center: Vector3, top_radius: float, bottom_radius: float, height: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 7
	instance.mesh = mesh
	instance.position = center
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	parent.add_child(instance)


func _clear_nodes(parent: Node3D) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _world_at(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) - WORLD_HALF + 0.5, 0.0, float(cell.y) - WORLD_HALF + 0.5)


func _rebuild_sites() -> void:
	_clear_nodes(props_root)
	for site in sim.sites.values():
		var cell := Vector2i(int(site["x"]), int(site["z"]))
		var node := Node3D.new()
		node.position = _world_at(cell)
		props_root.add_child(node)
		if site["kind"] == "tree":
			_add_cylinder(node, Vector3(0, 0.65, 0), 0.11, 0.17, 1.3, Color("#6a4831"))
			_add_sphere(node, Vector3(0, 1.75, 0), 0.59, Color("#356946"))
			_add_sphere(node, Vector3(-0.28, 1.46, 0.2), 0.42, Color("#448054"))
		else:
			_add_sphere(node, Vector3(0, 0.28, 0), 0.48, Color("#8f9288"))
	_last_site_count = sim.sites.size()


func _rebuild_buildings() -> void:
	_clear_nodes(builds_root)
	for building in sim.buildings.values():
		var cell := Vector2i(int(building["x"]), int(building["z"]))
		var piece := Node3D.new()
		piece.position = _world_at(cell)
		piece.rotation.y = float(int(building["rotation"])) * PI / 2.0
		builds_root.add_child(piece)
		_build_piece_mesh(piece, building["id"])


func _build_piece_mesh(node: Node3D, kind: String) -> void:
	match kind:
		"path":
			_add_box(node, Vector3(0, 0.045, 0), Vector3(0.99, 0.09, 0.99), Color("#a5a394"))
		"floor":
			_add_box(node, Vector3(0, 0.09, 0), Vector3(0.99, 0.18, 0.99), Color("#b48756"))
		"wall":
			_add_box(node, Vector3(0, 1.01, -0.43), Vector3(0.99, 2.0, 0.16), Color("#c09a65"))
			_add_box(node, Vector3(-0.39, 1.0, -0.43), Vector3(0.1, 2.05, 0.2), Color("#65452e"))
			_add_box(node, Vector3(0.39, 1.0, -0.43), Vector3(0.1, 2.05, 0.2), Color("#65452e"))
		"roof":
			_add_box(node, Vector3(0, 2.27, 0), Vector3(1.04, 0.22, 1.04), Color("#935547"))
		"forester":
			_add_box(node, Vector3(0, 0.18, 0), Vector3(0.88, 0.36, 0.78), Color("#75543a"))
			_add_cylinder(node, Vector3(0, 0.65, -0.1), 0.08, 0.12, 0.8, Color("#d6b075"))
			_add_sphere(node, Vector3(0, 1.15, -0.1), 0.33, Color("#45815a"))
		"quarry":
			_add_box(node, Vector3(0, 0.15, 0), Vector3(0.95, 0.28, 0.85), Color("#615c52"))
			_add_sphere(node, Vector3(-0.18, 0.55, 0), 0.36, Color("#aba9a1"))
			_add_sphere(node, Vector3(0.25, 0.48, 0.2), 0.24, Color("#8c9691"))
		"farm":
			_add_box(node, Vector3(0, 0.09, 0), Vector3(0.97, 0.17, 0.97), Color("#7b4a30"))
			for i in range(3):
				_add_box(node, Vector3(-0.3 + float(i) * 0.3, 0.30, 0), Vector3(0.12, 0.32, 0.72), Color("#90a64d"))
		"sawmill":
			_add_box(node, Vector3(0, 0.31, 0), Vector3(0.95, 0.6, 0.8), Color("#92653c"))
			_add_box(node, Vector3(0, 0.72, 0), Vector3(0.85, 0.12, 0.67), Color("#cfaa6c"))
			_add_box(node, Vector3(0, 0.93, 0), Vector3(0.06, 0.38, 0.56), Color("#b2b9bc"))
		"home":
			_add_box(node, Vector3(0, 0.75, 0), Vector3(0.93, 1.5, 0.95), Color("#caaf83"))
			_add_box(node, Vector3(0, 1.62, 0), Vector3(1.13, 0.32, 1.15), Color("#844c40"))
			_add_box(node, Vector3(0, 0.5, 0.49), Vector3(0.32, 0.98, 0.06), Color("#594534"))
		"warehouse":
			_add_box(node, Vector3(0, 0.73, 0), Vector3(0.95, 1.45, 0.95), Color("#81725b"))
			_add_box(node, Vector3(0, 1.5, 0), Vector3(1.1, 0.16, 1.1), Color("#b69a6a"))
			_add_box(node, Vector3(0, 0.45, 0.49), Vector3(0.48, 0.85, 0.06), Color("#684d37"))


func _create_villagers() -> void:
	_clear_nodes(villagers_root)
	villager_nodes.clear()
	var colors := [Color("#c8975f"), Color("#7d9ab5"), Color("#bc7780")]
	for i in range(sim.villagers.size()):
		var npc := Node3D.new()
		npc.position = Vector3(float(i) * 1.1 - 1.0, 0.0, -1.8)
		villagers_root.add_child(npc)
		_add_box(npc, Vector3(0, 0.65, 0), Vector3(0.37, 0.75, 0.27), colors[i % colors.size()])
		_add_sphere(npc, Vector3(0, 1.22, 0), 0.23, Color("#e6be95"))
		var name_tag := Label3D.new()
		name_tag.name = "NameTag"
		name_tag.text = sim.villagers[i]["name"]
		name_tag.position = Vector3(0, 1.73, 0)
		name_tag.font_size = 32
		name_tag.pixel_size = 0.006
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		npc.add_child(name_tag)
		villager_nodes.append(npc)


func _update_villagers(delta: float) -> void:
	for i in range(mini(villager_nodes.size(), sim.villagers.size())):
		var npc := villager_nodes[i]
		var target := Vector3(float(i) * 1.1 - 1.0, 0.0, -1.8)
		var key: String = sim.villagers[i]["job_key"]
		if sim.buildings.has(key):
			var workplace: Dictionary = sim.buildings[key]
			target = _world_at(Vector2i(int(workplace["x"]), int(workplace["z"])))
			target.x += 0.5
		npc.position = npc.position.move_toward(target, delta * 2.25)
		var tag: Label3D = npc.get_node("NameTag")
		var blocker := sim.job_blocker(key) if key != "" else "Idle"
		tag.text = "%s • %s" % [sim.villagers[i]["name"], "Working" if blocker == "" else blocker]


func _update_camera() -> void:
	avatar.position = player_pos
	var horizontal := cos(orbit_pitch) * camera_distance
	var offset := Vector3(sin(orbit_yaw) * horizontal, sin(orbit_pitch) * camera_distance + 1.3, cos(orbit_yaw) * horizontal)
	camera.position = player_pos + offset
	camera.look_at(player_pos + Vector3(0, 1.15, 0), Vector3.UP)


func _move_player(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if input_vector == Vector2.ZERO:
		return
	input_vector = input_vector.normalized()
	var forward := Vector3(-sin(orbit_yaw), 0, -cos(orbit_yaw))
	var right := Vector3(cos(orbit_yaw), 0, -sin(orbit_yaw))
	var displacement := (right * input_vector.x - forward * input_vector.y) * delta * 5.0
	player_pos.x = clampf(player_pos.x + displacement.x, -15.5, 15.5)
	player_pos.z = clampf(player_pos.z + displacement.z, -15.5, 15.5)
	avatar.rotation.y = atan2(-displacement.x, -displacement.z)


func _process(delta: float) -> void:
	_move_player(delta)
	_update_camera()
	sim.tick(delta * simulation_speed)
	if sim.sites.size() != _last_site_count:
		_rebuild_sites()
	_update_villagers(delta)
	if dragging:
		drag_end = _pointed_cell()
	_update_preview()
	_hud_clock += delta
	if _hud_clock > 0.35:
		_hud_clock = 0.0
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = maxf(camera_distance - 1.3, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = minf(camera_distance + 1.3, 26.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start = _pointed_cell()
				drag_end = drag_start
				dragging = SettlementModel.in_bounds(drag_start)
			elif dragging:
				_commit_build()
				dragging = false
				_preview_signature = ""
	elif event is InputEventMouseMotion and orbiting:
		orbit_yaw -= event.relative.x * 0.009
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.007, 0.18, 1.30)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_pipette()
			KEY_R:
				placement_rotation = posmod(placement_rotation + 1, 4)
				_preview_signature = ""
			KEY_P:
				var cell := _pointed_cell()
				var station_key := SettlementModel.build_key(cell.x, cell.y, "object")
				if sim.plots.has(station_key):
					var active: bool = bool(sim.order_for(station_key).get("active", false))
					sim.set_order_active(station_key, not active)
					_notify("Plot order %s" % ("resumed" if active == false else "paused"))
					_update_hud()
				else:
					_notify("Point at a workshop to pause/resume its order")
			KEY_F1:
				simulation_speed = 1.0 if simulation_speed > 1.0 else 8.0
				_notify("Simulation: %dx" % int(simulation_speed))
			KEY_F5:
				_save_game()
			KEY_F9:
				_load_game()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_select_tool(PALETTE[int(event.keycode) - KEY_1])


func _pointed_cell() -> Vector2i:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector2i(-1, -1)
	var hit := origin + direction * distance
	return Vector2i(int(floor(hit.x + WORLD_HALF)), int(floor(hit.z + WORLD_HALF)))


func _selection_cells() -> Array[Vector2i]:
	var focus := drag_end if dragging else _pointed_cell()
	var start := drag_start if dragging else focus
	if not SettlementModel.in_bounds(start) or not SettlementModel.in_bounds(focus):
		return []
	if current_tool == "gather":
		return [focus]
	return SettlementModel.rectangle_cells(start, focus)


func _update_preview() -> void:
	var cells := _selection_cells()
	var signature := current_tool + ":" + str(cells) + ":" + str(placement_rotation)
	if signature == _preview_signature:
		return
	_preview_signature = signature
	_clear_nodes(preview_root)
	if cells.is_empty():
		return
	var reason := ""
	if current_tool == "gather":
		if not sim.sites.has(SettlementModel.cell_key(cells[0].x, cells[0].y)):
			reason = "No natural resource"
	else:
		reason = sim.validate_placement(current_tool, cells)
	var tint := Color(0.23, 0.92, 0.74, 0.42) if reason == "" else Color(0.94, 0.33, 0.24, 0.45)
	for cell in cells:
		var position := _world_at(cell)
		position.y = 0.25
		_add_box(preview_root, position, Vector3(0.96, 0.48, 0.96), tint, true)


func _commit_build() -> void:
	var cells := _selection_cells()
	if cells.is_empty():
		_notify("Invalid selection; drag maximum is 12 x 12.")
		return
	if current_tool == "gather":
		var result := sim.gather(cells[0])
		_notify("Gathered a natural resource." if result == "" else result)
		if result == "":
			_rebuild_sites()
	else:
		var result := sim.place(current_tool, cells, placement_rotation)
		if result == "":
			_notify("Built %d × %s." % [cells.size(), SettlementModel.DEFINITIONS[current_tool]["label"]])
			_rebuild_buildings()
		else:
			_notify(result)
	_preview_signature = ""
	_update_hud()


func _pipette() -> void:
	var cell := _pointed_cell()
	if not SettlementModel.in_bounds(cell):
		return
	for layer in ["object", "roof", "wall", "ground"]:
		var key := SettlementModel.build_key(cell.x, cell.y, layer)
		if sim.buildings.has(key):
			_select_tool(sim.buildings[key]["id"])
			return


func _select_tool(kind: String) -> void:
	if kind != "gather" and not SettlementModel.DEFINITIONS.has(kind):
		return
	current_tool = kind
	dragging = false
	_preview_signature = ""
	for name in palette_buttons:
		palette_buttons[name].modulate = Color("#b1eec5") if name == kind else Color.WHITE
	_update_hud()


func _notify(message: String) -> void:
	if message_label != null:
		message_label.text = message


func _update_hud() -> void:
	if resource_label == null:
		return
	var r := sim.resources
	resource_label.text = "Wood %d    Stone %d    Food %d    Planks %d\nStorage: %d / resource" % [
		int(r["wood"]), int(r["stone"]), int(r["food"]), int(r["plank"]), sim.capacity()
	]
	town_label.text = "Population: %d    Happiness: %d%%\nDay %d    Work orders: %d    Clock: %dx" % [
		sim.villagers.size(), int(sim.happiness), int(sim.elapsed / 120.0) + 1,
		sim.completed_orders, int(simulation_speed)
	]
	var worker_text := ""
	for line in sim.worker_summary():
		worker_text += line + "\n"
	workers_label.text = worker_text
	if current_tool == "gather":
		tool_label.text = "GATHER  •  click trees / rocks to collect finite resources"
	else:
		var definition: Dictionary = SettlementModel.DEFINITIONS[current_tool]
		tool_label.text = "BUILD  •  %s  •  %s each  •  R rotates" % [
			definition["label"], str(definition["cost"])
		]


func _save_game() -> void:
	var data := sim.snapshot()
	data["player_x"] = player_pos.x
	data["player_z"] = player_pos.z
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		_notify("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_notify("Saved to %s" % SAVE_FILE)


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		_notify("No saved game found")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not parsed is Dictionary or not sim.restore(parsed):
		_notify("Save invalid or unsupported")
		return
	player_pos = Vector3(float(parsed.get("player_x", 0)), 0, float(parsed.get("player_z", 0)))
	_rebuild_sites()
	_rebuild_buildings()
	_create_villagers()
	_preview_signature = ""
	_notify("Loaded settlement")
