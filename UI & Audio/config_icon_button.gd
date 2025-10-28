extends Button

@export var background_color: Color = Color.html("#0d1a26")
@export var ring_color: Color = Color.html("#1e2f3f")
@export var icon_color: Color = Color.html("#e5f2f7")
@export var highlight_color: Color = Color.html("#5fd1c9")

var _hovered := false
var _pressed := false

func _ready() -> void:
        flat = true
        text = ""
        focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        clip_contents = false
        _connect_state_signals()
        update()

func _notification(what: int) -> void:
        if what == NOTIFICATION_THEME_CHANGED:
                update()

func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseMotion:
                return
        if event is InputEventMouseButton and event.pressed:
                _pressed = true
                update()
        elif event is InputEventMouseButton and not event.pressed:
                _pressed = false
                update()

func _connect_state_signals() -> void:
        mouse_entered.connect(func():
                _hovered = true
                update()
        )
        mouse_exited.connect(func():
                _hovered = has_focus()
                update()
        )
        focus_entered.connect(func():
                _hovered = true
                update()
        )
        focus_exited.connect(func():
                _hovered = false
                update()
        )
        button_down.connect(func():
                _pressed = true
                update()
        )
        button_up.connect(func():
                _pressed = false
                update()
        )

func _draw() -> void:
        var rect := get_rect()
        var center := rect.size * 0.5
        var size := min(rect.size.x, rect.size.y)
        var base_radius := size * 0.48
        var base_color := background_color
        if _hovered:
                base_color = base_color.lerp(highlight_color, 0.3)
        if _pressed:
                base_color = base_color.darkened(0.15)
        draw_circle(center, base_radius, base_color)

        var ring_col := ring_color
        if _hovered:
                ring_col = ring_col.lerp(highlight_color, 0.35)
        draw_circle(center, base_radius * 0.82, ring_col)

        var tooth_outer := base_radius * 0.75
        var tooth_inner := base_radius * 0.46
        var tooth_half_width := base_radius * 0.18
        var gear_color := icon_color
        if _hovered:
                gear_color = gear_color.lerp(highlight_color, 0.45)
        if _pressed:
                gear_color = gear_color.darkened(0.2)

        for i in range(8):
                var angle := deg_to_rad(i * 45.0)
                var dir := Vector2(cos(angle), sin(angle))
                var perp := Vector2(-sin(angle), cos(angle))
                var inner_center := center + dir * tooth_inner
                var outer_center := center + dir * tooth_outer
                var p1 := inner_center + perp * tooth_half_width
                var p2 := outer_center + perp * tooth_half_width
                var p3 := outer_center - perp * tooth_half_width
                var p4 := inner_center - perp * tooth_half_width
                draw_colored_polygon([p1, p2, p3, p4], gear_color)

        draw_circle(center, tooth_outer * 0.78, gear_color)
        draw_circle(center, tooth_inner * 0.42, base_color)
        draw_circle(center, tooth_inner * 0.2, gear_color.lerp(highlight_color, 0.25))

func reset_visual_state() -> void:
        _hovered = false
        _pressed = false
        update()
