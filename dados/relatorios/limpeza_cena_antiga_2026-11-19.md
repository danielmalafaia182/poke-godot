# Limpeza da cena de hunt antiga (ciclo 3)

A hunt jogável é só a cena nova (`caca_sim.tscn`, sobre a simulação) desde a fase 2; as 451 hunts do snapshot são
simuladas. A cena antiga (`Caca.tscn`, `caca.gd`, `caca_base.gd`) existia para a hunt de antes e para os testes do P04.

## Migrado para a cena nova (ou para a sim)

| De | Para | O que cobre |
| --- | --- | --- |
| `test_mapa_entre_hunts.gd` (começava na cena antiga) | o mesmo arquivo, começando em `caca_sim.tscn` | mapa-múndi dentro da hunt abre sem sair, fechar volta, viajar zera o contador, preserva líder/HP/estoque, mesma hunt = instância nova (8/8) |
| `test_qualidade.gd`, parte dos cartões do time | `testes/test_hud_time.gd` (cena nova) | cartões do time não são recriados com HP/XP, outro Pokémon intacto, cura refletida, adição/remoção sem recriar (6/6) |
| `test_importacao_especies.gd`, "Hunt Bulbasaur/Charmander/Squirtle" | o mesmo arquivo, pela sim (`dados.hunts`) | a hunt de cada inicial tem 15 spawns da espécie (A) |
| `test_cidade_qualidade.gd`, "cidade para caça" | o mesmo arquivo, instanciando `caca_sim.tscn` | a hunt abre com os 15 selvagens e a volta restaura a posição na cidade |
| `test_consistencia.gd`, `test_progressao_treinador.gd` | o mesmo arquivo, sem o bloco da cena antiga | o resto (coleção, save, XP) segue; "captura inválida não consome bola" e "derrota dá XP uma vez" já estão na sim e no `test_caca_sim` |

## Apagado

**Cena antiga:** `Caca.tscn`, `caca.gd`, `caca_base.gd`.

**Scripts que só a cena antiga usava:** `animacao_geodude.gd`, `animacao_selvagem.gd`, `apresentacao_caca.gd`,
`busca_caminho_selvagem.gd`, `dados_navegacao.gd`, `efeito_captura.gd`, `efeito_cura.gd`, `efeito_impacto.gd`,
`efeito_troca.gd`, `indicador_selvagem.gd`, `movimento_selvagens.gd`, `treinador_caca.gd`.

**Testes do P04 que só existiam por causa dela (23)** — combate, movimento e configuração da cena antiga; o que tinham de
regra do original está nos testes da sim (`test_sim_regras`, `test_sim_caminho`, `test_sim_alvo`, `test_sim_ilhas`,
`test_sim_regras_usuario`, `test_caca_sim`):
`test_ajustes_hunt`, `test_ataques_independentes`, `test_calibracao_combate`, `test_cerco_acesso`, `test_combate_rapido`,
`test_configuracao_hunts`, `test_cooldown_troca`, `test_dano_atributos`, `test_dano_candidato`, `test_dificuldade_hunts`,
`test_golpes_combate`, `test_hunt_generica`, `test_hunt_larvitar`, `test_hunt_referencias`, `test_loot_combate_fiel`,
`test_movimento_selvagens`, `test_nivel_formula_selvagem`, `test_ofensiva_selvagens`, `test_preparo_ataque`,
`test_registro_combate`, `test_revisao`, `test_troca_hunt_barras`, `test_vida_selvagem_candidato`.

**Arquivos de validação antigos (P01/P02)** com cópias desses testes e os logs: `validacao_p01/`, `validacao_p02/`,
`verificacao/` (ficam no histórico do git).

## Ficou

Os 20 testes restantes do P04 (`testes/rodar_antigos.sh`): 20/20. O mapa-múndi abre sempre a cena nova.
