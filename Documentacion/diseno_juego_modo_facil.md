# Documento de Funcionamiento del Juego – Modo Fácil

## 1. Resumen ejecutivo
Este documento describe el funcionamiento completo del modo fácil del juego educativo desarrollado para la Sociedad Colombiana de Anestesiología y Reanimación (SCARE). Se resumen los objetivos pedagógicos, el flujo de juego, las reglas, la interfaz de usuario, los sistemas técnicos principales y los datos gestionados para que cualquier lector pueda comprender, operar y, de ser necesario, mantener el proyecto.

## 2. Contexto del proyecto
- **Propósito:** Facilitar el repaso de conceptos clave de anestesiología a través de una experiencia lúdica basada en tablero.
- **Público objetivo:** Profesionales y estudiantes de SCARE que participen en talleres o eventos formativos.
- **Plataforma:** Godot Engine 4 (proyecto `project.godot`). Se ejecuta como aplicación de escritorio o web exportada.
- **Estado de referencia:** Escena principal `levels/main.tscn` con sus scripts asociados.

## 3. Visión general del juego
- **Elevator pitch:** El jugador lanza un dado virtual, avanza un peón sobre podios temáticos y responde preguntas de opción múltiple para acumular puntos y mantener sus vidas.
- **Objetivos educativos:** Exponer al participante a preguntas cortas distribuidas en categorías médicas. Cada categoría aporta contenido específico y colorimetría asociada (`levels/main.gd`, constante `CATEGORY_COLORS`).
- **Tono y narrativa:** Experiencia relajada, acompañada por la introducción textual del modo fácil (`UI & Audio/mode_intro_overlay.gd`). No hay narrativa ficcional, sino una ambientación de tablero futurista.

## 4. Flujo de juego
1. **Inicio y tutorial:**
   - Se carga la escena `levels/main.tscn`, se muestra la superposición `ModeIntroOverlay` con título, descripción y botón “Comenzar”. Mientras está visible, el árbol está en pausa (`mode_intro_overlay.gd`).
2. **Indicación inicial:**
   - Al cerrar la introducción, aparece la etiqueta “Dé click en cualquier lugar de la pantalla para tirar el dado” en la esquina superior derecha (`levels/main.gd`, nodo `HUDMessages/ClickInstructionLabel`). Se oculta automáticamente con el primer clic detectado (`_input`).
3. **Lanzamiento de dado:**
   - El jugador hace clic izquierdo sobre el área de juego con el peón en reposo para accionar el dado (`Assets/Dice/dice.gd`, método `_input`).
4. **Movimiento del peón:**
   - El peón se desplaza salto a salto según el número obtenido (`Player/player.gd`, `_start_next_jump` y `_process`). Cada aterrizaje reproduce un efecto de sonido y partículas.
5. **Encuentro con podio:**
   - El script `levels/spots.gd` detecta el podio final y emite la categoría correspondiente o el evento de vida extra para `PreguntasPanel`.
6. **Pregunta y resolución:**
   - `UI & Audio/preguntas_panel.gd` muestra una pregunta aleatoria de la categoría, administra temporizador de 45 segundos, califica la respuesta, actualiza puntuación y vidas y reproduce retroalimentación audiovisual.
7. **Estado del juego:**
   - La partida continúa en bucle (lanzar dado → moverse → preguntar) hasta alcanzar 15 puntos (victoria) o perder todas las vidas (derrota). Se muestra `VictoryOverlay` con mensajes contextuales (`levels/main.gd`, `_show_end_overlay`).
8. **Post-juego:**
   - Se puede reiniciar la partida o volver al menú principal (`_restart_game`, `_return_to_main_menu`). Si la derrota ocurre por falta de vidas, se fuerza el regreso al menú para reiniciar el flujo.

## 5. Reglas y mecánicas
- **Lanzamiento del dado:**
  - Solo se permite tirar cuando el peón ha aterrizado y no hay panel de preguntas abierto (`dice.gd`, bandera `can_roll`).
  - El dado aplica fuerza y torque aleatorios; cuando se detiene, determina el valor final mediante raycasts (`Dice.tscn`, grupo `Raycasts`).
- **Movimiento del peón:**
  - El peón recorre secuencialmente los `Marker3D` definidos en `Player/player.tscn` (`@export var game_spaces`).
  - Cada salto describe una parábola suave y bloquea nuevas tiradas hasta finalizar.
- **Podios y categorías:**
  - Los podios se instancian aleatoriamente al inicio excluyendo repeticiones consecutivas. Los puestos 10 y 20 garantizan la categoría “Health” (vida extra).
  - Al aterrizar, `levels/spots.gd` determina la categoría mediante la metadata del podio e invoca `mostrar_pregunta_de_categoria` del panel.
- **Preguntas:**
  - Cada categoría tiene un conjunto de preguntas con opciones y retroalimentación (`UI & Audio/preguntas_etapa_1.json`).
  - Las preguntas usadas se retiran temporalmente para evitar repeticiones hasta agotar la lista, momento en el cual se reinicia el conjunto (`preguntas_panel.gd`, `_cargar_preguntas`).
  - Las respuestas correctas otorgan un punto; las incorrectas o el tiempo agotado consumen una vida.
- **Vidas y vida extra:**
  - Se inicia con 3 vidas (`preguntas_panel.gd`, variable `vidas`).
  - El podio “Health” suma una vida hasta un máximo no limitado explícitamente y muestra un toast informativo (`levels/main.gd`, `_show_extra_life_toast`).
  - Sin vidas restantes, se dispara derrota y se bloquea la interacción hasta escoger reinicio o menú (`_game_over`, `_lock_gameplay`).
- **Condición de victoria:**
  - Alcanzar 15 puntos detona `victoria_alcanzada`, detiene el flujo y muestra el panel final.

## 6. Interfaz de usuario y experiencia
- **Tablero 3D:** Escena `levels/main.tscn` combina componentes 3D (tablero, luz, podios, peón, dado) con HUD 2D.
- **HUD:** Etiquetas `Score` y `Health` muestran progreso y vidas con colorimetría adaptativa según la categoría activa (`_update_ui_colors`).
- **Panel de preguntas:** CanvasLayer con panel informativo, carta de pregunta y botones de respuesta. Incluye cronómetro con cambios de color, iconografía por categoría y pistas de continuación (`preguntas_panel.tscn`).
- **Superposiciones:**
  - `ModeIntroOverlay`: presentación del modo, pausable.
  - `GuideOverlay`: acceso a guía rápida desde botón lateral (`guide_overlay.tscn`).
  - `ConfigOverlay`: opciones de configuración y accesos a menú/reinicio (`config_overlay.tscn`).
  - `VictoryOverlay`: resumen de victoria/derrota con botones de acción.
  - `ExitConfirmDialog`: confirma salida al menú principal.
- **Indicadores temporales:** Mensaje de vida extra y texto de instrucción inicial se gestionan mediante tweens y flags para evitar repeticiones.

## 7. Diseño audiovisual
- **Música y ambientación:** Archivos en `UI & Audio/Musica y Audios/` controlan música de fondo (no gestionados desde los scripts listados, dependerá de la escena principal si se habilita).
- **Efectos de sonido clave:**
  - Lanzamiento del dado (`Assets/Dice/dice.gd`, nodo `ThrowSound`).
  - Golpes del dado durante colisiones (`Dice sound`).
  - Aterrizaje del peón (`Player/player.tscn`, `LandingSound`).
  - Respuestas correctas/incorrectas, victoria y derrota (`Assets/sfx/sfx_manager.gd`).
  - Selección de botones: sonido aleatorio entre variaciones (`play_select`).
- **Retroalimentación visual:**
  - Cambios de color en piso, luz y overlays según categoría (`levels/main.gd`, `_apply_scene_color`).
  - Partículas de aterrizaje (`Assets/Vfx/PawnLandingVfx.tscn`).
  - Animaciones de entrada del panel de preguntas y cronómetro parpadeante.

## 8. Arquitectura técnica
- **Escena raíz (`levels/main.tscn`):** Nodo `Node` con subárbol para ambiente 3D, HUD y superposiciones. Script `levels/main.gd` gestiona señales, cambios de color, flujos de victoria/derrota y coordinación general.
- **Peón (`Player/player.tscn` + `player.gd`):** `CharacterBody3D` con ruta de marcadores exportada y señales para avisar al sistema de podios.
- **Dado (`Assets/Dice/Dice.tscn` + `dice.gd`):** `RigidBody3D` con raycasts para identificar la cara resultante y audio propio.
- **Podios (`Assets/Podium/*.tscn`):** Instanciados dinámicamente por `levels/spots.gd`, que también emite las señales `category_reached` y `extra_life_awarded`.
- **Panel de preguntas (`UI & Audio/preguntas_panel.tscn` + `preguntas_panel.gd`):** Controla ciclo de preguntas, cronómetro, puntuación y vidas.
- **Gestor de SFX (`Assets/sfx/sfx_manager.gd`):** Nodo autoload (consultar `project.godot` → sección `autoload`) responsable de reproducir efectos globales y conectar botones.
- **Overlays de guía y configuración:** Scripts `guide_overlay.gd` y `config_overlay.gd` proporcionan apertura/cierre, con señales `overlay_closed`, `menu_requested` y `restart_requested` atendidas desde `levels/main.gd`.

## 9. Datos y telemetría
- **Datos manejados:**
  - Puntaje (`puntos`) y vidas (`vidas`) almacenados en memoria durante la sesión.
  - Historial de preguntas usadas para evitar repeticiones inmediatas.
  - Estado del tablero (categoría actual, vidas extras otorgadas).
- **Persistencia:** No se guarda información de manera permanente ni se envían datos a servidores externos. Al reiniciar o volver al menú principal, todo el progreso se restablece.
- **Privacidad:** Sin recopilación de datos personales ni métricas; cumplimiento implícito con requisitos de privacidad al no almacenar información sensible.

## 10. Contenido y localización
- **Texto:** Todos los textos de la interfaz están en español, incluidos tutorial, mensajes de overlay y retroalimentación.
- **Preguntas:** Archivo JSON `UI & Audio/preguntas_etapa_1.json` organiza preguntas por categoría con campos `texto`, `opciones`, `respuesta_correcta` y `retroalimentacion`.
- **Iconografía:** Asociada a cada categoría en `Assets/Icons/*.svg` y cargada a través del diccionario `icon_map`.
- **Mensajes dinámicos:** Etiquetas de victoria, derrota, vida extra e instrucciones iniciales generadas desde `levels/main.gd`.

## 11. Pruebas y validación
- **Pruebas manuales recomendadas:**
  - Verificar que el tutorial pause el juego y que la instrucción de clic inicial aparezca y desaparezca correctamente.
  - Lanzar el dado múltiples veces para confirmar comportamiento físico y audio.
  - Probar respuestas correctas, incorrectas y expiración del tiempo para validar cambios de puntuación/vidas y señales de victoria/derrota.
  - Asegurar que los podios “Health” otorguen vida extra y muestren el toast.
  - Revisar accesos a guía, configuración y diálogo de salida durante una partida activa.
- **Automatización:** No se incluyen pruebas automatizadas. Se sugiere evaluar la viabilidad de tests de GUT o integración en futuras iteraciones.

## 12. Despliegue y configuración
- **Construcción:** Utilizar los presets definidos en `export_presets.cfg` para generar builds. Confirmar dependencias de assets multimedia antes de exportar.
- **Configuración en tiempo de ejecución:**
  - Controles vía ratón/entrada táctil para lanzar dado y seleccionar respuestas.
  - El menú de configuración ofrece accesos a reinicio y retorno al menú principal.
- **Requerimientos:** Godot 4.x para edición; hardware capaz de renderizar escenas 3D moderadas.

## 13. Apéndices
- **Lista de escenas clave:**
  - `levels/main.tscn`, `levels/exam_main.tscn` (modo examen, fuera de alcance de este documento pero reutiliza componentes).
  - `Player/player.tscn`, `Assets/Dice/Dice.tscn`, `UI & Audio/preguntas_panel.tscn`.
- **Recursos de audio destacados:**
  - `Assets/sfx/correct_answer.mp3`, `Assets/sfx/wrong_answer.mp3`, `Assets/sfx/success.mp3`, `Assets/sfx/failure.mp3`.
  - `Assets/Dice/throw_sound.ogg` (según configuración de la escena) y sonidos de colisión.
- **Glosario:**
  - **Podio:** Casilla del tablero que detona la visualización de una pregunta y define su categoría.
  - **HUD:** Capa de interfaz 2D que muestra puntuación, vidas y mensajes auxiliares.
  - **Overlay:** Superposición de interfaz que bloquea temporalmente la interacción principal.

