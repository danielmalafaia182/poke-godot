# Fase 0 — coleta e contrato

Kit para tirar do jogo original tudo o que a réplica precisa, de forma repetível.
Nada aqui altera o projeto Godot; a integração vem na fase 1.

## Conteúdo

| Arquivo | Para que serve |
| --- | --- |
| `ferramentas/coletor/coletor_poke.js` | Roda numa página do jogo e grava um snapshot completo numa pasta escolhida |
| `ferramentas/gravador/gravador_ws.user.js` | Grava as mensagens do jogo enquanto você joga (sem token) |
| `ferramentas/gravador/analisar_gravacao.py` | Resume gravações em cadência, faixas de dano, XP, loot, capturas |
| `ferramentas/protocolo/gerar_protocolo.py` | Gera `protocolo.json` a partir do cliente original e dos logs |
| `ferramentas/importador/importar_snapshot.py` | Converte o snapshot em dados normalizados para o Godot |
| `ferramentas/importador/diff_snapshots.py` | Mostra o que mudou entre dois snapshots |
| `dados/protocolo.json` | Catálogo atual: 136 tipos de mensagem, 65 comandos, 72 eventos |
| `dados/correcoes.json` | Correções sobre o publicado (por ora: IV até 32) |

Scripts Python usam só a biblioteca padrão (Python 3.9+).

## 1. Coletar um snapshot

1. Abra qualquer página de `https://poke.idleworld.online` (a Pokepedia serve; não precisa estar logado).
2. F12 → Console → cole o conteúdo de `coletor_poke.js` → Enter.
3. No painel do canto inferior direito, marque as etapas e escolha um modo:
   - **Baixar como ZIPs** (qualquer navegador, recomendado no Firefox): baixa um ZIP por etapa
     (`snapshot_AAAA-MM-DD_dados.zip`, `_hunts`, `_mapas`, `_atlas`, `_outfits`, `_icones`, `_manifest`).
     Extraia todos na mesma pasta: eles se juntam em `snapshot_AAAA-MM-DD/`.
   - **Escolher pasta e coletar** (só Chrome/Edge): grava direto na pasta escolhida.
4. O resultado tem `manifest.json` (URL, tamanho e SHA-256 de cada arquivo) e um `manifest_<etapa>.json` por ZIP.

No Firefox, o console pede que você digite `allow pasting` (ou `permitir colar`) antes da primeira colagem.

Etapas: `dados` (catálogos), `hunts` (454 configurações + NPCs), `mapas` (um por hunt),
`atlas` (97 páginas de map-items), `outfits` (sprites de Pokémon/NPC), `icones` (itens, tipos, efeitos).
Faz só GET de arquivos públicos, em sequência, com pausa de 60 ms, sem enviar cookies.

## 2. Gravar sessões de jogo

- **Tampermonkey/Violentmonkey:** instale `gravador_ws.user.js`. Grava desde o carregamento de `/play`.
- **Sem extensão:** com o jogo aberto, cole o arquivo no console. Ele se liga ao WebSocket já aberto
  na próxima mensagem que o cliente enviar (poucos segundos).

O painel no canto inferior esquerdo mostra o total, pausa, exporta a sessão em JSONL e limpa.
Chat e DM de outros jogadores são descartados. URL, token e cookies nunca são gravados.
Dica: abra o painel do time no começo da sessão, para a gravação registrar os stats do Pokémon ativo.

Depois: `python3 analisar_gravacao.py poke_ws_*.jsonl --json resumo.json`

## 3. Importar e comparar

```
python3 ferramentas/importador/importar_snapshot.py snapshot_AAAA-MM-DD \
        --correcoes dados/correcoes.json --saida dados/gerados
python3 ferramentas/importador/diff_snapshots.py snapshot_ANTIGO snapshot_NOVO --saida DIFF.md
```

Saída do importador: `especies.json`, `golpes.json`, `itens.json`, `hunts.json`, `cidades.json`,
`regras.json`, `relatorio_importacao.json`. A mesma entrada gera sempre os mesmos bytes.

## Fatos já confirmados nesta fase

- Ticks de 200 ms; snapshot `field` a cada 400 ms; passo herói/treinador 500 ms, selvagem 1000 ms.
- Aliado ataca a cada 1600 ms (Bulbasaur/Seed Bomb, Gastly/Lick); cada selvagem a cada 2000 ms.
- HP do selvagem = 35 × stat de HP, mínimo 120.
- XP base = `experience` da espécie; VIP +50% em parcela separada.
- O mesmo golpe tem cooldown diferente por espécie (234 de 407 golpes variam). Por isso o importador
  guarda os golpes dentro de cada espécie, e `golpes.json` traz o valor mais comum + as variações.
- Chance de loot no `creatures.json` está em 1/100.000.
