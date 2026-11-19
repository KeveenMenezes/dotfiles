# Tema do terminal (comando `tema`): fzf com as cores do tema e bat/delta com o tema de sintaxe dele.
$env.FZF_DEFAULT_OPTS = ([
  "--color=fg:#bfbfbf,bg:-1,hl:#29b8db,fg+:#e0e0e0,bg+:#3a3a3a,hl+:#29b8db"
  "--color=info:#6b6b6b,prompt:#949494,pointer:#29b8db,marker:#98c379,spinner:#949494"
  "--color=header:#888888,border:#2b2b2b,gutter:-1,query:#e0e0e0,label:#888888"
] | str join " ")
$env.BAT_THEME = "prom-wiki"
