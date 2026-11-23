class_name ScreenFx
extends CanvasLayer
## Full-screen feel under the HUD: a soft vignette, and short effects that
## read the screen: a red flash with a colour split when you're hurt, a
## kick of split on your heavy hits and kills, a radial speed blur while
## you dash or fly. The screen-reading shader only runs during an effect.

const FX_SHADER := preload("res://src/match/screen_fx.gdshader")
const REST_SHADER := preload("res://src/match/vignette.gdshader")

var vignette := 0.3
var _rect: ColorRect
var _fx_mat: ShaderMaterial
var _rest_mat: ShaderMaterial
var _aberration := 0.0
var _flash := Color(1, 0.1, 0.1, 0.0)
var _blur := 0.0
var _blur_want := 0.0
var _enabled := true


func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = FX_SHADER
	_rest_mat = ShaderMaterial.new()
	_rest_mat.shader = REST_SHADER
	_rect.material = _rest_mat
	apply_preset()


## LOW: no vignette and no screen effects (fill rate on slow phones).
func apply_preset() -> void:
	_enabled = Game.preset()["name"] != "LOW"
	vignette = 0.3 if _enabled else 0.0
	_rest_mat.set_shader_parameter(&"vignette", vignette)
	_fx_mat.set_shader_parameter(&"vignette", vignette)
	_rect.visible = _enabled


## You got hit: `amount` 0..1.
func hurt(amount: float) -> void:
	_aberration = maxf(_aberration, amount)
	_flash = Color(0.85, 0.05, 0.05, maxf(_flash.a, 0.45 * amount))


## A jolt: your heavy hit landed, or a kill.
func punch(amount: float, tint: Color = Color(1, 0.85, 0.4, 0.0)) -> void:
	_aberration = maxf(_aberration, amount)
	if tint.a > 0.0:
		_flash = Color(tint.r, tint.g, tint.b, maxf(_flash.a, tint.a))


## Speed blur wanted this frame (0 = none), set every frame by the match.
func set_speed(amount: float) -> void:
	_blur_want = amount


func _process(delta: float) -> void:
	if not _enabled:
		return
	var real := delta / maxf(Engine.time_scale, 0.05)
	_aberration = maxf(_aberration - real * 2.8, 0.0)
	_flash.a = maxf(_flash.a - real * 1.6, 0.0)
	_blur = move_toward(_blur, _blur_want, real * 4.0)
	var active := _aberration > 0.01 or _flash.a > 0.01 or _blur > 0.01
	_rect.material = _fx_mat if active else _rest_mat
	if active:
		_fx_mat.set_shader_parameter(&"aberration", _aberration)
		_fx_mat.set_shader_parameter(&"blur", _blur)
		_fx_mat.set_shader_parameter(&"flash", _flash)
