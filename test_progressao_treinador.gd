extends SceneTree
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool,t: String) -> void:
 checks+=1
 if not ok:falhas+=1;push_error(t)
func executar() -> void:
 var p: PerfilTreinador=PerfilTreinador.new()
 p.registrar_recompensa_treinador(8)
 checar(p.nivel_treinador==1 and p.experiencia_treinador_acumulada==8,"XP inicial")
 p.registrar_recompensa_treinador(92)
 checar(p.nivel_treinador==2,"Limite de subida de nível")
 p.registrar_recompensa_treinador(-10)
 checar(p.experiencia_treinador_acumulada==100,"Rejeita XP negativa")
 p=PerfilTreinador.new();p.nivel_treinador=20;p.experiencia_treinador_acumulada=50
 p.normalizar_progressao()
 checar(p.nivel_treinador==20 and p.experiencia_treinador_acumulada==50,"Migração preserva nível e XP histórica")
 var base: int=p.experiencia_base_migracao
 p.normalizar_progressao()
 checar(p.experiencia_base_migracao==base,"Migração idempotente")
 var estado: Node=root.get_node("EstadoJogo")
 estado.perfil=p
 # Testa HUD e serialização sem alterar conexões do singleton de produção.
 var hud: Control=load("res://painel_time.gd").new();root.add_child(hud)
 await process_frame
 var anterior: int=hud.lista.get_child_count()
 p.registrar_recompensa_treinador(1000);estado.perfil_alterado.emit()
 checar(hud.barra_xp_treinador.value>0 and hud.xp_treinador.text.begins_with("XP "),"HUD atualiza XP")
 checar(hud.lista.get_child_count()==anterior,"Atualização não reconstrói time")
 var save: RefCounted=preload("res://salvamento_local.gd").new()
 var dados: Dictionary=save.construir_dados(estado)
 checar(save._validar(dados).is_empty() and dados["experiencia_base_migracao"]==base,"Save inclui base de migração")
 var xp: int=p.experiencia_treinador_acumulada
 var lv: int=p.nivel_treinador
 save._restaurar(estado,dados)
 checar(estado.nivel_treinador==lv and estado.experiencia_treinador_acumulada==xp and estado.perfil.experiencia_base_migracao==base,"Roundtrip preserva progresso")
 # Ciclo 3: 'Derrota concede XP uma única vez' era da cena antiga; a nova recebe XP por field-kill (test_caca_sim).
 hud.queue_free();await process_frame
 print("PROGRESSAO TREINADOR: %d verificações; %d falhas" % [checks,falhas])
 quit(1 if falhas else 0)
