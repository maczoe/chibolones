extends SceneTree
## Winnability CLI (design-decisions-v2.md D12): checks every indexed
## board against the baseline inventory and prints one line per board.
## Exit code 0 = every board winnable, 1 = at least one unwinnable board.
## Run: godot --headless --path . --script res://tools/check_boards.gd

var failed := false


func _initialize() -> void:
	_ensure_autoloads()
	_run()


func _run() -> void:
	# The manually installed autoloads run their _ready on the first frame,
	# like every test script in tests/ does.
	await physics_frame
	var content := root.get_node("ContentDB")
	var reports := BoardChecker.check_all(content)
	print("Board winnability vs baseline inventory (%d shots):"
			% BoardChecker.BASELINE_SHOTS)
	for i in reports.size():
		var report: BoardChecker.Report = reports[i]
		var def: BoardDef = content.board_def(i)
		if report.winnable:
			print("OK   %2d %-28s %s in %d shots"
					% [i + 1, def.theme_name, str(report.example), report.shots_needed])
		else:
			failed = true
			print("FAIL %2d %-28s %s" % [i + 1, def.theme_name, report.reason])
	print("BOARDS %s" % ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)


## In --script mode Godot does not register project autoloads; the checker
## only needs ContentDB for the board index.
func _ensure_autoloads() -> void:
	var autoloads := [
		["EventBus", "res://autoload/event_bus.gd"],
		["ContentDB", "res://autoload/content_db.gd"],
	]
	for entry in autoloads:
		if not root.has_node(entry[0]):
			var node: Node = (load(entry[1]) as GDScript).new()
			node.name = entry[0]
			root.add_child(node)
