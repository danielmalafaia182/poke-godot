# Preços de NPC: compra no Mark × venda ao Mark (como a simulação usa)

Gerado por `ferramentas/importador/relatorio_precos.py` a partir de `dados/gerados/itens.json` (não editar à mão).

## Leitura dos campos

- `items.json` do snapshot: `npcPrice` = o que o Mark **paga** (C: a dica do item mostra "Mark paga: npcPrice"), `priceGold` = preço de **compra** (C: "Preço: priceGold"; A: bolas com o mesmo campo no `balls.catalog`). Unidade: ouro inteiro nos dois.
- Importação: `npcPrice → precoNpc`, `priceGold → precoGold`, `category → categoria`. Conferência campo a campo contra o snapshot cru: **0 divergências**.
- Venda (C, lista de venda do Mark no cliente): só item com `npcPrice > 0` e categoria fora de heal/revive/stone, salvo os ids 205 e 206 (Revive e Max Revive aposentados). O teto "venda ≤ compra" (E) fica só como proteção.
- Os únicos itens com `npcPrice > priceGold` no catálogo são 200, 201, 202, 203, 204 (as poções): o npcPrice delas não é preço de venda, porque o Mark não compra poções. **Não era erro de importação** (os campos estão nos nomes e na unidade certos); o erro estava na regra de venda do lote 1, que tratava poções como vendáveis (com o teto). Corrigido em `sim/servico_cidade.gd`.

## Resumo

- Itens com preço (compra ou npcPrice): 393. Vendáveis ao Mark: 370. Compráveis: 5 (poções) + 4 bolas.
- **Itens em que a venda supera a compra: 0** (nenhum)

## Bolas (A: balls.catalog)

| id | bola | compra | o Mark compra? |
|---|---|---|---|
| 1 | Poké Ball | 5 | não |
| 2 | Great Ball | 20 | não |
| 3 | Super Ball | 50 | não |
| 4 | Ultra Ball | 130 | não |
| 6 | Idle Ball | não vende (buyable false) | não |
| 7 | Golden Idle Ball | não vende (buyable false) | não |
| 5 | Master Ball | não vende (buyable false) | não |

## Itens

| id | item | categoria | compra (priceGold) | npcPrice (cru) | venda que a sim usa | venda > compra? | obs. |
|---|---|---|---|---|---|---|---|
| 1 | Air Tank | loot | — | 1000 | 1000 |  |  |
| 2 | Ancient Stone | stone | — | 50000 | 0 |  | Mark não compra (stone) |
| 3 | Armadillo Claw | loot | — | 147 | 147 |  |  |
| 4 | Bag of Pollen | loot | — | 40 | 40 |  |  |
| 5 | Band Aid | loot | — | 1 | 1 |  |  |
| 6 | Bat Wing | loot | — | 78 | 78 |  |  |
| 7 | Bee Sting | loot | — | 54 | 54 |  |  |
| 8 | Belt of Champion | loot | — | 1000 | 1000 |  |  |
| 9 | Bird Beak | loot | — | 30 | 30 |  |  |
| 10 | Bitten Apple | loot | — | 7 | 7 |  |  |
| 11 | Blue Fish Fin | loot | — | 500 | 500 |  |  |
| 12 | Blue Vines | loot | — | 500 | 500 |  |  |
| 13 | Bone | loot | — | 123 | 123 |  |  |
| 14 | Bottles of Poison | loot | — | 1 | 1 |  |  |
| 15 | Bug Antenna | loot | — | 96 | 96 |  |  |
| 16 | Bug Gosme | loot | — | 1 | 1 |  |  |
| 17 | Bug Venom | loot | — | 371 | 371 |  |  |
| 18 | Bulb | loot | — | 132 | 132 |  |  |
| 19 | Bull Tail | loot | — | 500 | 500 |  |  |
| 20 | Butterfly Wing | loot | — | 66 | 66 |  |  |
| 21 | Chansey Egg | loot | — | 500 | 500 |  |  |
| 22 | Chicken Feet | loot | — | 500 | 500 |  |  |
| 23 | Cocoon Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 24 | Colored Feather | loot | — | 168 | 168 |  |  |
| 25 | Comb | loot | — | 100 | 100 |  |  |
| 26 | Crab Claw | loot | — | 90 | 90 |  |  |
| 27 | Crystal Cube | loot | — | 500 | 500 |  |  |
| 28 | Crystal Stone | stone | — | 50000 | 0 |  | Mark não compra (stone) |
| 29 | Crystal Tail | loot | — | 500 | 500 |  |  |
| 30 | Dark Gem | loot | — | 1 | 1 |  |  |
| 31 | Darkness Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 32 | Diving Mask | loot | — | 1000 | 1000 |  |  |
| 33 | Dodo Cube | loot | — | 500 | 500 |  |  |
| 34 | Dodrio Feather | loot | — | 102 | 102 |  |  |
| 35 | Dome Fossil | loot | — | 500 | 500 |  |  |
| 36 | Dragon Scale | loot | — | 1 | 1 |  |  |
| 37 | Dragon Tail | loot | — | 500 | 500 |  |  |
| 38 | Dragon Tooth | loot | — | 610 | 610 |  |  |
| 39 | Earth Ball | loot | — | 1 | 1 |  |  |
| 40 | Earth Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 41 | Electric Box | loot | — | 20 | 20 |  |  |
| 42 | Electric Rat Tail | loot | — | 132 | 132 |  |  |
| 43 | Electric Tail | loot | — | 500 | 500 |  |  |
| 44 | Enchanted Gem | loot | — | 1 | 1 |  |  |
| 45 | Enigma Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 46 | Essence of Fire | loot | — | 1 | 1 |  |  |
| 47 | Farfetchd Stick | loot | — | 300 | 300 |  |  |
| 48 | Feather | loot | — | 8 | 8 |  |  |
| 49 | Feather Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 50 | Female Ear | loot | — | 147 | 147 |  |  |
| 51 | Fins | loot | — | 1000 | 1000 |  |  |
| 52 | Fire Horse Foot | loot | — | 114 | 114 |  |  |
| 53 | Fire Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 54 | Fire Tail | loot | — | 132 | 132 |  |  |
| 55 | Fish Fin | loot | — | 500 | 500 |  |  |
| 56 | Fox Tail | loot | — | 1000 | 1000 |  |  |
| 57 | Fur | loot | — | 13 | 13 |  |  |
| 58 | Future Orb | loot | — | 16 | 16 |  |  |
| 59 | Ghost Essence | loot | — | 1 | 1 |  |  |
| 60 | Giant Fin | loot | — | 500 | 500 |  |  |
| 61 | Giant Piece of Fur | loot | — | 180 | 180 |  |  |
| 62 | Giant Ruby | loot | — | 200 | 200 |  |  |
| 63 | Goggles | loot | — | 500 | 500 |  |  |
| 64 | Gosme | loot | — | 78 | 78 |  |  |
| 65 | Gyarados Tail | loot | — | 500 | 500 |  |  |
| 66 | Heart Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 67 | Helix Fossil | loot | — | 500 | 500 |  |  |
| 68 | Horn | loot | — | 25 | 25 |  |  |
| 69 | Horn Drill | loot | — | 500 | 500 |  |  |
| 70 | Ice Orb | loot | — | 33 | 33 |  |  |
| 71 | Ice Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 72 | Iron Bracelet | loot | — | 114 | 114 |  |  |
| 73 | Kanga Ear | loot | — | 500 | 500 |  |  |
| 74 | Karate Duck | loot | — | 123 | 123 |  |  |
| 75 | Kick Machine | loot | — | 135 | 135 |  |  |
| 76 | Leaf Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 77 | Leaves | loot | — | 9 | 9 |  |  |
| 78 | Linearly Guided Hypnosis | loot | — | 410 | 410 |  |  |
| 79 | Locksmith of Shell | loot | — | 24 | 24 |  |  |
| 80 | Luck Medallion | loot | — | 1000 | 1000 |  |  |
| 81 | Magikarp Fin | loot | — | 3 | 3 |  |  |
| 82 | Magma Foot | loot | — | 500 | 500 |  |  |
| 83 | Magnet | loot | — | 90 | 90 |  |  |
| 84 | Magnetic Cube | loot | — | 500 | 500 |  |  |
| 85 | Male Ear | loot | — | 147 | 147 |  |  |
| 86 | Martial Arts Scroll | loot | — | 185 | 185 |  |  |
| 87 | Metal Stone | stone | — | 50000 | 0 |  | Mark não compra (stone) |
| 88 | Microphone | loot | — | 147 | 147 |  |  |
| 89 | Mimic Clothes | loot | — | 500 | 500 |  |  |
| 90 | Mushroom | loot | — | 114 | 114 |  |  |
| 91 | Nail | loot | — | 10 | 10 |  |  |
| 92 | Neodymium Magnet | loot | — | 500 | 500 |  |  |
| 93 | Old Amber | loot | — | 500 | 500 |  |  |
| 94 | Onix Tail | loot | — | 371 | 371 |  |  |
| 95 | Piece of Diglett | loot | — | 78 | 78 |  |  |
| 96 | Piece of Steel | loot | — | 1 | 1 |  |  |
| 97 | Pinsir Horn | loot | — | 500 | 500 |  |  |
| 98 | Plant Foot | loot | — | 123 | 123 |  |  |
| 99 | Plant Tail | loot | — | 114 | 114 |  |  |
| 101 | Pot of Lava | loot | — | 18 | 18 |  |  |
| 102 | Pot of Moss Bug | loot | — | 8 | 8 |  |  |
| 103 | Psychic Spoon | loot | — | 180 | 180 |  |  |
| 104 | Psyduck Mug | loot | — | 129 | 129 |  |  |
| 105 | Punch Machine | loot | — | 135 | 135 |  |  |
| 106 | Punch Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 107 | Rat Tail | loot | — | 54 | 54 |  |  |
| 108 | Red Wing | loot | — | 114 | 114 |  |  |
| 109 | Rock Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 110 | Rubber Ball | loot | — | 1 | 1 |  |  |
| 111 | Ruby | loot | — | 100 | 100 |  |  |
| 112 | Sandbag | loot | — | 15 | 15 |  |  |
| 113 | Screw | loot | — | 1 | 1 |  |  |
| 114 | Scythe | loot | — | 500 | 500 |  |  |
| 115 | Seahorse Tail | loot | — | 500 | 500 |  |  |
| 116 | Seal Tail | loot | — | 147 | 147 |  |  |
| 117 | Seed | loot | — | 1 | 1 |  |  |
| 118 | Ski Poles | loot | — | 1000 | 1000 |  |  |
| 119 | Slow Tail | loot | — | 225 | 225 |  |  |
| 120 | Small Stone | loot | — | 1 | 1 |  |  |
| 121 | Snake Tail | loot | — | 78 | 78 |  |  |
| 122 | Snow Skis | loot | — | 500 | 500 |  |  |
| 123 | Snowball | loot | — | 1 | 1 |  |  |
| 124 | Squirtle Hull | loot | — | 132 | 132 |  |  |
| 125 | Sticky Hand | loot | — | 120 | 120 |  |  |
| 126 | Stone Orb | loot | — | 17 | 17 |  |  |
| 127 | Strange Flower | loot | — | 114 | 114 |  |  |
| 128 | Strange Rock | loot | — | 159 | 159 |  |  |
| 129 | Strange Spike | loot | — | 135 | 135 |  |  |
| 130 | Strange Thing | loot | — | 147 | 147 |  |  |
| 131 | Straw | loot | — | 1 | 1 |  |  |
| 132 | Tentacruel Tentacle | loot | — | 500 | 500 |  |  |
| 133 | Thunder Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 134 | Tongue | loot | — | 410 | 410 |  |  |
| 135 | Tooth | loot | — | 8 | 8 |  |  |
| 136 | Topknot | loot | — | 147 | 147 |  |  |
| 137 | Traces of Ghost | loot | — | 180 | 180 |  |  |
| 138 | Venom Flute | loot | — | 78 | 78 |  |  |
| 139 | Venom Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 140 | Water Gem | loot | — | 1 | 1 |  |  |
| 141 | Water Pendant | loot | — | 10 | 10 |  |  |
| 142 | Water Stone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 143 | Wool Ball | loot | — | 69 | 69 |  |  |
| 200 | Small Potion | heal | 5 | 50 | 0 |  | Mark não compra (heal); no cru npcPrice > compra (50 > 5), não usado |
| 201 | Great Potion | heal | 10 | 150 | 0 |  | Mark não compra (heal); no cru npcPrice > compra (150 > 10), não usado |
| 202 | Ultra Potion | heal | 22 | 400 | 0 |  | Mark não compra (heal); no cru npcPrice > compra (400 > 22), não usado |
| 203 | Hyper Potion | heal | 55 | 800 | 0 |  | Mark não compra (heal); no cru npcPrice > compra (800 > 55), não usado |
| 204 | Ultimate Potion | heal | 135 | 1500 | 0 |  | Mark não compra (heal); no cru npcPrice > compra (1500 > 135), não usado |
| 205 | Revive | revive | — | 40 | 40 |  |  |
| 206 | Max Revive | revive | — | 350 | 350 |  |  |
| 289 | Small Eagle Feather | loot | — | 2500 | 2500 |  |  |
| 299 | Big Eagle Feather | loot | — | 6000 | 6000 |  |  |
| 321 | Dragon Slime | loot | — | 3500 | 3500 |  |  |
| 2380 | Ice Bra | loot | — | 1000 | 1000 |  |  |
| 5002 | Azure Shard | loot | — | 500 | 500 |  |  |
| 5008 | Big Bug Gosme | clan | — | 100 | 100 |  |  |
| 5009 | Big Enchanted Gem | clan | — | 100 | 100 |  |  |
| 5010 | Big Poison Bottle | clan | — | 100 | 100 |  |  |
| 5020 | Cerise Shard | loot | — | 500 | 500 |  |  |
| 5024 | Corrupted Ice Orb | loot | — | 10 | 10 |  |  |
| 5025 | Corrupted Pot of Moss Bug | loot | — | 10 | 10 |  |  |
| 5028 | Cyan Nightmare Gem | loot | — | 500 | 500 |  |  |
| 5054 | Googles | loot | — | 500 | 500 |  |  |
| 5056 | Harlequin Shard | loot | — | 500 | 500 |  |  |
| 5069 | Malefic Essence | loot | — | 500 | 500 |  |  |
| 5071 | Metal Scraps | loot | — | 10 | 10 |  |  |
| 5075 | Naturia Essence | loot | — | 10 | 10 |  |  |
| 5076 | Neutral Essence | loot | — | 10 | 10 |  |  |
| 5077 | Nightmare Gem | loot | — | 10 | 10 |  |  |
| 5078 | Nightmare Ore | loot | — | 10 | 10 |  |  |
| 5087 | Psychic Mustache | loot | — | 10 | 10 |  |  |
| 5089 | Psycraft Essence | loot | — | 10 | 10 |  |  |
| 5101 | Seavell Essence | loot | — | 10 | 10 |  |  |
| 5109 | Solid Ice Cube | clan | — | 100 | 100 |  |  |
| 5200 | Rough Gemstone | stone | — | 5000 | 0 |  | Mark não compra (stone) |
| 5301 | Big Screw | clan | — | 100 | 100 |  |  |
| 5302 | Compressed Fire | clan | — | 100 | 100 |  |  |
| 5303 | Pile of Seeds | clan | — | 100 | 100 |  |  |
| 5304 | Compressed Steel | clan | — | 100 | 100 |  |  |
| 5305 | Solid Water Gem | clan | — | 100 | 100 |  |  |
| 5307 | Compressed Straw | clan | — | 100 | 100 |  |  |
| 5308 | Dragon Scale Collection | clan | — | 100 | 100 |  |  |
| 5309 | Solid Earth Piece | clan | — | 100 | 100 |  |  |
| 5310 | Big Stone | clan | — | 100 | 100 |  |  |
| 5311 | Injection | clan | — | 100 | 100 |  |  |
| 5312 | Solid Rubber Ball | clan | — | 100 | 100 |  |  |
| 5313 | Compressed Ghost Essence | clan | — | 100 | 100 |  |  |
| 5314 | Solid Dark Gem | clan | — | 100 | 100 |  |  |
| 11510 | Great Petal | loot | — | 132 | 132 |  |  |
| 11511 | Hot Fur | loot | — | 132 | 132 |  |  |
| 11512 | Red Scale | loot | — | 132 | 132 |  |  |
| 11513 | Squirrel Tail | loot | — | 78 | 78 |  |  |
| 11514 | Owl Feather | loot | — | 147 | 147 |  |  |
| 11515 | Ladybug Wing | loot | — | 78 | 78 |  |  |
| 11516 | Spider Leg | loot | — | 78 | 78 |  |  |
| 11517 | Giant Bat Wing | loot | — | 180 | 180 |  |  |
| 11518 | Point Of Light | loot | — | 114 | 114 |  |  |
| 11520 | Eggshell | loot | — | 1000 | 1000 |  |  |
| 11521 | Strange Wing | loot | — | 168 | 168 |  |  |
| 11522 | Sheep Wool | loot | — | 132 | 132 |  |  |
| 11524 | Blue Ball | loot | — | 147 | 147 |  |  |
| 11525 | Branch of Stone | loot | — | 180 | 180 |  |  |
| 11527 | Yellow Flower | loot | — | 114 | 114 |  |  |
| 11528 | Monkey Paw | loot | — | 90 | 90 |  |  |
| 11529 | Helicopter Leaves | loot | — | 69 | 69 |  |  |
| 11530 | Strange Tail | loot | — | 180 | 180 |  |  |
| 11531 | Strange Antenna | loot | — | 180 | 180 |  |  |
| 11532 | Piece Of Shell | loot | — | 147 | 147 |  |  |
| 11533 | Small Wing | loot | — | 69 | 69 |  |  |
| 11534 | Gligar Claw | loot | — | 90 | 90 |  |  |
| 11535 | Dog Ear | loot | — | 147 | 147 |  |  |
| 11536 | Small Tail | loot | — | 123 | 123 |  |  |
| 11537 | Scizor Claw | loot | — | 2000 | 2000 |  |  |
| 11538 | Steelix Tail | loot | — | 2000 | 2000 |  |  |
| 11539 | Small Shell | loot | — | 69 | 69 |  |  |
| 11540 | Insect Claw | loot | — | 180 | 180 |  |  |
| 11541 | Cat Ear | loot | — | 123 | 123 |  |  |
| 11542 | Bear Paw | loot | — | 204 | 204 |  |  |
| 11543 | Fire Ear | loot | — | 135 | 135 |  |  |
| 11544 | Tusk | loot | — | 180 | 180 |  |  |
| 11545 | Piece Of Coral | loot | — | 114 | 114 |  |  |
| 11546 | Tentacle | loot | — | 159 | 159 |  |  |
| 11547 | Gift Bag | loot | — | 90 | 90 |  |  |
| 11548 | Streak Tail | loot | — | 180 | 180 |  |  |
| 11549 | Steel Wing | loot | — | 192 | 192 |  |  |
| 11550 | Strange Bone | loot | — | 180 | 180 |  |  |
| 11552 | Elephant Foot | loot | — | 180 | 180 |  |  |
| 11553 | Reindeer Horn | loot | — | 123 | 123 |  |  |
| 11554 | Brush | loot | — | 90 | 90 |  |  |
| 11555 | Spin Machine | loot | — | 135 | 135 |  |  |
| 11556 | Cow Tail | loot | — | 180 | 180 |  |  |
| 11560 | Lizard Tail | loot | — | 450 | 450 |  |  |
| 11586 | Gem Star | loot | — | 78 | 78 |  |  |
| 11592 | Insect Tail | loot | — | 114 | 114 |  |  |
| 11593 | Wooper Horn | loot | — | 147 | 147 |  |  |
| 11594 | Dark Beak | loot | — | 123 | 123 |  |  |
| 11595 | Miss Trace | loot | — | 310 | 310 |  |  |
| 14898 | Beautiful Scales | loot | — | 10000 | 10000 |  |  |
| 14924 | Titanium Imam | loot | — | 10000 | 10000 |  |  |
| 14925 | Solid Rock Paw | loot | — | 100000 | 100000 |  |  |
| 14926 | Massive Vines | loot | — | 100000 | 100000 |  |  |
| 14927 | Max Volt Paw | loot | — | 100000 | 100000 |  |  |
| 14928 | Blaze Topknot | loot | — | 100000 | 100000 |  |  |
| 14929 | Scary Smile | loot | — | 100000 | 100000 |  |  |
| 15472 | Armor Fossil | loot | — | 60000 | 60000 |  |  |
| 15473 | Shiny Stone | loot | — | 100000 | 100000 |  |  |
| 15474 | Bone Shield | loot | — | 30000 | 30000 |  |  |
| 17340 | Slate Shard | loot | — | 150000 | 150000 |  |  |
| 17341 | Scarlet Shard | loot | — | 150000 | 150000 |  |  |
| 17342 | Sunflower Shard | loot | — | 150000 | 150000 |  |  |
| 17343 | Kermes Shard | loot | — | 150000 | 150000 |  |  |
| 17344 | Shell Shard | loot | — | 150000 | 150000 |  |  |
| 17345 | Indigo Shard | loot | — | 150000 | 150000 |  |  |
| 19354 | Fresh Herbs | loot | — | 1000 | 1000 |  |  |
| 19356 | Wild Herbs | loot | — | 5000 | 5000 |  |  |
| 21869 | Volcanic Essence | loot | — | 1000 | 1000 |  |  |
| 21874 | Raibolt Essence | loot | — | 1000 | 1000 |  |  |
| 21876 | Gardestrike Essence | loot | — | 1000 | 1000 |  |  |
| 21878 | Ironhard Essence | loot | — | 1000 | 1000 |  |  |
| 21879 | Orebound Essence | loot | — | 1000 | 1000 |  |  |
| 21880 | Wingeon Essence | loot | — | 1000 | 1000 |  |  |
| 25108 | Alolan Electric Rat Tail | loot | — | 45000 | 45000 |  |  |
| 25109 | Catfish Tail | loot | — | 45000 | 45000 |  |  |
| 25110 | Catfish Whiskers | loot | — | 66500 | 66500 |  |  |
| 25111 | Electric Fish Tail | loot | — | 45000 | 45000 |  |  |
| 25112 | Fire Monkey Hair | loot | — | 4500 | 4500 |  |  |
| 25118 | Virtual Tail | loot | — | 4500 | 4500 |  |  |
| 25639 | Remains of Gears | loot | — | 66500 | 66500 |  |  |
| 25640 | Gear Nose | loot | — | 31000 | 31000 |  |  |
| 25641 | Whiskers Fin | loot | — | 4500 | 4500 |  |  |
| 25642 | Savage Fin | loot | — | 4500 | 4500 |  |  |
| 25643 | Mole Hair | loot | — | 4500 | 4500 |  |  |
| 25644 | Mole Big Hair | loot | — | 66500 | 66500 |  |  |
| 25647 | Cave Nail | loot | — | 4500 | 4500 |  |  |
| 25648 | Blade Horn | loot | — | 180000 | 180000 |  |  |
| 25649 | Mach Nail | loot | — | 53000 | 53000 |  |  |
| 25651 | Land Shark Horn | loot | — | 4500 | 4500 |  |  |
| 25652 | Big Mount Horn | loot | — | 66500 | 66500 |  |  |
| 25654 | Flame Tail | loot | — | 180000 | 180000 |  |  |
| 25655 | Gleam Tail | loot | — | 180000 | 180000 |  |  |
| 25657 | Royal Tail | loot | — | 66500 | 66500 |  |  |
| 25658 | Royal Mane | loot | — | 4500 | 4500 |  |  |
| 25660 | Brutal Fin | loot | — | 31000 | 31000 |  |  |
| 25661 | Mount Horn | loot | — | 53000 | 53000 |  |  |
| 25663 | Elefish Fin | loot | — | 4500 | 4500 |  |  |
| 25664 | Bagworm Green Leaves | loot | — | 4500 | 4500 |  |  |
| 25665 | Bagworm Pink Leaves | loot | — | 45000 | 45000 |  |  |
| 25666 | Bagworm Stone | loot | — | 45000 | 45000 |  |  |
| 25925 | Solid Head | loot | — | 31000 | 31000 |  |  |
| 26019 | Toxic Gosme | loot | — | 3500 | 3500 |  |  |
| 26020 | Black Wool Ball | loot | — | 3500 | 3500 |  |  |
| 26022 | Razor Claw | loot | — | 37500 | 37500 |  |  |
| 26173 | Damson Shard | loot | — | 150000 | 150000 |  |  |
| 27304 | 10.000 Carat Emerald | loot | — | 150000 | 150000 |  |  |
| 29040 | Rabbit Fur | loot | — | 7 | 7 |  |  |
| 29041 | Rabbit Ear | loot | — | 21 | 21 |  |  |
| 29042 | Rabbit Eyebrows | loot | — | 265 | 265 |  |  |
| 31466 | Bucket of Honey | loot | — | 102 | 102 |  |  |
| 31563 | Kite Antenna | loot | — | 132 | 132 |  |  |
| 32115 | Dark Ear | loot | — | 350 | 350 |  |  |
| 32116 | Psychic Ear | loot | — | 350 | 350 |  |  |
| 32142 | Mystic Flower | loot | — | 450 | 450 |  |  |
| 32144 | Mystic Petal | loot | — | 180 | 180 |  |  |
| 37323 | Moon Piece | loot | — | 4500 | 4500 |  |  |
| 37324 | Sun Piece | loot | — | 4500 | 4500 |  |  |
| 37633 | Centipede Armor | loot | — | 6000 | 6000 |  |  |
| 37635 | Corrupted Scizor Claw | loot | — | 6000 | 6000 |  |  |
| 37639 | Corrupted Lizard Tail | loot | — | 6000 | 6000 |  |  |
| 37640 | Corrupted Feather | loot | — | 6000 | 6000 |  |  |
| 37642 | Corrupted Gem Star | loot | — | 6000 | 6000 |  |  |
| 38226 | Corrupted Champion Belt | loot | — | 4500 | 4500 |  |  |
| 38232 | Curly Pig Tail | loot | — | 8000 | 8000 |  |  |
| 38235 | Lovely Topknot | loot | — | 8000 | 8000 |  |  |
| 38236 | Small Bird Beak | loot | — | 2500 | 2500 |  |  |
| 38242 | Brown Ear | loot | — | 4500 | 4500 |  |  |
| 38243 | White Hair | loot | — | 4500 | 4500 |  |  |
| 38244 | Bear Arm | loot | — | 8000 | 8000 |  |  |
| 38245 | Red Spike | loot | — | 4500 | 4500 |  |  |
| 38246 | Corrupted Ice Piece | loot | — | 8000 | 8000 |  |  |
| 38247 | Frosty Hand | loot | — | 4500 | 4500 |  |  |
| 38249 | Purple Shell | loot | — | 8000 | 8000 |  |  |
| 38250 | Green Hair | loot | — | 8000 | 8000 |  |  |
| 38251 | Corrupted Doll Star | loot | — | 4500 | 4500 |  |  |
| 38252 | Corrupted Vines | loot | — | 4500 | 4500 |  |  |
| 38253 | Corrupted Miss Trace | loot | — | 8000 | 8000 |  |  |
| 38254 | Corrupted Magnet | loot | — | 2500 | 2500 |  |  |
| 38255 | Corrupted Dragon Tooth | loot | — | 2500 | 2500 |  |  |
| 38256 | Corrupted Tree Branch | loot | — | 6000 | 6000 |  |  |
| 39348 | Sand Pouch | loot | — | 4500 | 4500 |  |  |
| 39349 | Corrupted Poisonous Tail | loot | — | 8000 | 8000 |  |  |
| 39350 | Corrupted Pot of Lava | loot | — | 2500 | 2500 |  |  |
| 39351 | Corrupted Pinsir Horn | loot | — | 4500 | 4500 |  |  |
| 39352 | Corrupted Steelix Tail | loot | — | 8000 | 8000 |  |  |
| 39353 | Petite Leaves | loot | — | 2500 | 2500 |  |  |
| 39354 | Corrupted Black Hull | loot | — | 8000 | 8000 |  |  |
| 39772 | Corrupted Streak Tail | loot | — | 6000 | 6000 |  |  |
| 40400 | Leek Shield | loot | — | 25000 | 25000 |  |  |
| 40405 | Leek Lance | loot | — | 25000 | 25000 |  |  |
| 44417 | Strange Pheromone | loot | — | 1000000 | 1000000 |  |  |
| 53772 | Big Ice Ball | loot | — | 4500 | 4500 |  |  |
| 53773 | Ice Crystal | loot | — | 4500 | 4500 |  |  |
| 53782 | Black Lucky Charm | loot | — | 4500 | 4500 |  |  |
| 53899 | Flower Hat | loot | — | 4500 | 4500 |  |  |
| 54794 | Wolf Tail | loot | — | 3500 | 3500 |  |  |
| 54824 | Slice of Apple | loot | — | 3500 | 3500 |  |  |
| 54829 | Sweet Apple Pie | loot | — | 8000 | 8000 |  |  |
| 55165 | Feline Fur | loot | — | 4500 | 4500 |  |  |
| 59195 | Rare Pokémon Picture | loot | — | 5000 | 5000 |  |  |
| 59217 | greens | loot | — | 40 | 40 |  |  |
| 59218 | fire feather | loot | — | 40 | 40 |  |  |
| 59219 | black fins | loot | — | 40 | 40 |  |  |
| 59220 | big seed | loot | — | 40 | 40 |  |  |
| 59221 | pelican wing | loot | — | 40 | 40 |  |  |
| 59222 | cute ball | loot | — | 40 | 40 |  |  |
| 59223 | eruption ears | loot | — | 40 | 40 |  |  |
| 59224 | samurai hair | loot | — | 40 | 40 |  |  |
| 59225 | mediling | loot | — | 40 | 40 |  |  |
| 59226 | shock topknot | loot | — | 40 | 40 |  |  |
| 59227 | nu ball | loot | — | 40 | 40 |  |  |
| 59228 | mini volcano | loot | — | 40 | 40 |  |  |
| 59229 | springs | loot | — | 40 | 40 |  |  |
| 59230 | lobster claw | loot | — | 40 | 40 |  |  |
| 59231 | pawn | loot | — | 40 | 40 |  |  |
| 59232 | ghost skull | loot | — | 40 | 40 |  |  |
| 59233 | ice blocks | loot | — | 40 | 40 |  |  |
| 59234 | seal mustache | loot | — | 40 | 40 |  |  |
| 59235 | Big Crystal | loot | — | 40 | 40 |  |  |
| 59236 | Black Hull | loot | — | 40 | 40 |  |  |
| 59237 | Cactus Head | loot | — | 40 | 40 |  |  |
| 59238 | Cure Flower | loot | — | 40 | 40 |  |  |
| 59239 | Metal Hull | loot | — | 40 | 40 |  |  |
| 59240 | Metal Jaw | loot | — | 40 | 40 |  |  |
| 59241 | Mini Wings | loot | — | 40 | 40 |  |  |
| 59242 | Poisonous Tail | loot | — | 40 | 40 |  |  |
| 59243 | Sand Tail | loot | — | 40 | 40 |  |  |
| 59244 | Sharp Leaves | loot | — | 40 | 40 |  |  |
| 59245 | Small Crown | loot | — | 40 | 40 |  |  |
| 59246 | Tech Ball | loot | — | 40 | 40 |  |  |
| 59250 | cloud | loot | — | 40 | 40 |  |  |
| 59251 | crimson feather | loot | — | 40 | 40 |  |  |
| 59252 | dark moon | loot | — | 40 | 40 |  |  |
| 59253 | doll star | loot | — | 40 | 40 |  |  |
| 59254 | strange ball | loot | — | 40 | 40 |  |  |
| 59255 | tribe mark | loot | — | 40 | 40 |  |  |
| 59256 | water plant | loot | — | 40 | 40 |  |  |
| 59257 | fur ball | loot | — | 40 | 40 |  |  |
| 59258 | hyena tail | loot | — | 40 | 40 |  |  |
| 59259 | creepy eye | loot | — | 40 | 40 |  |  |
| 59260 | palm leaves | loot | — | 40 | 40 |  |  |
| 63605 | Talon | loot | — | 1000 | 1000 |  |  |
| 64058 | Yellow Eyebrows | loot | — | 6000 | 6000 |  |  |
| 65173 | Blue Ghost Candle | loot | — | 4500 | 4500 |  |  |
| 70000 | Bronze Boss Token | loot | — | 250000 | 250000 |  |  |
| 90123 | Dragon Goo | loot | — | 3500 | 3500 |  |  |
