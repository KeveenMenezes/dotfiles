-- Tema ativo no terminal (comando `tema`): "prometheus" ou "prom-lilas"
local function tema_atual()
  local ok, linhas = pcall(vim.fn.readfile, vim.fn.expand("~/.config/tema/atual"))
  return ok and linhas[1] or "prometheus"
end

local cores = {
  text = "#b6b6b6",
  subtext0 = "#969696",
  subtext1 = "#a4a4a4",
  -- destaque no azul do Prometheus (#29b8db) em vez do ciano #00d0ff do plugin, como no resto do terminal
  sky = "#29b8db",
}
-- Prometheus Lilás: só os destaques mudam (mesma matiz, versão pastel); os cinzas são os do Prometheus
if tema_atual() == "prom-lilas" then
  cores = vim.tbl_extend("force", cores, {
    red = "#f47c7c",
    maroon = "#e88a92",
    peach = "#ffa07f",
    orange = "#ffb86b",
    yellow = "#ffd59a",
    green = "#b2d99a",
    teal = "#7fe3ee",
    sky = "#6fc3e3",
    sapphire = "#6fc3e3",
    blue = "#6fc3e3",
    mauve = "#c3a6e0",
    lavender = "#d8bff0",
  })
end

return {
  {
    "KeveenMenezes/promo-wiki.nvim",
    main = "promowiki",
    lazy = false,
    priority = 1000,
    opts = {
      transparent_background = true,
      terminal_colors = true,
      color_overrides = {
        all = cores,
      },
      highlight_overrides = {
        all = function(palette)
          return {
            LspReferenceRead = { bg = palette.surface2 },
            LspReferenceText = { bg = palette.surface2 },
            LspReferenceWrite = { bg = palette.overlay0 },
          }
        end,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "promo-wiki",
    },
  },
}
