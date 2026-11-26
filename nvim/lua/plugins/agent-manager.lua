local dir = "/Users/keveenmenezes/Documents/projects/work/agent-manager.nvim"

return {
  {
    dir = dir,
    name = "agent-manager.nvim",
    cond = vim.uv.fs_stat(dir) ~= nil,
    config = function()
      require("agent-manager").setup({
        keymap = "<leader>as",
        create_keymap = true,
      })
    end,
  },
}
