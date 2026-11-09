# Fórmula de dano e limites de fidelidade

## Confirmado nas fontes

https://poke.idleworld.online/pokepedia/systems/power
https://poke.idleworld.online/pokepedia/systems/combat

A página de Power publica a relação entre base, IV, nível, qualidade, atributos
e Power. A de combate informa o reforço dos selvagens e a amplificação elemental.
A conversão de HP e os expoentes já estavam recuperados do cliente extraído.
Os dados base de Larvitar e Geodude vêm de creatures.json fornecido anteriormente.

## Regra local substituível

Para um golpe danoso, com categoria física ou especial:

```
A = max(1, Atk ou SpAtk do atacante)
D = max(1, Def ou SpDef do defensor)
base = ((2*nível/5 + 2) * PowerDoGolpe * A/D) / 50 + 2
dano = max(1, round(base * elementoAmplificado * reforçoSelvagem))
```

Imunidade retorna 0 antes do piso; golpes de status ou de poder zero retornam 0.
ReforçoSelvagem vale1,8 para ataques de selvagens e1 para ataques do aliado.
Essa curva foi adotada como política do protótipo; não foi atribuída ao servidor.
O piso de atributos1 protege níveis baixos contra divisão por zero sem alterar
os valores exibidos no TEAM. Não se adicionaram STAB, crítico ou sorte sem confirmação.
Speed não está presente; o Power agregado do Pokémon também não entra diretamente.

## Próximas prioridades

1. Recuperar ou inferir a fórmula completa com eventos contendo atacante,
   defensor, seis atributos, nível, qualidade, golpe, bônus e dano efetivo.
2. Confirmar STAB, críticos, aleatoriedade, arredondamentos e limites por estágio.
3. Conferir bônus adicionais, golpes de status e efeitos de redução de atributos.
4. Conferir a regra de nível dos selvagens por destino; não inferir nível a partir
   de HP observado no field. Os indivíduos locais preservam seu nível real.
5. Integrar Speed somente após confirmar sua função. Não usá-lo indiretamente
   multiplicando o Power agregado no dano.
6. Confirmar o perfil inicial oficial (IVs/qualidade), separadamente dos dados
   base da espécie. O perfil de137 IVs é uma escolha local explícita.

O atributo legado dano_base pode ser usado apenas com usar_atributos_combate
DESLIGADO, para reproduzir testes históricos. O padrão é LIGADO e usa os atributos.
A validação de cadência/golpes antigos isola esse modo legado; o novo teste valida
o modo real e a aplicação do dano ao HP, além de resistências e imunidades.
