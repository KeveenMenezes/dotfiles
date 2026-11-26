---
name: multi-agent-panes
description: Use quando o usuário pedir para executar trabalho com multi-agents, trilhas em paralelo ou "controller + subagentes" — e.g. "roda isso em 3 trilhas", "divide entre subagentes", "multi-agent nessas tarefas". Abre uma pane do Herdr por subagente com um monitor ao vivo (estado, commits, arquivos em edição, últimas ações e mensagens de texto do agente), sem gastar tokens.
---

# Multi-agent com panes de acompanhamento

Cada subagente roda numa worktree isolada; ao lado da pane do usuário, uma pane por trilha mostra em tempo real o
que o agente está fazendo. O monitor é bash puro e só lê — o custo de IA fica só na montagem, feita uma vez.

## Pré-condição

- `test "${HERDR_ENV:-}" = 1`. Se falhar, avise em uma linha que não está no Herdr e siga com os subagentes sem panes.
- Se nenhuma skill do Herdr estiver no contexto, rode `herdr --skill` uma vez por sessão.
- `jq` instalado (o monitor depende dele).

## Passos

1. **Base dos commits:** antes de lançar, guarde `base=$(git rev-parse HEAD)` — é de onde as worktrees partem.
2. **Lance as trilhas:** uma chamada do Agent tool por trilha, todas na mesma mensagem, com `isolation: "worktree"`
   e uma `description` curta (vira o título). Os subagentes já rodam em background; guarde o `agentId` de cada um.
3. **Layout:** cheque com `herdr pane layout --pane "$HERDR_PANE_ID"`. Divida a pane do usuário à direita e empilhe
   as N panes de monitor com altura igual:
   ```bash
   p=$(herdr pane split --pane "$HERDR_PANE_ID" --direction right --ratio 0.5 --no-focus --cwd "$PWD" | jq -r '.result.pane.pane_id')
   # para cada trilha seguinte i = 2..N, divida a ÚLTIMA pane criada para baixo:
   p=$(herdr pane split --pane "$p" --direction down --ratio <1/(N-i+2)> --no-focus --cwd "$PWD" | jq -r '.result.pane.pane_id')
   ```
   `--ratio` é a fração que fica com a pane dividida: N=2 → 0.5; N=3 → 0.33, 0.5; N=4 → 0.25, 0.33, 0.5.
   Sempre `--no-focus` — nunca tire o foco da pane do usuário. Com mais de 4 trilhas, prefira uma aba nova a panes
   ilegíveis.
   **Limite compartilhado com background-panes:** o total de panes ao lado da do usuário é 4.
   `bash ~/.claude/skills/background-panes/bg-pool.sh count` diz quantas já existem. Se houver alguma, não divida a
   pane do usuário de novo: empilhe dividindo para baixo (`--ratio 0.5`) a pane mais alta da coluna da direita
   (`herdr pane layout`), e abra só as trilhas que cabem nas vagas; as demais vão para uma aba nova.
4. **Monitor em cada pane:**
   ```bash
   herdr pane rename <id> "Trilha X · módulo (tarefas)"
   herdr pane run <id> "bash ~/.claude/skills/multi-agent-panes/track-monitor.sh 'Trilha X · módulo (tarefas)' <agentId> <base>"
   ```
   O script fica na skill, nunca no repo. Ele acha sozinho a transcrição (`~/.claude/projects/*/*/subagents/agent-<id>.jsonl`)
   e lê worktree e branch do `.meta.json` ao lado; se a transcrição ainda não existe, mostra "aguardando" e tenta de novo.
   O que ele mostra (redesenha a cada 1s; git e transcrição são relidos a cada 3s — o 4º argumento muda isso):
   - **barra de título colorida pelo estado**, legível de relance entre panes empilhadas: amarela com spinner
     (trabalhando), verde `✓` (terminou — inclusive via `SubagentHandback`), vermelha `■` (interrompido), cinza `◌`
     (parado há 90s+); à direita, o modelo do agente
   - tempo decorrido, última atividade, branch e base; contadores de ferramentas, edições, commits e contexto (`ctx 87k`)
   - barra de progresso `▰▰▰▱▱ 3/5` + tarefa atual, se o agente usar TodoWrite
   - commits desde a base (hash em destaque) e arquivos em edição com status colorido e `+add −del` por arquivo,
     sem `serverless.template`, via `git --no-optional-locks` para não disputar o `index.lock` com o agente
   - ao terminar, a seção **Resultado** com a entrega/última mensagem do agente
   - **Atividade** com horário: ferramentas coloridas por tipo (edição amarela, Bash ciano, leitura azul,
     subagente magenta) e mensagens de texto do agente (`»`, em itálico) — o mais próximo do raciocínio que dá para
     exibir; a ação mais recente fica em negrito com `▶`. Ocupa toda a altura que sobra da pane
   - caminhos encurtados (sem o prefixo da worktree/repo; scratchpad vira `scratch/`) e linhas cortadas com `…` na
     largura da pane, que é relida a cada frame (redimensionar funciona)
5. **Confirme** a renderização de cada pane com `herdr pane read <id> --source visible --lines 20`. O controller nunca
   lê a transcrição JSONL diretamente, para não estourar o próprio contexto.
6. **Enquanto rodam:** não faça polling. Espere as notificações de conclusão dos subagentes; as panes são para o usuário.
7. **Ao terminar todas as trilhas:** pergunte se o usuário quer manter as panes. Se não, para cada uma:
   `herdr pane send-keys <id> ctrl+c` e `herdr pane close <id>`. Depois resuma o resultado de cada trilha (branch,
   commits, pendências) e lembre das worktrees que sobraram (`git worktree list`) para merge ou remoção.

## Ajustes rápidos

- Teste um frame sem pane: `MONITOR_ONCE=1 bash ~/.claude/skills/multi-agent-panes/track-monitor.sh 'título' <agentId> <base>`.
- Os limites ficam no topo do script: `max_commits` (5), `max_files` (8), `max_result` (8 linhas), `min_activity` (5).
- `herdr pane run` digita o comando no shell da pane (pode não ser bash), então passe só `bash <script> <args>` — nada de
  sintaxe bash inline.
