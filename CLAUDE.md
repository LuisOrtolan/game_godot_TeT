# MVP de RPG por Turnos em Godot

## Visão geral
Protótipo mínimo jogável (MVP) de um RPG com combate por turnos, pra testar com amigos. Ambientado na ideia geral do universo de Trilhas & Tesouros — reaproveita conceitos e nomes (trilhas, magias), mas **não** é uma tentativa de portar o sistema de RPG de mesa inteiro pra regras de código. A meta agora é só provar que o loop de combate é divertido.

## Quem está construindo isso
Desenvolvedor backend (AdvPL/TLPP, Protheus), iniciante em Godot, GDScript e game design. Confortável com lógica, dados e regras de negócio; pouca experiência com front-end/UI visual e zero com engines de jogo antes disso. Ao explicar ou sugerir código, prefira conectar conceitos novos (Node, Scene, Signal) a paradigmas que ele já conhece (estado, evento, dado estruturado) em vez de assumir vocabulário de game dev.

## Escopo do MVP — não expandir sem decisão explícita
- 1 trilha (classe) jogável
- 3 a 4 feitiços/ações dessa trilha
- 1 encontro de batalha, contra 1 inimigo
- Fora de escopo por enquanto: múltiplos personagens no grupo, exploração de mapa, progressão/level up, save/load, som/música, multiplayer, balanceamento fino, réplica das regras completas do sistema de mesa

## Stack técnica
- Godot 4.7 (estável)
- GDScript — não C#, porque projetos em C# hoje não exportam pra Web no Godot 4, e a ideia é manter aberta a opção de exportar como link (HTML5/WebAssembly) pra compartilhar com os amigos sem instalação
- Hospedagem de teste: itch.io (gratuito, sem fila de aprovação)

## Arquitetura
- **Dados como `Resource` (.tres)**: `Personagem`, `Acao`/`Feitico`, `Inimigo`, cada um guardando seus próprios atributos (nome, HP, dano, descrição). Pense nisso como o equivalente ao `magias.json` do site do Trilhas & Tesouros, só que carregado dentro do jogo.
- **Signals** para eventos de turno: início de turno, ação resolvida, fim de turno — cada sistema (UI, IA do inimigo) reage ao sinal em vez de tudo ficar acoplado num arquivo só.
- **Máquina de estados** simples pra batalha: `turno_jogador` → `turno_inimigo` → `resolvendo_acao` → `fim_de_batalha`.
- **UI de batalha** com `Control` nodes: menu de ação, barra de HP, indicador de turno.

## Ordem de trabalho — não pular etapa
1. Estrutura de dados (Resources) pro recorte de conteúdo definido
2. Lógica de batalha funcionando com placeholder (caixas coloridas, texto puro) — sem arte nenhuma ainda
3. UI funcional, ainda com placeholder
4. Arte só entra por último: retratos estáticos gerados por IA (sem animação de sprite) + asset pack pronto pra UI genérica

## Princípio geral
Lógica e diversão do combate vêm antes de qualquer polimento visual. Se o passo 2 mostrar que o loop não é divertido, isso precisa ser resolvido antes de seguir pro resto — é mais barato descobrir isso cedo.

## Conteúdo do recorte (trilha Xamã)
Fonte: SRD de Trilhas & Tesouros (trilha Xamã) + Bestiário.

- **Personagem de teste**: Xamã nível 1, `resources/personagens/xama_teste.tres`. PV e atributos são valores de teste escolhidos pra rodar o MVP (o SRD só dá a fórmula de geração, não valores fixos) — ajustar livremente.
- **Rituais** (4 de 1ª grandeza, custo em pontos de Canalização, ver abaixo): Dardo de Espinho, Correia de Vinha, Brasa Ancestral, Seiva Restauradora. Em `resources/rituais/`.
- **Inimigo de teste**: Cão (`resources/inimigos/cao.tres`), escolhido em vez do Lobo do Bestiário porque com o PV baixo do Xamã de teste o Lobo vencia o combate rápido demais pra validar o loop.
- **Canalização simplificada pro MVP**: pool de mana por combate (`canalizacao_maxima`/`canalizacao_atual` em `Personagem`, 10 no Xamã de teste), onde cada ritual gasta `custo_canalizacao` (Dardo 2, Seiva 2, Correia 3, Brasa 3). Antes era 1 uso por ritual num pool de 2, mas o Xamã ficava sem canalização na rodada 2 e só repetia ataque de cajado. Sem a depleção aleatória de dados nem a tabela de Fúria dos Espíritos do SRD completo. Se o motor provar que vale a pena, portar a versão completa é uma decisão separada.
