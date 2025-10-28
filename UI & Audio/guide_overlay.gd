extends CanvasLayer

signal overlay_closed

@onready var dimmer: ColorRect = $Dimmer
@onready var close_button: BaseButton = $"CenterContainer/Panel/MarginContainer/VBox/Header/CloseButton"
@onready var map_container: VBoxContainer = $"CenterContainer/Panel/MarginContainer/VBox/Body/MapPanel/MapVBox/MapScroll/MapVBox"
@onready var content_scroll: ScrollContainer = $"CenterContainer/Panel/MarginContainer/VBox/Body/ContentScroll"
@onready var content_container: VBoxContainer = $"CenterContainer/Panel/MarginContainer/VBox/Body/ContentScroll/ContentVBox"
@onready var panel: Panel = $"CenterContainer/Panel"

var is_open: bool = false
var pause_applied: bool = false
var section_lookup: Dictionary = {}

const ACCENT_COLOR: Color = Color(0.207843, 0.564706, 0.52549)
const MUTED_COLOR: Color = Color(0.62, 0.7, 0.78)
const FLOW_NODES: Array = [
	{
		"tag": "Inicio",
		"title": "Resumen",
		"summary": "Visión general, objetivo y público.",
		"section_id": "resumen"
	},
	{
		"tag": "Contexto",
		"title": "Introducción",
		"summary": "Definición, historia y mortalidad con/sin dantroleno.",
		"section_id": "introduccion",
		"children": [
			{
				"title": "Epidemiología",
				"summary": "Herencia, incidencia, edad, sexo y expresividad.",
				"section_id": "epidemiologia"
			},
			{
				"title": "Disparadores",
				"summary": "Succinilcolina, inhalados potentes, diferenciación con SNM.",
				"section_id": "disparadores"
			}
		]
	},
	{
		"tag": "Mecanismo",
		"title": "Fisiopatología",
		"summary": "RYR1 / CACNA1S, calcio y hipermetabolismo.",
		"section_id": "fisiopatologia"
	},
	{
		"tag": "Clínica",
		"title": "Presentación clínica",
		"summary": "Rigidez, hipercapnia, taquicardia, trismo.",
		"section_id": "presentacion",
		"children": [
			{
				"title": "Manifestaciones paraclínicas",
				"summary": "Acidemia, CK, mioglobinuria, K+.",
				"section_id": "paraclinicos"
			},
			{
				"title": "Diagnóstico diferencial",
				"summary": "Infección, tirotoxicosis, feo, iatrogenia, SNM…",
				"section_id": "diferencial"
			}
		]
	},
	{
		"tag": "Manejo",
		"title": "Tratamiento de la crisis",
		"summary": "Dantroleno IV, soporte, enfriamiento, monitorización.",
		"section_id": "tratamiento"
	},
	{
		"tag": "Diagnóstico",
		"title": "Diagnóstico de susceptibilidad",
		"summary": "CHCT/IVCT, genética (RYR1), sensibilidad.",
		"section_id": "susceptibilidad"
	},
	{
		"tag": "Asociaciones",
		"title": "Asociación con otras miopatías",
		"summary": "Miopatía de núcleo central, King–Denborough…",
		"section_id": "asociaciones"
	},
	{
		"tag": "Perioperatorio",
		"title": "Anestesia en pacientes susceptibles",
		"summary": "TIVA, preparación máquina < 5 ppm, filtros carbón.",
		"section_id": "anestesia"
	},
	{
		"tag": "Orientación",
		"title": "Orientación a pacientes y familiares",
		"summary": "Educación, alerta médica y pruebas en familiares.",
		"section_id": "orientacion"
	},
	{
		"tag": "Cierre",
		"title": "Conclusiones",
		"summary": "Disponibilidad de dantroleno + reconocimiento precoz.",
		"section_id": "conclusiones"
	},
	{
		"tag": "Referencias",
		"title": "Bibliografía y recursos",
		"summary": "Artículos clave, guías EMHG, MHAUS.",
		"section_id": "bibliografia"
	}
]

const SECTION_CONTENT: Array = [
	{
		"id": "resumen",
		"title": "Resumen",
		"paragraphs": [
			"Este documento académico tiene como objetivo proporcionar una visión general sobre la hipertermia maligna (HM), un síndrome hipermetabólico de origen genético que representa una emergencia anestésica crítica. La intención principal es consolidar y aplicar conocimientos clave en fisiología, farmacología, genética y medicina perioperatoria, mediante el estudio estructurado de esta entidad clínica altamente relevante.",
			"A través de una revisión de la literatura científica actual, se busca reforzar la comprensión teórica del síndrome, promover el reconocimiento precoz de sus manifestaciones clínicas y paraclínicas, y presentar las estrategias terapéuticas y preventivas basadas en evidencia. Este enfoque formativo permite al lector integrar los conceptos fundamentales en el contexto de la práctica clínica y prepararse para la toma de decisiones ante eventos potencialmente fatales.",
			"El contenido está dirigido a estudiantes avanzados de medicina, profesionales en formación y especialistas del área quirúrgica y anestésica, y pretende servir como herramienta educativa útil para la actualización, la reflexión académica y el fortalecimiento de competencias en el manejo seguro del paciente en el entorno perioperatorio."
		]
	},
	{
		"id": "introduccion",
		"title": "Introducción",
		"paragraphs": [
			"La Hipertermia Maligna (HM) es un síndrome farmacogenético hipermetabólico agudo que se desencadena en individuos genéticamente predispuestos por la exposición a la succinilcolina o a anestésicos inhalados potentes (con la excepción del óxido nitroso). Su inicio puede ser fulminante y tener un curso rápido, caracterizándose por signos como rigidez muscular, hipercapnia y un aumento de la temperatura corporal. Sin un tratamiento específico y oportuno, estos signos pueden progresar en menos de una hora a un trastorno metabólico irreversible, usualmente letal.",
			"Históricamente, la mortalidad de la HM sin tratamiento se acercaba al 65%. Sin embargo, con el reconocimiento temprano y el tratamiento adecuado, incluyendo la administración intravenosa de dantroleno, la mortalidad se ha reducido significativamente, estimándose en la actualidad entre el 4 y el 10% en países desarrollados.",
			"Los primeros reportes de HM se realizaron en la década de 1960 por el grupo de Michael A. Denborough en Australia. El primer caso descrito en 1960 involucró a un paciente con antecedentes familiares de muertes durante la anestesia general con halotano, quien sobrevivió a pesar de no recibir tratamiento específico. En 1970, se desarrolló la prueba de contractura con cafeína y halotano (CHCT). En 1975 se estableció el dantroleno como tratamiento efectivo, especialmente en su forma endovenosa."
		]
	},
	{
		"id": "epidemiologia",
		"title": "Epidemiología",
		"info_grid": [
			{
				"title": "Genética y herencia",
				"text": "Herencia autosómica dominante, expresividad variable y penetrancia incompleta. Prevalencia estimada del trastorno genético entre 1:3.000 y 1:8.500."
			},
			{
				"title": "Incidencia",
				"text": "Crisis durante anestesia general de 1:5.000 a 1:100.000. Mayor incidencia reportada en niños (≈4×), con escasa presentación en neonatos y ancianos."
			},
			{
				"title": "Distribución por edad/sexo",
				"text": "Promedio de edad de 18 años al momento de la crisis. Incidencia igual por sexo hasta la adolescencia, luego más común en hombres."
			},
			{
				"title": "Otros",
				"text": "Crisis en cualquier momento perioperatorio, incluso postoperatorio tardío. La incidencia real puede estar subestimada por casos leves no diagnosticados."
			}
		]
	},
	{
		"id": "disparadores",
		"title": "Disparadores de la Hipertermia Maligna",
		"bullets": [
			"[b]Clásicos:[/b] Succinilcolina y anestésicos inhalados potentes (halotano, isoflurano, sevoflurano, desflurano).",
			"[b]No disparador:[/b] Óxido nitroso.",
			"[b]Modelos animales:[/b] En porcinos: agonistas alfa, ejercicio y estrés pueden desencadenar HM.",
			"[b]Humanos:[/b] Sin evidencia de que vasopresores, hipercapnia, hipercalcemia o digoxina sean disparadores."
		],
		"paragraphs": [
			"[b]Diferenciar de SNM:[/b] reacción hipermetabólica por neurolépticos; clínica similar pero fisiopatología distinta. Se han reportado pruebas de contractura positivas tras SNM."
		]
	},
	{
		"id": "fisiopatologia",
		"title": "Fisiopatología",
		"paragraphs": [
			"Alteración en la regulación del calcio del músculo esquelético por mutaciones en [i]RYR1[/i] y la subunidad alfa del receptor de dihidropiridina ([i]CACNA1S[/i]). Ante desencadenantes, el RYR1 permite liberación masiva y sostenida de Ca[sup]2+[/sup] al citosol, con contracciones incontroladas y un hipermetabolismo acelerado."
		],
		"bullets": [
			"↑ Consumo de O[sub]2[/sub] y ↑ producción de CO[sub]2[/sub].",
			"Acidosis láctica, ↑ temperatura corporal.",
			"Rabdomiólisis: ↑ CK y mioglobinuria.",
			"↑ Gasto cardíaco y consumo de O[sub]2[/sub] miocárdico."
		],
		"paragraphs_tail": [
			"La termorregulación central permanece intacta; la hipertermia es consecuencia del trabajo muscular y calor excesivo por contractura generalizada."
		]
	},
	{
		"id": "presentacion",
		"title": "Presentación clínica",
		"paragraphs": [
			"La variabilidad genética y penetrancia incompleta explican presentaciones irregulares. Usualmente durante las dos primeras horas de anestesia, pero también tardía."
		],
		"bullets": [
			"[b]Primeros signos:[/b] rigidez muscular, taquicardia sinusal, hipertensión e hipercapnia (frecuentemente el primer hallazgo por ETCO[sub]2[/sub]).",
			"[b]Piel:[/b] moteada, cianosis/parches eritematosos.",
			"[b]Trismo (espasmo masetero):[/b] tras succinilcolina; ≈50% de niños con trismo presentan susceptibilidad.",
			"[b]Mejor predictor aislado de CHCT positivo:[/b] rigidez muscular generalizada."
		]
	},
	{
		"id": "paraclinicos",
		"title": "Manifestaciones paraclínicas",
		"bullets": [
			"Acidemia severa (respiratoria y metabólica) precede a la hipertermia.",
			"↑ CK y mioglobinuria (rabdomiólisis).",
			"Hiperkalemia progresiva."
		]
	},
	{
		"id": "diferencial",
		"title": "Diagnóstico diferencial",
		"table_headers": [
			"Diagnóstico",
			"Comentario"
		],
		"table_rows": [
			[
				"Cuadro infeccioso o séptico",
				"La fiebre intraanestésica es rara; considerar el cuadro de base e hipermetabolismo por otras causas."
			],
			[
				"Tirotoxicosis",
				"Historia clínica orienta síntomas y manejo."
			],
			[
				"Feocromocitoma",
				"Predominan crisis hipertensivas severas."
			],
			[
				"Iatrogenia",
				"Insuflación de CO[sub]2[/sub], sobrecalentamiento, superficialidad anestésica, ventilación inadecuada."
			],
			[
				"Síndrome Neuroléptico Maligno",
				"Asociado a neurolépticos, ATC, IMAO o retiro de antiparkinsonianos."
			],
			[
				"Síndrome anticolinérgico",
				"Antihistamínicos, atropina, escopolamina, ATC."
			],
			[
				"Toxicidad por drogas",
				"Cocaína, anfetaminas, salicilatos."
			],
			[
				"Síndrome de abstinencia",
				"Historia clínica orienta."
			],
			[
				"Lesión cerebral",
				"Historia clínica orienta."
			]
		]
	},
	{
		"id": "tratamiento",
		"title": "Tratamiento de la crisis de Hipertermia Maligna",
		"ordered": [
			"Suspender inmediatamente agentes desencadenantes.",
			"Hiperventilar con O[sub]2[/sub] al 100% a flujos altos.",
			"Dantroleno IV: dosis inicial 2.5 mg/kg; repetir cada 5–10 min hasta revertir signos o dosis total 10 mg/kg.",
			"Bicarbonato de sodio 1–2 mEq/kg IV para acidosis severa/hiperkalemia (asegurar ventilación).",
			"Enfriamiento activo: compresas frías cervical/axilas/ingle, lavado gástrico/rectal con SSN fría; considerar inmersión en casos severos; convección/evaporación.",
			"Monitorización continua: signos vitales, gases, electrolitos, CK, orina (mioglobinuria).",
			"Diuresis adecuada para prevenir FRA por mioglobinuria."
		],
		"info_box": {
			"title": "Dantroleno: preparación y continuidad",
			"bullets": [
				"Cada vial 20 mg reconstituir con 60 ml de agua estéril (sin bacteriostáticos). No usar SSN ni dextrosa.",
				"Agitar vigorosamente hasta solución clara. Un paciente de 70 kg puede requerir múltiples viales.",
				"[b]Mantener[/b] dantroleno 1 mg/kg cada 4–6 h o infusión continua por 24–48 h para prevenir recurrencia (UCI).",
				"Simulación de reconstitución con modelos de bajo costo reduce tiempos en crisis reales."
			]
		},
		"small_text": "Ver [i]Listas de Chequeo: Crisis en Salas de Cirugía[/i] (Ariadne Labs / S.C.A.R.E.) para algoritmos operativos."
	},
	{
		"id": "susceptibilidad",
		"title": "Diagnóstico de susceptibilidad a HM",
		"bullets": [
			"[b]Prueba de referencia:[/b] contractura con cafeína y halotano (CHCT) / contractura [i]in vitro[/i] (IVCT).",
			"[b]Genética:[/b] múltiples mutaciones, principalmente [i]RYR1[/i]; sensibilidad global de pruebas genéticas ≈25%, útil en familiares cuando se identifica mutación índice.",
			"No hay pruebas menos invasivas que reemplacen a la prueba de contractura."
		]
	},
	{
		"id": "asociaciones",
		"title": "Asociación con otras enfermedades musculares",
		"paragraphs": [
			"Mayor riesgo de susceptibilidad en Miopatía de Núcleo Central y síndrome de King–Denborough. Distrofias de Duchenne y Becker no incrementan el riesgo más allá de la población general. En pediatría con sospecha de miopatía, evitar desencadenantes."
		]
	},
	{
		"id": "anestesia",
		"title": "Anestesia en pacientes susceptibles",
		"bullets": [
			"[b]Técnicas seguras:[/b] anestesia regional o TIVA con agentes no desencadenantes.",
			"[b]Máquina de anestesia:[/b] purga con O[sub]2[/sub] a alto flujo, recambio de componentes y uso de filtros de carbón activado para residuales < 5 ppm. Seguir manuales del fabricante.",
			"No se recomienda profilaxis con dantroleno cuando se evitan desencadenantes y se dispone de tratamiento IV."
		]
	},
	{
		"id": "orientacion",
		"title": "Orientación a pacientes y familiares",
		"paragraphs": [
			"Evaluar probabilidad clínica de evento con escalas. Considerar susceptibles a caso confirmado y familiares de primer grado. Ofrecer información detallada, recomendar pruebas (contractura/genética) y el uso de alertas médicas; informar a anestesiólogos en futuras atenciones."
		]
	},
	{
		"id": "conclusiones",
		"title": "Conclusiones",
		"paragraphs": [
			"La HM es un evento crítico que exige conciencia y preparación. La disponibilidad de dantroleno, el reconocimiento temprano y la implementación inmediata de protocolos mejoran el pronóstico. Comprender fisiopatología, disparadores, diagnóstico y manejo perioperatorio seguro en pacientes susceptibles es esencial. La simulación de escenarios y de la reconstitución del dantroleno fortalece la respuesta ante esta emergencia."
		]
	},
	{
		"id": "bibliografia",
		"title": "Bibliografía",
		"bullets": [
			"Rincón D, Sessler D. Cap. 34. En: Tratado de anestesia pediátrica. Tomo 1. Bogotá: SCARE; 2014. p. 1034-71. ISBN: 978-958-8873-18-3.",
			"Barash PG, Cullen BF, Stoelting RK, et al. Hyperthermia Maligna. En: Miller's Basics of Anesthesia. 8a ed. Elsevier; 2023. p. 379-384.",
			"Gupta PK, Bilmen JG, Hopkins PM. BJA Educ. 2021;21(6):218-224. doi:10.1016/j.bjae.2021.01.003.",
			"Glahn KPE, et al.; EMHG. BJA. 2025;134(1):221-223. doi:10.1016/j.bja.2024.09.022.",
			"Giraldo-Gutiérrez DS, Arrendo-Verbel MA, Rincón-Valenzuela DA. Rev. colomb. anestesiol. 2018.",
			"Heiderich S, et al. Anaesthesist. 2021;70(2):155-157. doi:10.1007/s00101-020-00893-5.",
			"Rüffert H, et al.; EMHG. BJA. 2021;126(1):120-130. doi:10.1016/j.bja.2020.09.029."
		],
		"subsections": [
			{
				"title": "Recursos",
				"bullets": [
					"MHAUS — Videos: https://www.mhaus.org/videos/",
					"EMHG — About: https://www.emhg.org/about"
				]
			},
			{
				"title": "Nota",
				"paragraphs": [
					"Fecha: Mayo 2025."
				]
			}
		]
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_build_map()
	_build_sections()
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if dimmer:
		dimmer.gui_input.connect(_on_dimmer_gui_input)

func open(section_id: String = "") -> void:
	if is_open:
		if section_id != "":
			call_deferred("_scroll_to_section", section_id)
		return
	show()
	is_open = true
	if not get_tree().paused:
		get_tree().paused = true
		pause_applied = true
	if close_button:
		close_button.grab_focus()
	elif panel:
		panel.grab_focus()
	if section_id != "":
		call_deferred("_scroll_to_section", section_id)

func close() -> void:
	if not is_open:
		return
	hide()
	is_open = false
	if pause_applied:
		get_tree().paused = false
	pause_applied = false
	overlay_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
		if get_viewport():
			get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	close()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		_on_close_button_pressed()
		if get_viewport():
			get_viewport().set_input_as_handled()

func _scroll_to_section(section_id: String) -> void:
	if not content_scroll:
		return
	var target: Control = section_lookup.get(section_id, null)
	if target:
		content_scroll.ensure_control_visible(target)

func _build_map() -> void:
	if not map_container:
		return
	for child in map_container.get_children():
		child.queue_free()
	for entry in FLOW_NODES:
		var entry_node: Control = _create_map_entry(entry, false)
		map_container.add_child(entry_node)

func _create_map_entry(entry: Dictionary, is_child: bool) -> Control:
	var panel_container := PanelContainer.new()
	panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_child:
		panel_container.modulate = Color(0.9, 0.98, 1.0, 0.9)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel_container.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	if entry.has("tag") and not is_child:
		var tag_label := Label.new()
		tag_label.text = entry["tag"].to_upper()
		tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag_label.add_theme_color_override("font_color", ACCENT_COLOR)
		tag_label.add_theme_font_size_override("font_size", 13)
		box.add_child(tag_label)
	var button := Button.new()
	button.text = entry.get("title", "")
	button.alignment = HorizontalAlignment.LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	button.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	button.add_theme_font_size_override("font_size", 18 if not is_child else 16)
	button.pressed.connect(_on_map_button_pressed.bind(entry.get("section_id", "")))
	box.add_child(button)
	if entry.has("summary"):
		var summary := Label.new()
		summary.text = entry["summary"]
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_color_override("font_color", MUTED_COLOR)
		summary.add_theme_font_size_override("font_size", 13 if not is_child else 12)
		box.add_child(summary)
	if entry.has("children"):
		var branch_margin := MarginContainer.new()
		branch_margin.add_theme_constant_override("margin_left", 14)
		branch_margin.add_theme_constant_override("margin_top", 4)
		box.add_child(branch_margin)
		var branch_box := VBoxContainer.new()
		branch_box.add_theme_constant_override("separation", 6)
		branch_margin.add_child(branch_box)
		for child_entry in entry["children"]:
			var child_node: Control = _create_map_entry(child_entry, true)
			branch_box.add_child(child_node)
	return panel_container

func _on_map_button_pressed(section_id: String) -> void:
	if section_id == "":
		return
	call_deferred("_scroll_to_section", section_id)

func _build_sections() -> void:
	section_lookup.clear()
	if not content_container:
		return
	for child in content_container.get_children():
		child.queue_free()
	for section in SECTION_CONTENT:
		var section_box := VBoxContainer.new()
		section_box.name = section.get("id", "")
		section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_box.add_theme_constant_override("separation", 10)
		var title_label := Label.new()
		title_label.text = section.get("title", "")
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0))
		content_container.add_child(section_box)
		section_box.add_child(title_label)
		if section.has("paragraphs"):
			for paragraph in section["paragraphs"]:
				_add_paragraph(section_box, paragraph)
		if section.has("bullets"):
			_add_bullet_list(section_box, section["bullets"])
		if section.has("ordered"):
			_add_ordered_list(section_box, section["ordered"])
		if section.has("info_box"):
			_add_info_box(section_box, section["info_box"])
		if section.has("small_text"):
			_add_small_text(section_box, section["small_text"])
		if section.has("info_grid"):
			_add_info_grid(section_box, section["info_grid"])
		if section.has("table_headers") and section.has("table_rows"):
			_add_table(section_box, section["table_headers"], section["table_rows"])
		if section.has("paragraphs_tail"):
			for tail in section["paragraphs_tail"]:
				_add_paragraph(section_box, tail)
		if section.has("subsections"):
			for subsection in section["subsections"]:
				_add_subsection(section_box, subsection)
		var separator := HSeparator.new()
		separator.modulate = Color(0.25, 0.35, 0.45, 0.6)
		content_container.add_child(separator)
		section_lookup[section_box.name] = section_box
	if content_container.get_child_count() > 0:
		var last_child := content_container.get_child(content_container.get_child_count() - 1)
		if last_child is HSeparator:
			last_child.queue_free()

func _add_paragraph(parent: VBoxContainer, text: String) -> void:
	var paragraph := RichTextLabel.new()
	paragraph.bbcode_enabled = true
	paragraph.fit_content = true
	paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paragraph.text = text
	parent.add_child(paragraph)

func _add_bullet_list(parent: VBoxContainer, items: Array) -> void:
	for item in items:
		var bullet := RichTextLabel.new()
		bullet.bbcode_enabled = true
		bullet.fit_content = true
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.text = "• %s" % item
		parent.add_child(bullet)

func _add_ordered_list(parent: VBoxContainer, items: Array) -> void:
	var index := 1
	for item in items:
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "[b]%d.[/b] %s" % [index, item]
		parent.add_child(line)
		index += 1

func _add_info_box(parent: VBoxContainer, info: Dictionary) -> void:
	var panel_container := PanelContainer.new()
	panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel_container.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title_label := Label.new()
	title_label.text = info.get("title", "")
	title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(title_label)
	if info.has("bullets"):
		for bullet_text in info["bullets"]:
			var bullet := RichTextLabel.new()
			bullet.bbcode_enabled = true
			bullet.fit_content = true
			bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bullet.text = "• %s" % bullet_text
			box.add_child(bullet)
	parent.add_child(panel_container)

func _add_small_text(parent: VBoxContainer, text: String) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("default_color", MUTED_COLOR)
	label.text = text
	parent.add_child(label)

func _add_info_grid(parent: VBoxContainer, entries: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = max(1, min(entries.size(), 2))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for entry in entries:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		var title_label := Label.new()
		title_label.text = entry.get("title", "")
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", ACCENT_COLOR)
		title_label.horizontal_alignment = HorizontalAlignment.LEFT
		cell.add_child(title_label)
		var text_label := RichTextLabel.new()
		text_label.bbcode_enabled = true
		text_label.fit_content = false
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.text = entry.get("text", "")
		cell.add_child(text_label)
		grid.add_child(cell)
	parent.add_child(grid)

func _add_table(parent: VBoxContainer, headers: Array, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = headers.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	for header in headers:
		var header_label := Label.new()
		header_label.text = header
		header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_label.horizontal_alignment = HorizontalAlignment.LEFT
		header_label.add_theme_font_size_override("font_size", 22)
		header_label.add_theme_color_override("font_color", ACCENT_COLOR)
		grid.add_child(header_label)
	for row in rows:
		for cell_text in row:
			var cell := RichTextLabel.new()
			cell.bbcode_enabled = true
			cell.fit_content = false
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cell.text = cell_text
			grid.add_child(cell)
	parent.add_child(grid)

func _add_subsection(parent: VBoxContainer, subsection: Dictionary) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	var title_label := Label.new()
	title_label.text = subsection.get("title", "")
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.82, 0.87, 1.0))
	container.add_child(title_label)
	if subsection.has("paragraphs"):
		for paragraph in subsection["paragraphs"]:
			_add_paragraph(container, paragraph)
	if subsection.has("bullets"):
		_add_bullet_list(container, subsection["bullets"])
	parent.add_child(container)
