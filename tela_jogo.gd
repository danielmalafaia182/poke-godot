extends RefCounted

# Novo: pixels de interface independem da ampliação da janela.
# A cidade revela mais mapa em telas maiores, em vez de ampliar todo o HUD.
static func aplicar(janela: Window) -> void:
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	janela.content_scale_size = Vector2i.ZERO
	janela.content_scale_factor = 1.0
