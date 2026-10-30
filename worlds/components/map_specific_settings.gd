extends Node

const RENDER_SCALES: Array[float] = [1.0, 0.77, 0.67, 0.59, 0.5, 0.35, 0.25]
const SHADOW_FILTERS: Array[int] = [
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
]
const SHADOW_ATLAS_SIZES: Array[int] = [2048, 4096, 4096]
const SUN_ANGULAR_DISTANCES: Array[float] = [0.0, 0.0, 0.5]

@export var sun: DirectionalLight3D
@export var grade_brightness := 1.0

var _authored_shadow_modes: Dictionary[DirectionalLight3D, DirectionalLight3D.ShadowMode] = {}


static func render_scale(quality: int) -> float:
	return RENDER_SCALES[clampi(quality, 0, RENDER_SCALES.size() - 1)]


static func brighten(environment: Environment, brightness: float, grade: float) -> void:
	if !environment:
		return
	environment.adjustment_enabled = true
	environment.adjustment_brightness = brightness * grade


static func scaling_mode(use_fidelity_fx: bool, quality: int) -> Viewport.Scaling3DMode:
	if use_fidelity_fx && quality > 0:
		return Viewport.SCALING_3D_MODE_FSR2
	return Viewport.SCALING_3D_MODE_BILINEAR


static func shadow_level(quality: int) -> int:
	return clampi(quality, SettingsResource.ShadowQuality.LOW, SettingsResource.ShadowQuality.HIGH)


static func shadow_filter(quality: int) -> RenderingServer.ShadowQuality:
	return SHADOW_FILTERS[shadow_level(quality)] as RenderingServer.ShadowQuality


static func shadow_atlas_size(quality: int) -> int:
	return SHADOW_ATLAS_SIZES[shadow_level(quality)]


static func sun_angular_distance(quality: int) -> float:
	return SUN_ANGULAR_DISTANCES[shadow_level(quality)]


static func directional_shadow_mode(quality: int,
		authored: DirectionalLight3D.ShadowMode) -> DirectionalLight3D.ShadowMode:
	if shadow_level(quality) == SettingsResource.ShadowQuality.HIGH:
		return DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	return authored


func _ready() -> void:
	if sun:
		_authored_shadow_modes[sun] = sun.directional_shadow_mode
	SaveManager.settings.map_specific_settings_changed.connect(apply)
	apply()


func apply() -> void:
	var settings: SettingsResource = SaveManager.settings
	var viewport := get_viewport()
	viewport.scaling_3d_mode = scaling_mode(settings.use_fidelity_fx, settings.fidelity_fx)
	viewport.scaling_3d_scale = render_scale(settings.fidelity_fx)
	brighten(viewport.find_world_3d().environment, settings.brightness, grade_brightness)
	_apply_shadows(viewport, settings.shadow_quality)


func _apply_shadows(viewport: Viewport, quality: int) -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow_filter(quality))
	RenderingServer.positional_soft_shadow_filter_set_quality(shadow_filter(quality))
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size(quality), true)
	viewport.positional_shadow_atlas_size = shadow_atlas_size(quality)
	if sun:
		sun.light_angular_distance = sun_angular_distance(quality)
	for light: DirectionalLight3D in _authored_shadow_modes:
		var authored := _authored_shadow_modes[light]
		light.directional_shadow_mode = directional_shadow_mode(quality, authored)
