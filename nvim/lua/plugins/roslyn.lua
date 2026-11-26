return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "c_sharp") then
        table.insert(opts.ensure_installed, "c_sharp")
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        roslyn_ls = {
          cmd = {
            vim.fn.expand("~/.local/bin/roslyn-language-server"),
            "--logLevel",
            "Information",
            "--extensionLogDirectory",
            vim.fs.joinpath(vim.uv.os_tmpdir(), "roslyn_ls/logs"),
            "--stdio",
          },
        },
      },
    },
  },
}
