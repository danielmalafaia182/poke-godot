# Prioridades de descoberta do Depot

O Depot usa a mesma fonte de dados do TEAM. A interface não altera Pokémon,
HP, XP, IVs ou qualidade ao consultar uma ficha.

## Já confirmado e exibido com valores reais

| Campo | Origem |
| --- | --- |
| Nível | DadosPokemon.nivel |
| IV individual e soma /192 | Seis campos persistidos; máximo de 32 por campo |
| Qualidade e classificação | Valor persistido e faixas existentes |
| Tipos | Base registrada de cada espécie |
| Atributos | round(nível/100 × (base + 2×IV) × qualidade^expoente) |
| Power | round(soma dos seis atributos calculados × qualidade) |
| Active / Team / Stored | Líder e coleções reais do estado |

Os expoentes são 0,95 para HP/Vel e 0,8 para os demais. As fórmulas já estavam
portadas do cliente original em regras_pokemon.gd; este pacote reaproveita essas
funções. Não substitui HP de combate pelo HP bruto da ficha. Espécies sem base
registrada apresentam “—” nos atributos ausentes e em Power.

## P1 — campos e filtros ainda sem suporte completo

| Prioridade | Pendência | Evidência necessária | Comportamento desta versão |
| --- | --- | --- | --- |
| P1 | Família | Confirmar se agrupa evolução, conta ou outro conceito; obter identificador e regras do seletor atual | Família —; filtro e abas indisponíveis |
| P1 | Shiny | Integrar o booleano individual ao modelo e save; conferir sprite, destaque e filtro do Depot | Shiny —; filtro indisponível |
| P1 | Held e filtros especiais | Identificar dados individuais e significado exato de cada ícone; conferir respostas e ações do Depot original | Held —; filtros sem metadados desativados |
| P1 | Emblemas pequenos junto dos retratos | Confirmar significado do símbolo azul e de eventuais símbolos de vínculo/estado | Não desenhar um emblema que afirme um estado desconhecido |
| P1 | Mais espécies | Registrar atributos-base, tipos e sprites confiáveis antes de habilitar seu cálculo | Placeholder para informação ausente |

O booleano shiny aparece em mensagens do original, mas ainda não existe no
DadosPokemon deste projeto. Ausência de campo não significa falso. O cliente
extraído é de uma versão anterior à captura de referência do Depot: não se deve
presumir a semântica de filtros mais novos a partir apenas da aparência.

Próxima investigação: comparar payload de um indivíduo normal, um shiny e um
indivíduo com o símbolo azul no Depot; acompanhar cada seletor e as ações do
original. Registrar nomes dos campos, limites, estados e persistência antes de
implementar. Não há necessidade de alterar fórmulas de Power/IV para isso.

## P2 — acabamento e serviços posteriores

Confirmar os assets exatos dos ícones ainda representados por símbolos de texto.
Implementar serviços dos demais NPCs e reprodução/família em etapas próprias.
Este pacote só ajusta os serviços já existentes de Nurse Joy e Depot.
