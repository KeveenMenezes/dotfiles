local sonar = require("config.sonar")

return {
  {
    "santanusinha/sonarlint.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
    },
    ft = sonar.filetypes,
    opts = function()
      sonar.ensure_layout()
      return sonar.sonarlint_opts()
    end,
  },
}
