extends RefCounted
## 唯一存档位。路径是 user://saves/slot1.json。

const PATH := "user://saves/slot1.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write_state(state: Dictionary) -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	dir.make_dir_recursive("saves")
	if FileAccess.file_exists(PATH):
		var previous := FileAccess.get_file_as_string(PATH)
		var bak := FileAccess.open(PATH + ".bak", FileAccess.WRITE)
		if bak != null:
			bak.store_string(previous)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state, "\t"))
	return true


static func read_state() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data
	return {}
