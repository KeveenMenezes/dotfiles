return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "csharpier",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = {
        timeout_ms = 2000,
        lsp_format = "fallback",
      },
      formatters = {
        csharpier = {
          command = vim.fn.expand("~/.local/share/nvim/mason/bin/csharpier"),
        },
      },
      formatters_by_ft = {
        cs = { "csharpier" },
      },
    },
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "Nsidorenco/neotest-vstest",
    },
    opts = {
      adapters = {
        ["neotest-vstest"] = {},
      },
    },
  },
}
