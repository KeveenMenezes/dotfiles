return {
  {
    "nvim-zh/colorful-winsep.nvim",
    event = { "WinLeave" },
    opts = {
      border = "bold",
      -- destaque do tema ativo (comando `tema`): ciano do Prometheus ou a versão pastel do lilás
      highlight = (function()
        local ok, linhas = pcall(vim.fn.readfile, vim.fn.expand("~/.config/tema/atual"))
        return (ok and linhas[1] == "prom-lilas") and "#6fc3e3" or "#29b8db"
      end)(),
      indicator_for_2wins = {
        position = "center",
      },
      animate = {
        enabled = false,
      },
    },
  },
}
