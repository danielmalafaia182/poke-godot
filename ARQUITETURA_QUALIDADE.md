# Revisão aplicada — 05/11/2026

Base: `poke-idle(1).rar`. As quatro melhorias solicitadas foram implementadas no
mesmo pacote, mantendo as interfaces das cenas e o formato do progresso.

| Responsabilidade | Arquivo | Regra |
|---|---|---|
| Interface das cenas | `estado_jogo.gd` | Encaminha chamadas, propriedades e sinais; não mantém cópias dos módulos |
| Estoques e itens do depot | `inventario_jogo.gd` | Consumo e transferência BAG/DEPOT no mesmo proprietário |
| Preferências automáticas | `configuracao_auto_helper.gd` | Usa catálogo/estoque do inventário; não conhece cenas |
| TEAM/BOX, líder, HP e XP | `colecao_pokemon.gd` | Conserva as instâncias e rejeita IDs repetidos |
| Perfil e XP acumulado do treinador | `perfil_treinador.gd` | Separados do XP individual do Pokémon |
| Agendamento, fechamento e aviso de save | `coordenador_salvamento.gd` | Nó criado pela fachada; agrupa gravações e mantém aviso global |
| Formato, integridade e arquivos | `salvamento_local.gd` | Inalterado; valida tudo antes de restaurar |
| Vida e identidade do selvagem | `encontro_selvagem.gd` | Uma instância por nascimento, inclusive respawns no mesmo slot |
| Cartão de um membro do time | `cartao_pokemon_hud.gd` | Atualiza valores; emite intenção de selecionar líder |
| Composição do HUD | `painel_time.gd` | Reconcilia membros e encaminha sinais ao cartão correto |

## Encontros

`caca.gd` mantém `Array[EncontroSelvagem]`. `encontro_atual` aponta diretamente
para um membro dessa população. `indice_alvo`, `pokemon_selvagem`,
`imagem_selvagem` e `vida_selvagem` são acessos derivados, não cópias independentes.
A imagem modelo é usada apenas quando não há alvo.

O objeto guarda ID, slot, indivíduo, HP máximo/atual, estado VIVO/DERROTADO/RESOLVIDO,
recompensa, início da captura e dados tipados de movimento/respawn. Mantém uma
referência ao sprite para compatibilidade com a simulação atual; não instancia
efeitos e não controla sua duração. Não é ainda uma simulação desacoplada de Godot.
A aproximação e o timer de combate continuam sendo tarefas do controlador.

A marca de recompensa é reservada antes de conceder XP. A captura é reservada
antes de consumir a bola. O slot é resolvido no estado do jogo antes do evento
visual. Um novo respawn recebe outro objeto e ID; eventos carregam valores e não
referências ao objeto ou ao sprite reutilizado. Esses IDs são locais à sessão,
não são IDs do protocolo original nem autenticação para uma futura versão online.

## Compatibilidade e sinais

Os nomes públicos de `EstadoJogo` permanecem. Propriedades encaminham leitura e
escrita aos módulos para atender cenas e restaurador existentes. Isso preserva
compatibilidade, mas ainda permite mutações diretas nos arrays/dicionários pelos
consumidores antigos. Novas funcionalidades devem preferir os métodos da fachada.
Não há encapsulamento total nem auditoria completa de todos os scripts nesta etapa.

O sinal antigo `pokemon_alterado` permanece para painéis existentes. O novo
`individuo_alterado(pokemon)` atualiza somente o cartão correspondente e a barra
sobre o aliado. `depot_alterado` reconcilia membros sem recriar sobreviventes;
`lider_alterado` muda o destaque; `perfil_alterado` atualiza o cabeçalho.
A criação de barras não sincroniza mais XP: a coleção/carregamento fazem isso.
Outros painéis e cartões de recompensa não foram reescritos nesta entrega.

## Evidências dos anexos

O `loogs.txt` fornecido coincide byte a byte com o log arquivado no projeto.
São 71 objetos JSON, incluindo 20 snapshots `field`, três `field-kill`, três
`poke-xp` e três `catch-result`. A grade `field-init` também coincide com a usada.

- As três derrotas concedem 12 XP ao treinador e ao Pokémon: base 8 + VIP 4.
- As tentativas com Super Ball têm dois resultados negativos e um positivo.
  Essa amostra não determina a chance de captura.
- `hits.slot` identifica o selvagem atingido; `targetSlot` pode já ter mudado.
  A ordem entre snapshots com hits e eventos de derrota varia na coleta.
- `heroStepMs=500`, `trainerStepMs=500`, `mobStepMs=1000`, `tickMs=200`.
  Tick não prova cooldown de poção, golpe ou respawn.
- HP e XP da conta original não foram importados para o progresso local.

O print orienta a composição já existente: time à esquerda, menu acima,
Auto-Helper e recompensas à direita, captura embaixo. O HUD foi renderizado após
a refatoração em 1152×648. Chat, Shop, boosts, loot e acabamento visual completo
não foram implementados por esta revisão de código.
