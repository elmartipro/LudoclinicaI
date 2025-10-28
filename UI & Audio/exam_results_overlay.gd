extends CanvasLayer

signal overlay_cerrado

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: Panel = $CenterContainer/Panel
@onready var titulo_label: Label = $CenterContainer/Panel/VBoxContainer/TituloLabel
@onready var resumen_label: Label = $CenterContainer/Panel/VBoxContainer/ResumenLabel
@onready var categorias_label: RichTextLabel = $CenterContainer/Panel/VBoxContainer/CategoriasLabel
@onready var intentos_label: RichTextLabel = $CenterContainer/Panel/VBoxContainer/IntentosPreviosLabel
@onready var historial_container: Control = $CenterContainer/Panel/VBoxContainer/HistorialContainer
@onready var historial_label: RichTextLabel = $CenterContainer/Panel/VBoxContainer/HistorialContainer/HistorialLabel
@onready var historial_button: Button = $CenterContainer/Panel/VBoxContainer/HistorialButton
@onready var cerrar_button: Button = $CenterContainer/Panel/VBoxContainer/CerrarButton

var historial_visible: bool = false

func _ready() -> void:
	hide()
	historial_container.visible = false
	historial_button.pressed.connect(_on_historial_button_pressed)
	cerrar_button.pressed.connect(_on_cerrar_button_pressed)

func mostrar_resumen(resumen: Dictionary, historial_detallado: Array, intentos_previos: Array) -> void:
	historial_visible = false
	historial_container.visible = false
	var aciertos: int = resumen.get("aciertos", 0)
	var total: int = max(resumen.get("total", 0), 1)
	var porcentaje: float = resumen.get("porcentaje", float(aciertos) / float(total) * 100.0)
	var tiempo_total: float = resumen.get("tiempo_total", 0.0)
	var promedio: float = resumen.get("promedio", 0.0)
	titulo_label.text = "Resultados del modo examen"
	var resumen_texto: String = "Aciertos: %d / %d (%.2f%%)\n" % [aciertos, total, porcentaje]
	resumen_texto += "Tiempo total: %s\n" % _formatear_tiempo(tiempo_total)
	resumen_texto += "Promedio por pregunta: %s" % _formatear_tiempo(promedio)
	resumen_label.text = resumen_texto
	categorias_label.bbcode_enabled = true
	categorias_label.clear()
	var categoria_stats: Dictionary = resumen.get("categorias", {})
	if categoria_stats.is_empty():
		categorias_label.text = "Sin datos de categorías"
	else:
		var mejor: String = _categoria_mejor(categoria_stats)
		var peor: String = _categoria_peor(categoria_stats)
		var texto: String = "[b]Desempeño por categoría[/b]\n"
		var categorias: Array = categoria_stats.keys()
		categorias.sort()
		for categoria in categorias:
			var datos: Dictionary = categoria_stats[categoria]
			var cor: int = datos.get("correctas", 0)
			var tot: int = max(datos.get("total", 0), 1)
			var perc: float = float(cor) / float(tot) * 100.0
			texto += "%s: %d/%d (%.1f%%)\n" % [categoria, cor, tot, perc]
		texto += "\n[b]Mayor acierto:[/b] %s\n" % mejor
		texto += "[b]Mayor dificultad:[/b] %s" % peor
		categorias_label.text = texto
	_historial_formatear(historial_detallado)
	_mostrar_intentos_previos(intentos_previos)
	historial_container.visible = historial_visible
	if historial_visible:
		historial_button.text = "Ocultar historial"
	else:
		historial_button.text = "Ver historial detallado"
	show()
	panel.grab_focus()

func _historial_formatear(historial: Array) -> void:
	historial_label.bbcode_enabled = true
	if historial.size() == 0:
		historial_label.text = "No hay respuestas para mostrar"
		return
	var texto: String = "[b]Historial de respuestas[/b]\n"
	for entrada in historial:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var categoria: String = entrada.get("categoria", "")
		var pregunta: String = entrada.get("pregunta", "")
		var correcta: bool = entrada.get("correcta", false)
		var resp_jugador: String = entrada.get("respuesta_jugador", "Sin respuesta")
		var resp_correcta: String = entrada.get("respuesta_correcta", "")
		var tiempo: float = entrada.get("tiempo", 0.0)
		var estado: String = "❌"
		if correcta:
			estado = "✅"
		texto += "%s [%s] %s\n" % [estado, categoria, pregunta]
		texto += "    Tu respuesta: %s\n" % resp_jugador
		texto += "    Correcta: %s\n" % resp_correcta
		texto += "    Tiempo: %s\n\n" % _formatear_tiempo(tiempo)
	historial_label.text = texto

func _mostrar_intentos_previos(intentos: Array) -> void:
	intentos_label.bbcode_enabled = true
	if intentos.size() == 0:
		intentos_label.text = "Sin intentos anteriores"
		return
	var texto: String = "[b]Intentos anteriores[/b]\n"
	for intento in intentos:
		if typeof(intento) != TYPE_DICTIONARY:
			continue
		var fecha: String = intento.get("fecha", "")
		var aciertos: int = intento.get("aciertos", 0)
		var total: int = max(intento.get("total", 0), 1)
		var porcentaje: float = float(aciertos) / float(total) * 100.0
		var tiempo: float = intento.get("tiempo_total", 0.0)
		texto += "%s → %d/%d (%.1f%%) en %s\n" % [fecha, aciertos, total, porcentaje, _formatear_tiempo(tiempo)]
	intentos_label.text = texto

func _on_historial_button_pressed() -> void:
	historial_visible = not historial_visible
	historial_container.visible = historial_visible
	if historial_visible:
		historial_button.text = "Ocultar historial"
	else:
		historial_button.text = "Ver historial detallado"

func _on_cerrar_button_pressed() -> void:
	hide()
	overlay_cerrado.emit()

func _formatear_tiempo(segundos: float) -> String:
	var total_segundos: float = max(segundos, 0.0)
	var minutos: int = int(total_segundos) / 60
	var resto_segundos: float = total_segundos - float(minutos * 60)
	return "%02d:%05.2f" % [minutos, resto_segundos]

func _categoria_mejor(datos: Dictionary) -> String:
	var mejor_categoria: String = ""
	var mejor_valor: float = -1.0
	for categoria in datos.keys():
		var info: Dictionary = datos[categoria]
		var tot: int = max(info.get("total", 0), 1)
		var cor: int = info.get("correctas", 0)
		var perc: float = float(cor) / float(tot)
		if perc > mejor_valor:
			mejor_valor = perc
			mejor_categoria = categoria
	return mejor_categoria

func _categoria_peor(datos: Dictionary) -> String:
	var peor_categoria: String = ""
	var peor_valor: float = 2.0
	for categoria in datos.keys():
		var info: Dictionary = datos[categoria]
		var tot: int = max(info.get("total", 0), 1)
		var cor: int = info.get("correctas", 0)
		var perc: float = float(cor) / float(tot)
		if perc < peor_valor:
			peor_valor = perc
			peor_categoria = categoria
	return peor_categoria
