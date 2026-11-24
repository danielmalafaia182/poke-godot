# Revisão estrutural e de segurança — 23/11/2026

Base da revisão: `b2f635c`, posterior à tag local `v1.0` (`153c14a`).
O Game Master foi preservado no editor e no executável. Nenhum save real foi usado.

## Correções entregues

- **Perfis de regras:** nomes e caminhos validados; tipos, faixas, números não finitos,
  opções e campos de tabelas conferidos; edição recusada não altera o arquivo válido.
- **Leitura externa:** `.tres` de usuário é tratado como dados. Associação a script,
  construtores de objetos e referências externas não são executados. O dock usa JSON
  para entrada de valores. Resources binários do pacote continuam suportados.
- **Restauração:** grava defaults explícitos; não apaga um override deixando reaparecer
  o valor modificado da camada inferior. Criar perfil não sobrescreve um existente.
- **Recarga:** ponto único em `EstadoJogo`; invalida dez serviços e a ponte da cidade;
  atualiza o mapa já aberto; preserva o snapshot da hunt atual.
- **Novo jogo:** exige save e backups válidos; verifica erros antes de remover progresso;
  tenta recuperação em caso de remoção parcial e mantém os backups.
- **Vazamento real corrigido:** o painel legado de captura ficava fora da árvore e
  sobrevivia à hunt. Agora pertence ao HUD oculto e é liberado com a cena.
- **Verificação e build:** dados isolados, logs completos, detecção de falsos sucessos,
  falha em erro de script/vazamento, destino novo obrigatório, três fases no executável
  e manifesto SHA-256. O comando de build não apaga versões anteriores.
- **Evidência:** o catálogo não converte a letra A em comprovação automática. B e D
  têm significados distintos; captura c/k permanecem F. Corrigidas unidades inferidas
  por substrings como `_s` em `shiny`/`selvagem`.

## Validação

| Verificação | Resultado | Evidência local |
| --- | --- | --- |
| Testes GDScript autônomos | 83/83 no resultado consolidado | `saida_testes/qualidade/refino_consolidado.json` |
| Conjunto final das áreas alteradas | 12/12 scripts | `saida_testes/qualidade/refino_final_smoke/resumo.json` |
| Segurança de regras | 42/42 verificações | log de `test_regras_seguranca.gd` |
| Recarga, dez serviços e mapa aberto | 18/18 verificações | log de `test_recarga_regras.gd` |
| Falhas ao iniciar novo jogo | 6/6 verificações | log de `test_novo_jogo_falhas.gd` |
| Simulação anterior versus atual | 3/3 sequências idênticas | `testes/referencia_sim.json`, base `b2f635c` |
| Compatibilidade e novo jogo em dois processos | aprovados; novo jogo 12/12 verificações | `saida_testes/qualidade/poke_fluxos_0wi454ig/` |
| Save antigo e gravação em thread | 8/8 verificações | logs temporários `poke_save_thread__pj5jju6` |
| Encerramento durante gravação | 15/15, sem perder gravação confirmada | mesmo diretório temporário; todas as 15 interrupções ocorreram durante escrita |
| Testes Python do critério de qualidade | 6/6 | `ferramentas/qualidade/test_verificar.py` |
| Testes Python de metadados | 5/5 | `ferramentas/regras/test_catalogo.py` |
| Testes Python de destino do build | 2/2 | `ferramentas/build/test_montar_build.py` |
| Executável final | três fases aprovadas | `saida_testes/build/refino_final_20261123_r2/` |

O consolidado mantém a execução inicial e as reexecuções com seus caminhos de origem.
A primeira suíte terminou em 82/83 por um erro de inferência de tipo no novo teste do
mapa. O teste foi corrigido e passou com 18/18; a checagem final também o executou.
O histórico original não foi sobrescrito nem os erros foram filtrados do relatório.

O executável foi exercitado em modo headless: jogo novo, tutorial, caça Geodude, salvar,
fechar, reabrir e importar uma fixture. Também foram verificados habilitar GM nas
Configurações, abrir pelo F12, editar/restaurar em `user://` e preservar os 22 grupos
originais mais o perfil empacotado `xp100`. A seleção pessoal de perfil não é exportada.

Build: `builds/refino_final_20261123_r2/PokeIdle.exe`.
Integridade dos arquivos: `builds/refino_final_20261123_r2/manifesto.json`.
A tag e o build `v1.0` foram mantidos.

## Escopo e limites

Os 202 literais do catálogo e as declarações executáveis dos 22 scripts gerados de
regras permaneceram iguais; só seus comentários/metadados mudaram. Não houve ajuste
de XP, dano, captura, loot ou progressão. Os três gabaritos determinísticos cobrem
Rhydon, Orre e começo de jogo; não equivalem a provar todas as combinações possíveis.

Esta revisão não repetiu a coleta do original, a validação estatística de todas as
gravações, nem a medição de FPS com janela em foco nas 451 hunts. Os números históricos
de desempenho e fidelidade da v1.0 não são apresentados como novas medições.

O projeto ainda tem fachadas e painéis legados grandes. As fronteiras, contratos,
persistência e ferramentas de manutenção foram fortalecidos; não houve reorganização
cosmética de todos os arquivos. `ARQUITETURA.md` orienta a evolução incremental.
Orre, viés de Larvitar e regras de classe 3 continuam com o status anterior.

Alterações preexistentes no `project.godot`, perfil `xp100`, arquivos de referência e
UIDs alheios à revisão foram preservadas. Os commits locais contêm somente esta revisão.
Não houve push, acesso ao save real ou envio de gravações/HARs.

Decisões de produto necessárias: nenhuma nesta rodada.
