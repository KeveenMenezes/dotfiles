---
name: background-panes
description: Use sempre que for rodar algo em background (Bash com run_in_background, deploys, builds longos, Monitor) estando no Herdr. Abre panes de acompanhamento ao vivo, com no máximo 4; acima disso consolida num painel único.
---

# Panes de acompanhamento para tarefas em background

O usuário vê ao vivo o que roda em background; o controller não gasta tokens com isso. Toda a decisão de layout, fila e
reciclagem fica no `bg-pool.sh` (determinístico), e os monitores são bash puro.

## Quando usar
- Qualquer Bash com `run_in_background`, comando que deve passar de ~30s (deploy, build, testes, synth) ou Monitor.
- Subagentes NÃO: esses usam a skill multi-agent-panes. As duas dividem o mesmo limite de 4 panes.
- Não use para comandos rápidos nem fora do Herdr (`test "${HERDR_ENV:-}" = 1`; se falhar, siga sem panes e sem avisar).
- Depende de `jq`. Se nenhuma skill do Herdr estiver no contexto, `herdr --skill` não é necessário: o `bg-pool.sh`
  faz todas as chamadas.

## Como usar
Variáveis abaixo: `S=~/.claude/skills/background-panes`, `D=<scratchpad da sessão>/bg-panes`.

1. **Lance o comando** terminando com `; echo "__EXIT__ $?"` (marcador de fim). Em pipelines, comece com
   `set -o pipefail;` para o código refletir a falha real. Guarde o arquivo de output que o Bash tool devolve
   ("Output is being written to: …"). Para Monitor ou outro comando sem arquivo próprio, mande a saída para
   `$D/<slug>.log` com `2>&1 | tee -a $D/<slug>.log` e use esse arquivo.
2. **Registre e dê uma pane:** `bash $S/bg-pool.sh add $D '<rótulo curto>' <arquivo>` — uma chamada só, logo depois
   do lançamento (várias tarefas podem ir num único Bash, uma linha cada). Ele imprime onde a tarefa ficou:
   - `pane <id>` — pane própria (reaproveitada ou nova). Criada com `--no-focus`, empilhada na coluna da direita
     dividindo a pane mais alta, o que mantém as alturas iguais.
   - `dashboard <id>` — o pool de 4 está cheio (contando as panes de multi-agent-panes): na primeira vez a última pane
     do pool vira o **painel consolidado**, com uma linha por tarefa (estado colorido, rótulo, decorrido, `▣` em pane /
     `·` só no painel, última linha do output). Tarefas novas entram nele.
   - `sem pane: …` — as 4 panes são de outra skill; a tarefa fica só registrada. Siga sem avisar.
3. **Reciclagem é automática:** uma tarefa concluída segura a pane com ✓ por 60s (✗ por 5min, para dar tempo de ler o
   erro). Depois, o próprio monitor da pane assume a tarefa ativa mais antiga que está só no painel e se renomeia;
   sem fila, a pane fica livre para o próximo `add`. Não faça nada nem polling para isso.
4. **Enquanto rodam:** espere as notificações de conclusão. Para conferir sem ler output: `bash $S/bg-pool.sh status $D`
   (uma linha por tarefa + ocupação do pool). Para o conteúdo, `tail` pontual no arquivo — nunca leia o output inteiro
   pelo monitor nem pelas panes; elas são para o usuário.
5. **Encerramento:** quando `status` mostrar `ativas: 0` e não houver mais nada a lançar, `bash $S/bg-pool.sh close $D`
   (ctrl+c nos monitores e fecha só as panes desta skill), a não ser que o usuário peça para mantê-las.

## O que o monitor mostra (`bg-monitor.sh`, só lê o output, redesenha a cada 1s)
- **Tarefa:** barra de título colorida pelo estado — amarela com spinner (rodando), verde ✓ (`__EXIT__ 0`), vermelha ✗
  com o código (`__EXIT__ ≠0`), cinza ◌ (sem saída nova há 90s+). Embaixo: decorrido, há quanto tempo saiu a última
  linha, tamanho do arquivo, e as últimas linhas do output ocupando a altura da pane (`tail`, nunca o arquivo inteiro).
  ANSI removido, barras de progresso com `\r` reduzidas ao último estado, linhas com error/failed/exception/fatal em
  vermelho e warn em amarelo (resumos como `0 Error(s)` e `Failed: 0` não contam), cortadas com … na largura atual.
- **Painel:** ativas primeiro (mais antigas no topo), depois concluídas (mais recentes no topo); cabeçalho com
  `N rodando · N ✓ · N ✗`, amarelo enquanto algo roda.
- O marcador `[exited with code N]` que o Claude Code grava nos próprios arquivos de background também encerra a
  tarefa, mas o `__EXIT__` tem prioridade (o código do harness é o do `echo` final, sempre 0).

## Ajustes rápidos
- Uso avulso, sem pool: `bash $S/bg-monitor.sh '<rótulo>' <arquivo>` ou `bash $S/bg-monitor.sh --dashboard $D`.
- Teste um frame sem pane: `MONITOR_ONCE=1 COLUMNS=80 LINES=20 bash $S/bg-monitor.sh '<rótulo>' <arquivo>`.
- Limites no topo de `bg-lib.sh`: `max_panes` (4), `stale_after` (90s), `done_hold` (60s), `fail_hold` (300s).
- Estado em `$D`: `bg-tasks.tsv` (id, rótulo, arquivo, início, pane ou `-`) e `panes.tsv` (pane, `task`|`dashboard`),
  escritos sob lock `mkdir`. As panes seguem esses arquivos sozinhas: mudar o papel ou a tarefa de uma pane não exige
  reiniciar o monitor.
- `herdr pane run` digita o comando no shell da pane (nushell aqui), por isso o pool só passa `bash <script> <args>`
  com argumentos entre aspas simples — nada de sintaxe bash inline.
- O pool é contado pelo layout real (`herdr pane layout`): toda pane da aba além da do usuário ocupa uma vaga.
  `bash $S/bg-pool.sh count` mostra quantas estão ocupadas.
