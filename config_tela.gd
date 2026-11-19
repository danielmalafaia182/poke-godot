extends RefCounted
## Configurações de tela (C: hud.config — tamanho da interface e tela cheia). Ficam em user://config_tela.cfg, fora do
## save do jogo (preferência da máquina, não do progresso). Escala 0,75–1,5 sobre a referência 1920×1080.

const ARQUIVO := "user://config_tela.cfg"
const ESCALAS := [0.75, 1.0, 1.25, 1.5]


static func ler() -> Dictionary:
	var c := ConfigFile.new()
	c.load(ARQUIVO)
	return {"escala": clampf(float(c.get_value("tela", "escala", 1.0)), 0.5, 2.0), "tela_cheia": bool(c.get_value("tela", "tela_cheia", false))}


static func gravar(cfg: Dictionary) -> void:
	var c := ConfigFile.new()
	c.set_value("tela", "escala", float(cfg.get("escala", 1.0)))
	c.set_value("tela", "tela_cheia", bool(cfg.get("tela_cheia", false)))
	c.save(ARQUIVO)


static func aplicar(janela: Window, cfg: Dictionary = {}) -> void:
	if cfg.is_empty():
		cfg = ler()
	if janela == null:
		return
	janela.content_scale_factor = float(cfg["escala"])
	if DisplayServer.get_name() != "headless":
		janela.mode = Window.MODE_FULLSCREEN if bool(cfg["tela_cheia"]) else (Window.MODE_WINDOWED if janela.mode == Window.MODE_FULLSCREEN else janela.mode)
