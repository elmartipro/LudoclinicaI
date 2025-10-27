extends CanvasLayer

signal respondida(correcta: bool)
signal panel_closed
signal panel_opened
signal victoria_alcanzada(total_puntos: int)
signal derrota_alcanzada

const WIN_THRESHOLD = 15

var pregunta_actual: Dictionary
var preguntas_por_categoria: Dictionary
var preguntas_originales: Dictionary
var waiting_for_continue: bool = false
var puntos: int = 0
var vidas: int = 3
var ultima_correcta: bool = true
var icono_vida: String = "✚"

var tiempo_limite: int = 45
var tiempo_restante: int = tiempo_limite

@onready var label_categoria: Label = $Categoria
@onready var label_pregunta: Label = $Pregunta
@onready var label_feedback: RichTextLabel = $Feedback
@onready var label_cronometro: Label = $Cronometro
@onready var botones: Array[Button] = [
    $Card/Opciones/Boton0,
    $Card/Opciones/Boton1,
    $Card/Opciones/Boton2,
    $Card/Opciones/Boton3
]
@onready var timer: Timer = $Card/Timer

@onready var categoria_icon: TextureRect = $Panel/CategoriaIcon
@onready var continue_hint: Label = $ContinueHint

@onready var score_label: Label = $"../Score"
@onready var health_label: Label = $"../Health"

var icon_map: Dictionary = {
    "Epidemiología": preload("res://Assets/Icons/epidemiologia.svg"),
    "Fisiopatología": preload("res://Assets/Icons/fisiopatologia.svg"),
    "Manifestaciones clínicas y paraclínicas": preload("res://Assets/Icons/manifestaciones.svg"),
    "Diagnóstico diferencial": preload("res://Assets/Icons/diagnostico.svg"),
    "Tratamiento": preload("res://Assets/Icons/tratamiento.svg"),
    "Seguimiento": preload("res://Assets/Icons/seguimiento.svg"),
    "Cultura": preload("res://Assets/Icons/cultura.svg"),
    "Health": preload("res://Assets/Icons/health.svg")
}

func _ready() -> void:
    hide()
    _cargar_preguntas()
    _update_score_label()
    _update_health_label()
    if continue_hint:
        continue_hint.visible = false
    if label_feedback:
        label_feedback.bbcode_enabled = true
    for i in range(botones.size()):
        botones[i].pressed.connect(_on_opcion_pressed.bind(i))
    timer.timeout.connect(_on_timer_tick)

func _cargar_preguntas() -> void:
    var file = FileAccess.open("res://UI & Audio/preguntas_etapa_1.json", FileAccess.READ)
    if not file:
        push_error("No se pudo abrir el archivo de preguntas.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Formato JSON no esperado.")
        return
    preguntas_por_categoria = parsed.duplicate(true)
    preguntas_originales = parsed.duplicate(true)

func mostrar_pregunta_de_categoria(cat: String) -> void:
    if not preguntas_por_categoria.has(cat):
        push_error("Categoría no encontrada: " + cat)
        return
    var lista: Array = preguntas_por_categoria[cat]
    if lista.is_empty() and preguntas_originales.has(cat):
        preguntas_por_categoria[cat] = preguntas_originales[cat].duplicate(true)
        lista = preguntas_por_categoria[cat]
    if lista.is_empty():
        push_error("Categoría vacía incluso tras reiniciar: " + cat)
        return
    var idx = randi() % lista.size()
    var pregunta = lista[idx]
    preguntas_por_categoria[cat].remove_at(idx)
    _mostrar_pregunta(pregunta, cat)

func _mostrar_pregunta(p: Dictionary, cat: String) -> void:
    pregunta_actual = p.duplicate(true)
    show()
    panel_opened.emit()
    label_categoria.text = cat
    label_pregunta.text = p["texto"]

    var opciones: Array = []
    for i in range(p["opciones"].size()):
        opciones.append({"texto": p["opciones"][i], "correcta": i == p["respuesta_correcta"]})
    opciones.shuffle()

    pregunta_actual["opciones"] = []
    for i in range(opciones.size()):
        pregunta_actual["opciones"].append(opciones[i]["texto"])
        if opciones[i]["correcta"]:
            pregunta_actual["respuesta_correcta"] = i

    for i in range(botones.size()):
        botones[i].text = "%s) %s" % [char(65 + i), pregunta_actual["opciones"][i]]
        botones[i].disabled = false

    label_feedback.clear()
    waiting_for_continue = false
    _set_continue_hint("", false)

    tiempo_restante = tiempo_limite
    timer.stop()
    timer.wait_time = 1.0
    timer.start()
    label_cronometro.text = str(tiempo_restante)

    if icon_map.has(cat):
        categoria_icon.texture = icon_map[cat]
        categoria_icon.self_modulate = Color.html("#2a7870")
    else:
        categoria_icon.texture = null

func _on_opcion_pressed(index: int) -> void:
    timer.stop()
    ultima_correcta = index == pregunta_actual["respuesta_correcta"]
    var retro = pregunta_actual.get("retroalimentacion", "")

    for boton in botones:
        boton.disabled = true

    label_feedback.clear()
    if ultima_correcta:
        puntos += 1
        _update_score_label()
        label_feedback.append_text("[color=#66bb66]¡Correcto![/color]\n\n")
        if puntos >= WIN_THRESHOLD:
            label_feedback.append_text("[color=#f1c40f]¡Has alcanzado la meta de %d puntos![/color]" % WIN_THRESHOLD)
            respondida.emit(true)
            _trigger_victory()
            return
    else:
        label_feedback.append_text("[color=#cc6666]¡Incorrecto![/color]\n")
        var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])
        label_feedback.append_text("La respuesta correcta era: [color=#66bb66]%s[/color]\n\n" % letra_correcta)

    if retro != "":
        label_feedback.append_text("[color=white]%s[/color]" % retro)

    respondida.emit(ultima_correcta)
    waiting_for_continue = true
    _set_continue_hint("Haz clic o presiona Enter para continuar", true)

func _on_timer_tick() -> void:
    tiempo_restante -= 1
    if tiempo_restante <= 10:
        if tiempo_restante % 2 == 0:
            label_cronometro.add_theme_color_override("font_color", Color.html("#cc6666"))
        else:
            label_cronometro.add_theme_color_override("font_color", Color.html("#68908d"))
    else:
        label_cronometro.add_theme_color_override("font_color", Color.html("#68908d"))

    label_cronometro.text = str(tiempo_restante)

    if tiempo_restante > 0:
        return

    timer.stop()
    for boton in botones:
        boton.disabled = true

    ultima_correcta = false
    var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])

    label_feedback.clear()
    label_feedback.append_text("[color=#cc6666]¡Se acabó el tiempo![/color]\n")
    label_feedback.append_text("La respuesta correcta era: [color=#66bb66]%s[/color]" % letra_correcta)

    respondida.emit(false)
    waiting_for_continue = true
    _set_continue_hint("Haz clic o presiona Enter para continuar", true)

func _unhandled_input(event: InputEvent) -> void:
    if not waiting_for_continue:
        return
    if event is InputEventKey and event.pressed:
        _close_question()
    if event is InputEventMouseButton and event.pressed:
        _close_question()

func _close_question() -> void:
    waiting_for_continue = false
    _set_continue_hint("", false)
    if not ultima_correcta:
        _perder_vida()
        if vidas <= 0:
            return
    hide()
    panel_closed.emit()

func _update_score_label() -> void:
    if score_label:
        score_label.text = "Puntos: %d / %d" % [puntos, WIN_THRESHOLD]

func _update_health_label() -> void:
    if not health_label:
        return
    health_label.text = "Vidas: %s" % _formatear_vidas(vidas)

func _formatear_vidas(total: int) -> String:
    if total <= 0:
        return "—"
    var resultado = []
    for _i in range(total):
        resultado.append(icono_vida)
    return " ".join(resultado)

func _perder_vida() -> void:
    vidas -= 1
    _update_health_label()
    if vidas <= 0:
        _game_over()

func _game_over() -> void:
    timer.stop()
    for boton in botones:
        boton.disabled = true
    waiting_for_continue = false
    hide()
    panel_closed.emit()
    derrota_alcanzada.emit()

func _set_continue_hint(texto: String, mostrar: bool) -> void:
    if not continue_hint:
        return
    continue_hint.text = texto
    continue_hint.visible = mostrar

func _trigger_victory() -> void:
    timer.stop()
    for boton in botones:
        boton.disabled = true
    waiting_for_continue = false
    _set_continue_hint("", false)
    hide()
    panel_closed.emit()
    victoria_alcanzada.emit(puntos)
