extends Node

@export var enabled := true
@export var timeout_sec := 2.5

@export var candidates: PackedStringArray = [
	"http://rpi-node-01.local:8787",
	"http://192.168.0.241:8787"
]

var _http: HTTPRequest
var backend_base := ""
var connected := false

func _ready() -> void:
	if not enabled:
		print("[RPI] backend disabled.")
		return

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done)

	_try_index(0)

func _try_index(i: int) -> void:
	if i >= candidates.size():
		print("[RPI] no backend found (safe fallback).")
		return

	var base := candidates[i]
	_http.timeout = timeout_sec
	print("[RPI] Trying:", base + "/ping")
	set_meta("try_i", i)
	set_meta("try_base", base)

	var err := _http.request(base + "/ping")
	if err != OK:
		_try_index(i + 1)

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[RPI] DONE result=", result, " code=", code, " body=", body.get_string_from_utf8())
	var i := int(get_meta("try_i", 0))
	var base := String(get_meta("try_base", ""))

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_try_index(i + 1)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_try_index(i + 1)
		return

	var data := json.data as Dictionary

	if data.get("ok", false):
		backend_base = base
		connected = true
		print("[RPI] Connected:", data)
	else:
		_try_index(i + 1)
