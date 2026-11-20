# Teste do build do ciclo 4: correções do ciclo 5, lado a lado

Evidências do usuário em `referencia_visual/teste_ciclo4/` (prints e os dois vídeos, que são do jogo original; quadros
extraídos em `referencia_visual/teste_ciclo4/quadros/`). Nosso jogo capturado em 1880 × 954 por
`ferramentas/visual/print_tela.gd`, com APPDATA isolado.

| Item | Arquivo | O que mostra |
| --- | --- | --- |
| 1. Barras do My Pokes | `01_my_pokes_barras_iv.png` | Evidência `mypokes.PNG` × a barra agora pelo IV (IV 15 de 32 = 47%); o número segue sendo o stat |
| 2. Painel de captura | `02_painel_captura.png` | Original (vídeo) × nosso: o painel do canto inferior direito aparece a cada lançamento, inclusive no Auto-Catch |
| 3. Pokédex | `03_pokedex.jpg` | Original × nosso: grade de 7 colunas, sprites dentro do cartão; abre em ~200 ms na 1ª vez e 13 ms depois |
| 4. Mochila | (sem mudança) | O usuário aprovou |
| 5. Animação da Pokébola | `05_animacao_pokebola.png` | Arremesso e folha de captura do cliente (spawnCatchFx) na hunt |
| 6. Botão Zzz | `06_sem_zzz_canto.png` | Hunt sem o botão flutuante; a Soneca só no dock |
| 7. Perfil | (sem mudança) | O usuário aprovou |
| 8. Casa da porta do Pokémon Center | `08_tile_porta_pc_lado_a_lado.png`, `08_tile_porta_pc_liberado.png` | Evidência `tile instrasponivel.PNG` (personagem sob a casa −2,−4) × colisão com as casas bloqueadas em vermelho: (−2,−4) liberada (E, `balanceamento.json` cidade.casas_liberadas; o original bloqueia com a peça 8274) |
| 9–10. Troca de líder e cooldown | `09_10_troca_lider_cooldown.png` | Vídeo `cooldown.mp4` (original) × nosso: o novo líder sobe para o 1º lugar, o antigo vai para a casa dele, 5 s de recarga com a contagem |
| 11. Fontes | `11_fontes_time_ampliado.png` | Evidência `fontes.PNG` × nosso, ampliado 3×: renderização LCD e as medidas do CSS (.phud) |
| 98. Novo jogo | `98_novo_jogo_confirmacao.png` | ⚙ → Novo jogo pede confirmação; backup em `user://backups/progresso_<data>.json` antes de apagar |
| 99. Reabrir | `99_reabrir_mensagem.txt` | A mensagem ao reabrir 3 h depois: quanto ficou fechado, os 15 min que contaram, o que se perdeu e por quê, o resultado |
| Decisão: coluna por bola | `c4d_gerenciamento_captura_colunas.png` | Original (vídeo) × nosso Gerenciamento de Captura com uma coluna por bola |

Testes: `test_team_fiel`, `test_janelas_ciclo2`, `test_ciclo_lote2`, `test_cidade_mapa`, `test_troca_time`,
`test_reabrir.sh`, `test_novo_jogo_config.sh`, `test_captura_jogo_novo`.
