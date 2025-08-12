extends HSlider


@export var audio_bus_name: String = "Master"

var audio_bus_id
const CONFIG_PATH := "user://config.cfg"

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	if audio_bus_id == -1:
		push_error("Bus de audio no encontrado: " + audio_bus_name)
		return
	var volumen = cargar_volumen()
	value = volumen
	AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(volumen))
	connect("value_changed", Callable(self, "_on_value_changed")) 

func _on_value_changed(value: float) -> void:
	if audio_bus_id == -1:
		return
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)
	guardar_volumen(value)

func guardar_volumen(valor: float) -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK:
		print("Creando nuevo archivo de configuración.")
	config.set_value("audio", audio_bus_name, valor)
	config.save(CONFIG_PATH)

func cargar_volumen() -> float:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		return config.get_value("audio", audio_bus_name, 1.0)
	return 1.0
