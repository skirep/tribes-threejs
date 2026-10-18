extends Node3D
## Native OpenXR port. Scene geometry shares the corrected web asset data.
## XRCamera3D is driven only by tracking; camera cuts move its origin once.
const PhoneMotion = preload("res://scripts/phone_motion.gd")
const UNIT := 0.225
const DURATION := 526.0
const MUSIC_CUT := 237.5
const TIMES := [0.0,27.0,42.0,78.0,128.0,164.0,198.0,220.0,237.5,278.0,320.0,372.0,410.0,430.0,478.0,495.0]
const TITLES := ["THE BEGINNING","TRIBES","THE SKY SHIPS","THE PURSUIT","THE ENCOUNTER","THE MARK","BEHIND THE EYES","THE HANDS","THE LOST CITY","THE TEMPLE","THE GATHERING","THE WELL","THE VISION","THE RETURN","FOLLOW THE TRIBE","CREDITS"]
var origin: XROrigin3D
var head: XRCamera3D
var flat_camera: Camera3D
var hud: Label3D
var fade_material: StandardMaterial3D
var world: Node3D
var groups: Array[Node3D] = []
var templates: Dictionary = {}
var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var music: Array[AudioStreamPlayer] = []
var ships: Array[Node3D] = []
var beast: Node3D
var particles: MultiMeshInstance3D
var picture: MeshInstance3D
var eye_tunnel: Node3D
var mask: Node3D
var elapsed := 0.0
var playing := false
var active := -1
var chapter := -1
var fade_time := 0.0
var xr_active := false
var hud_enabled := false
var rng := RandomNumberGenerator.new()
var turn_cooldown := 0.0
var right: XRController3D
var phone_motion := PhoneMotion.new()
var phone_status: Label
var phone_play: Button
var phone_gyro: Button
var phone_seek: HSlider
var phone_canvas: CanvasLayer
var drag_finger := -1
var mouse_dragging := false
var is_scrubbing := false
var muted := false

func _ready() -> void:
	rng.seed = 1997
	world = Node3D.new()
	world.scale = Vector3.ONE * UNIT
	add_child(world)
	_setup_viewer()
	_setup_lighting()
	var credits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/creds.json"))
	var boats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/scene2.json"))
	templates.kid = _original_model(credits,"kid",8.0)
	templates.girl = _original_model(credits,"girl",8.4)
	templates.beast = _original_model(credits,"beast",5.0)
	templates.pet = _original_model(boats,"pet",3.5)
	templates.ship = _original_model(boats,"ship",34.0)
	_build_scenes()
	for path in ["tribes.mp3","stories.mp3"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/" + path)
		player.volume_db = -3.0
		add_child(player)
		music.append(player)
	_animate()
	_update_hud()
	if "--phone-test" in OS.get_cmdline_user_args():
		assert(not xr_active)
		assert(is_instance_valid(phone_play))
		assert(is_instance_valid(phone_seek))
		phone_play.pressed.emit()
		assert(playing)
		phone_play.pressed.emit()
		assert(not playing)
		phone_motion.drag(Vector2(60,-25))
		assert(not phone_motion.view_basis().is_equal_approx(Basis.IDENTITY))
		_center_phone()
		assert(phone_motion.view_basis().is_equal_approx(Basis.IDENTITY))
		_skip(1)
		assert(elapsed == TIMES[1])
		print("PHONE_SMOKE_OK: touch controls, recenter, chapters and camera loaded")
		# Give the audio mixer one cycle to release a just-stopped MP3 voice.
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(0)
		return
	if "--smoke-test" in OS.get_cmdline_user_args():
		for t in TIMES:
			elapsed = t
			_animate()
			assert(is_instance_valid(head))
			assert(active >= 0 and groups[active].visible)
		print("QUEST_SMOKE_OK: all chapters and shared meshes loaded")
		get_tree().quit(0)

func _setup_viewer() -> void:
	origin = XROrigin3D.new()
	add_child(origin)
	head = XRCamera3D.new()
	head.near = 0.05
	head.far = 400.0
	origin.add_child(head)
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		xr_active = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.session_focussed.connect(_session_focused)
		xr.session_visible.connect(_session_unfocused)
		xr.session_stopping.connect(_session_unfocused)
	else:
		flat_camera = Camera3D.new()
		flat_camera.position.y = 1.6
		origin.add_child(flat_camera)
		flat_camera.current = true
		flat_camera.near = 0.05
		flat_camera.far = 400.0
		flat_camera.fov = 75.0
		_setup_phone_controls()
	for hand in ["left_hand","right_hand"]:
		var controller := XRController3D.new()
		controller.tracker = hand
		origin.add_child(controller)
		controller.button_pressed.connect(_controller_button.bind(hand))
		if hand == "right_hand":
			right = controller
	var viewer: Camera3D = head if xr_active else flat_camera
	hud = Label3D.new()
	hud.position = Vector3(0,-0.30,-1.8)
	hud.font_size = 42
	hud.pixel_size = 0.0007
	hud.outline_size = 8
	hud.no_depth_test = true
	viewer.add_child(hud)
	fade_material = StandardMaterial3D.new()
	fade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_material.no_depth_test = true
	fade_material.render_priority = 100
	fade_material.albedo_color = Color(0,0,0,0)
	var curtain := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	curtain.mesh = quad
	curtain.material_override = fade_material
	curtain.position.z = -0.12
	viewer.add_child(curtain)

func _setup_lighting() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("777145")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("ded3ad")
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_color = Color("ffe0b1")
	sun.light_energy = 1.3
	add_child(sun)

func _texture(path: String) -> Texture2D:
	if not texture_cache.has(path):
		texture_cache[path] = load("res://assets/" + path)
	return texture_cache[path]

func _material(path: String, color := Color.WHITE, repeat := 1.0) -> StandardMaterial3D:
	var key := path + str(color) + str(repeat)
	if material_cache.has(key):
		return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	if not path.is_empty():
		mat.albedo_texture = _texture(path)
		mat.albedo_color = Color.WHITE
	mat.uv1_scale = Vector3(repeat,repeat,1)
	material_cache[key] = mat
	return mat

func _matches(name_: String, kind: String) -> bool:
	match kind:
		"kid": return name_.begins_with("KID")
		"girl": return name_.begins_with("GRL") or name_.begins_with("GLASS") or name_.begins_with("GUN")
		"beast": return name_.begins_with("G ") or name_.begins_with("GAF") or name_ == "teeth01"
		"pet": return name_.begins_with("PET")
		"ship": return name_.begins_with("SHIP") or name_.begins_with("Scontour") or name_.begins_with("Spont")
	return false

func _original_model(data: Dictionary, kind: String, height: float) -> Node3D:
	var root := Node3D.new()
	var lo := Vector3(INF,INF,INF)
	var hi := Vector3(-INF,-INF,-INF)
	for piece in data.meshes:
		if not _matches(piece.name,kind):
			continue
		var surfaces: Dictionary = {}
		for face in range(piece.faces.size()/4):
			var mi: int = piece.faces[face*4+3]
			if not surfaces.has(mi):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[mi] = st
			var surface: SurfaceTool = surfaces[mi]
			for corner in [0,2,1]:
				var index: int = piece.faces[face*4+corner]
				var vertex := Vector3(piece.vertices[index*3],piece.vertices[index*3+2],-piece.vertices[index*3+1])
				lo = lo.min(vertex)
				hi = hi.max(vertex)
				var ti: int = piece.uvfaces[face*3+corner] if not piece.uvfaces.is_empty() else index
				var uv := Vector2.ZERO
				if ti*2+1 < piece.uv.size():
					uv = Vector2(piece.uv[ti*2],1.0-piece.uv[ti*2+1])
				surface.set_uv(uv)
				surface.add_vertex(vertex)
		for mi in surfaces:
			var st: SurfaceTool = surfaces[mi]
			st.generate_normals()
			var instance := MeshInstance3D.new()
			instance.mesh = st.commit()
			var material_data: Dictionary = data.materials[mi]
			var color := Color(material_data.color[0],material_data.color[1],material_data.color[2])
			instance.material_override = _material(material_data.texture,color)
			root.add_child(instance)
	assert(root.get_child_count() > 0,"Missing model: " + kind)
	var center := (lo+hi)*0.5
	for child in root.get_children():
		child.position = Vector3(-center.x,-lo.y,-center.z)
	root.scale = Vector3.ONE * height/maxf(hi.y-lo.y,0.01)
	return root

func _clone(kind: String, parent: Node3D, position_: Vector3, size := 1.0, yaw := 0.0) -> Node3D:
	var model: Node3D = templates[kind].duplicate()
	model.position = position_
	model.scale *= size
	model.rotation.y = yaw
	parent.add_child(model)
	return model

func _mesh(parent: Node3D, geometry: Mesh, mat: Material, position_ := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = mat
	instance.position = position_
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, size: Vector3, position_: Vector3, texture: String) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent,box,_material(texture),position_)

func _cylinder(parent: Node3D, top: float, bottom: float, height: float, position_: Vector3, texture: String) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 12
	return _mesh(parent,cylinder,_material(texture),position_)

func _group() -> Node3D:
	var group := Node3D.new()
	group.visible = false
	world.add_child(group)
	groups.append(group)
	return group

func _desert(parent: Node3D) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 600
	sphere.height = 1200
	var sky_mat := _material("sky03.jpg").duplicate() as StandardMaterial3D
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh(parent,sphere,sky_mat)
	var plane := PlaneMesh.new()
	plane.size = Vector2(600,600)
	_mesh(parent,plane,_material("grd6a.jpg",Color.WHITE,18),Vector3(0,-2,0))
	for i in range(35):
		var x := rng.randf_range(-230,230)
		var z := rng.randf_range(-230,230)
		if absf(x)<40 and absf(z)<110:
			continue
		var h := rng.randf_range(20,90)
		_cylinder(parent,8,18,h,Vector3(x,h/2-3,z),"grd6clif.jpg")

func _temple(parent: Node3D) -> void:
	_cylinder(parent,48,53,3,Vector3(0,-1,0),"tplwall.jpg")
	for i in range(12):
		var a := i*TAU/12
		_cylinder(parent,2,2.8,28,Vector3(sin(a)*35,14,cos(a)*35),"tplpil2.jpg")
	_cylinder(parent,43,43,3,Vector3(0,30,0),"tplwall.jpg")
	_cylinder(parent,0,46,16,Vector3(0,39,0),"tplroof.jpg")
	_cylinder(parent,6,9,3,Vector3(0,2,0),"ctytmpl.jpg")

func _build_scenes() -> void:
	var g := _group()
	_desert(g)
	_clone("kid",g,Vector3(0,-1,0),1,PI)
	_clone("pet",g,Vector3(9,-1,2),0.8,-0.8)
	for i in range(3):
		ships.append(_clone("ship",g,Vector3(-80+i*75,22+i*8,-170-i*80),1.3,-0.3))
	g = _group()
	_desert(g)
	beast = _clone("beast",g,Vector3(0,-1,0),1.3,PI/2)
	_clone("girl",g,Vector3(27,4,-22),1,-1)
	for i in range(3):
		_clone("ship",g,Vector3(35+i*45,18+i*6,-55-i*50),1,-0.3)
	g = _group()
	_desert(g)
	_clone("kid",g,Vector3(-5,-1,0),1,1.2)
	_clone("girl",g,Vector3(8,-1,0),1,-1.2)
	_clone("beast",g,Vector3(-15,-1,-8),0.85,1)
	_clone("ship",g,Vector3(42,10,-50),1.2,-0.5)
	g = _group()
	eye_tunnel = Node3D.new()
	g.add_child(eye_tunnel)
	for i in range(25):
		var ring := TorusMesh.new()
		ring.inner_radius = 7.8
		ring.outer_radius = 8.2
		var instance := _mesh(eye_tunnel,ring,_material("eye2.jpg"),Vector3(0,0,-i*5))
		instance.rotation.x = PI/2
	g = _group()
	var quad := QuadMesh.new()
	quad.size = Vector2(26,19.5)
	var picture_mat := _material("handy0.jpg").duplicate() as StandardMaterial3D
	picture_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	picture = _mesh(g,quad,picture_mat)
	g = _group()
	_desert(g)
	for j in range(-4,5):
		for i in range(-4,5):
			if absi(i)<2 and absi(j)<2:
				continue
			var h := rng.randf_range(12,42)
			_box(g,Vector3(12,h,12),Vector3(i*25,h/2-2,j*25),"ctytower.jpg")
			_cylinder(g,0,10,12,Vector3(i*25,h+3,j*25),"ctytmpl.jpg")
	_temple(g)
	_clone("ship",g,Vector3(0,30,100),1,PI)
	g = _group()
	_temple(g)
	_clone("kid",g,Vector3.ZERO)
	_clone("girl",g,Vector3(9,0,9),1,PI)
	particles = MultiMeshInstance3D.new()
	particles.multimesh = MultiMesh.new()
	particles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mote := SphereMesh.new()
	mote.radius = 0.10
	mote.height = 0.20
	mote.radial_segments = 4
	mote.rings = 1
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.albedo_color = Color("ffd473")
	mote.material = mote_mat
	particles.multimesh.mesh = mote
	particles.multimesh.instance_count = 1800
	particles.custom_aabb = AABB(Vector3(-30,-5,-30),Vector3(60,65,60))
	g.add_child(particles)
	g = _group()
	_desert(g)
	var ring := TorusMesh.new()
	ring.inner_radius = 12
	ring.outer_radius = 15
	_mesh(g,ring,_material("tplpil2.jpg"),Vector3(0,7,0))
	_cylinder(g,14,15,6,Vector3(0,3,0),"tplwall.jpg")
	_clone("kid",g,Vector3(0,7,17),1,PI)
	mask = _clone("pet",g,Vector3(0,7,0),2,PI)
	g = _group()
	_desert(g)
	for i in range(3):
		_clone("ship",g,Vector3((i-1)*36,12+i*6,-i*45),1.25)
	var cast := ["kid","girl","pet","beast"]
	for i in range(4):
		_clone(cast[i],g,Vector3((i-1.5)*9,-1,12),0.85,PI)

func _select_scene(index: int) -> void:
	if active == index:
		return
	active = index
	for i in range(groups.size()):
		groups[i].visible = i == index
	# Stationary observer anchors in world coordinates, NOT animated camera paths.
	var eyes := [Vector3(13,9,19),Vector3(20,10,15),Vector3(0,9,20),Vector3(0,0,15),Vector3(0,0,22),Vector3(0,20,120),Vector3(0,9,24),Vector3(23,15,23),Vector3(0,12,40)]
	var targets := [Vector3(0,5,0),Vector3(0,5,-15),Vector3(0,5,0),Vector3(0,0,-100),Vector3.ZERO,Vector3(0,20,0),Vector3(0,10,0),Vector3(0,8,0),Vector3(0,5,10)]
	var eye_position: Vector3 = eyes[index]*UNIT
	origin.position = eye_position - Vector3(0,1.6,0)
	var direction: Vector3 = targets[index]*UNIT-eye_position
	origin.rotation = Vector3(0,atan2(-direction.x,-direction.z),0)
	fade_time = 0.35

func _process(delta: float) -> void:
	if groups.is_empty():
		return
	if playing:
		elapsed = minf(DURATION,elapsed+delta)
		if elapsed >= DURATION:
			playing = false
			_sync_music()
	_animate()
	fade_time = maxf(0,fade_time-delta)
	fade_material.albedo_color.a = clampf(fade_time/0.35,0,1)
	turn_cooldown = maxf(0,turn_cooldown-delta)
	if xr_active and right and turn_cooldown <= 0:
		var stick := right.get_vector2("primary")
		if absf(stick.x)>0.7:
			origin.rotation.y -= signf(stick.x)*PI/6
			turn_cooldown = 0.3
	if not xr_active:
		phone_motion.update(Input.get_gyroscope(),Input.get_gravity(),delta)
		flat_camera.basis = phone_motion.view_basis()
	_update_hud()

func _animate() -> void:
	var t := elapsed
	var next := 0
	if t>=78: next=1
	if t>=128: next=2
	if t>=198: next=3
	if t>=220: next=4
	if t>=237.5: next=5
	if t>=278: next=6
	if t>=372: next=7
	if t>=410: next=4
	if t>=430: next=8
	_select_scene(next)
	var previous_chapter := chapter
	chapter = 0
	for i in range(TIMES.size()):
		if t>=TIMES[i]: chapter=i
	if chapter != previous_chapter:
		_sync_music()
	for i in range(ships.size()):
		ships[i].position = Vector3(sin(t*0.009+i)*100,28+i*8+sin(t*0.4+i),-150+i*55+t*0.65)
	if active==1:
		var q := t-78
		beast.position = Vector3(sin(q*0.12)*12,absf(sin(q*5))*0.65-1,-q*0.7+15)
		beast.rotation.y = PI+cos(q*0.12)*0.3
	if active==3:
		eye_tunnel.rotation.z = (t-198)*0.12
	if active==4:
		var image := "yellohnd.jpg" if t>=410 else ("handy1.jpg" if t>228 else "handy0.jpg")
		picture.material_override.albedo_texture = _texture(image)
	if active==6:
		particles.visible = t>309
		_update_particles(t)
	if active==7:
		mask.position.y = 3+(t-372)*0.32
		mask.rotation.y = (t-372)*0.18

func _update_particles(t: float) -> void:
	for i in range(particles.multimesh.instance_count):
		var a := i*2.399963
		var h := float(i)/particles.multimesh.instance_count
		var radius := 4+9*sin(h*PI)
		var p := Vector3(cos(a+t*0.2)*radius,4+h*24,sin(a+t*0.2)*radius)
		particles.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))

func _sync_music() -> void:
	# A headless runner has no audio mixer callback; validate UI without starting voices.
	if DisplayServer.get_name() == "headless" or music.size()!=2: return
	var selected := 0 if elapsed<MUSIC_CUT else 1
	for i in range(2):
		if i!=selected or not playing:
			music[i].stop()
		else:
			var offset := elapsed if i==0 else elapsed-MUSIC_CUT
			if not music[i].playing or absf(music[i].get_playback_position()-offset)>0.5:
				music[i].play(offset)

func _toggle_play() -> void:
	if elapsed>=DURATION: elapsed=0
	playing = not playing
	_sync_music()

func _skip(direction: int) -> void:
	var target := clampi(chapter+direction,0,TIMES.size()-1)
	elapsed = TIMES[target]
	_animate()
	_sync_music()

func _controller_button(button: String, hand: String) -> void:
	match button:
		"trigger_click","ax_button": _toggle_play()
		"by_button": _skip(1 if hand=="right_hand" else -1)
		"grip_click": hud_enabled = not hud_enabled

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed(): return
	if event is InputEventKey:
		match event.keycode:
			KEY_SPACE: _toggle_play()
			KEY_RIGHT: _skip(1)
			KEY_LEFT: _skip(-1)
			KEY_H: hud_enabled=not hud_enabled

func _update_hud() -> void:
	if not is_instance_valid(hud): return
	hud.visible = xr_active and (not playing or hud_enabled or elapsed<8)
	_update_phone_controls()
	var stamp := "%02d:%02d" % [int(elapsed)/60,int(elapsed)%60]
	var title_: String = TITLES[maxi(chapter,0)]
	if elapsed>=495: title_="PULSE × MELON DEZIGN\nAlex · Unreal · Camel · Antony\nMusic: Scorpik · Falcon"
	hud.text = "TRIBES VR · " + title_ + "\n" + stamp + " / 08:46\nA / trigger: play-pause   B: next   Y: previous\nGrip: info   Right stick: snap turn\nLook around freely · Stationary viewpoint"

func _session_unfocused() -> void:
	playing = false
	_sync_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		playing = false
		mouse_dragging = false
		drag_finger = -1
		_sync_music()

func _session_focused() -> void:
	# Deliberately stays paused after returning from the Quest system menu.
	_update_hud()

func _exit_tree() -> void:
	for template in templates.values():
		template.free()

func _setup_phone_controls() -> void:
	phone_canvas = CanvasLayer.new()
	add_child(phone_canvas)
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_canvas.add_child(layout)
	var header := PanelContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24
	header.offset_top = 12
	header.offset_right = -24
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(header)
	phone_status = Label.new()
	phone_status.add_theme_font_size_override("font_size",22)
	phone_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(phone_status)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -132
	panel.offset_bottom = -14
	layout.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	phone_seek = HSlider.new()
	phone_seek.min_value = 0
	phone_seek.max_value = DURATION
	phone_seek.step = 0.1
	phone_seek.custom_minimum_size.y = 36
	phone_seek.drag_started.connect(func(): is_scrubbing=true)
	phone_seek.drag_ended.connect(func(_changed: bool):
		is_scrubbing=false
		elapsed=phone_seek.value
		_animate()
		_sync_music())
	column.add_child(phone_seek)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	column.add_child(row)
	_phone_button(row,"◀ Anterior",func(): _skip(-1))
	phone_play = _phone_button(row,"Reproduir",_toggle_play)
	_phone_button(row,"Següent ▶",func(): _skip(1))
	_phone_button(row,"Centrar",_center_phone)
	phone_gyro = _phone_button(row,"Gir: ON",func():
		phone_motion.set_enabled(not phone_motion.enabled)
		_update_phone_controls())
	var sound := _phone_button(row,"So: ON",func():
		muted=not muted
		for player in music:
			player.volume_db = -80.0 if muted else -3.0)
	sound.pressed.connect(func(): sound.text="So: OFF" if muted else "So: ON")

func _phone_button(row: HBoxContainer, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0,58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",21)
	button.pressed.connect(callback)
	row.add_child(button)
	return button

func _center_phone() -> void:
	phone_motion.recenter()
	if is_instance_valid(flat_camera):
		flat_camera.basis = Basis.IDENTITY

func _update_phone_controls() -> void:
	if not is_instance_valid(phone_status): return
	var stamp := "%02d:%02d" % [int(elapsed)/60,int(elapsed)%60]
	phone_status.text="TRIBES 360 · " + TITLES[maxi(chapter,0)] + " · " + stamp + "/08:46\nMou el mòbil per mirar · Arrossega amb el dit · Centrar restableix la vista"
	phone_play.text="Pausa" if playing else "Reproduir"
	phone_gyro.text="Gir: ON" if phone_motion.enabled else "Gir: OFF"
	if not is_scrubbing:
		phone_seek.set_value_no_signal(elapsed)

func _unhandled_input(event: InputEvent) -> void:
	if xr_active: return
	# Godot can emulate mouse events from a finger; consume only the real gesture.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.pressed and drag_finger == -1:
			drag_finger=event.index
		elif not event.pressed and event.index==drag_finger:
			drag_finger=-1
	elif event is InputEventScreenDrag and event.index==drag_finger:
		phone_motion.drag(event.relative)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		mouse_dragging=event.pressed
	elif event is InputEventMouseMotion and mouse_dragging:
		phone_motion.drag(event.relative)
