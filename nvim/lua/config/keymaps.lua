-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local dotnet = require("config.dotnet")
local sonar = require("config.sonar")

_G.toggle_dbee = function()
  local dbee = require("dbee")
  local dbee_api = require("dbee.api")
  local dbee_layouts = require("config.dbee_layouts")
  local target_layout = dbee_layouts.floating
  local current_config = dbee_api.current_config()
  local current_layout = current_config.window_layout

  if current_layout ~= target_layout and current_layout and current_layout.is_open and current_layout:is_open() then
    current_layout:close()
  end

  current_config.window_layout = target_layout

  if target_layout:is_open() then
    dbee.close()
  else
    dbee.open()
  end
end

local function move_buffer_to_win(direction)
  local buf = vim.api.nvim_get_current_buf()
  local cur_win = vim.api.nvim_get_current_win()

  vim.cmd("wincmd " .. direction)
  local target_win = vim.api.nvim_get_current_win()

  if target_win == cur_win then
    local split_cmd = (direction == "h" or direction == "l") and "vsplit" or "split"
    local pos = (direction == "h") and "topleft " or (direction == "l") and "botright " or
                (direction == "k") and "topleft " or "botright "
    vim.cmd(pos .. split_cmd)
    target_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_win_set_buf(target_win, buf)
  vim.api.nvim_set_current_win(cur_win)

  local ok = pcall(vim.cmd, "bprevious")
  if not ok then pcall(vim.cmd, "bnext") end
end

local function toggle_terminal_mode()
  local is_terminal = vim.bo.buftype == "terminal" or vim.bo.filetype == "snacks_terminal"
  if not is_terminal then
    Snacks.terminal()
    return
  end

  if vim.api.nvim_get_mode().mode == "t" then
    vim.cmd.stopinsert()
    return
  end

  vim.cmd.startinsert()
end

local function open_terminal()
  vim.cmd("terminal")
  vim.cmd.startinsert()
end

local function close_current_buffer()
  Snacks.bufdelete()
end

local function close_current_window()
  vim.cmd("close")
end

local function map_move_buffer_aliases(direction, aliases, desc)
  local action = function() move_buffer_to_win(direction) end
  for _, lhs in ipairs(aliases) do
    vim.keymap.set("n", lhs, action, { desc = desc })
  end
end

vim.keymap.set("n", "<leader>fs", "<cmd>write<cr>", { desc = "Save File" })

map_move_buffer_aliases("h", { "<leader>wH", "<C-h>" }, "Move Buffer to Left Group")
map_move_buffer_aliases("l", { "<leader>wL", "<C-l>" }, "Move Buffer to Right Group")
map_move_buffer_aliases("k", { "<leader>wK", "<C-k>" }, "Move Buffer to Top Group")
map_move_buffer_aliases("j", { "<leader>wJ", "<C-j>" }, "Move Buffer to Bottom Group")

vim.keymap.set("n", "<leader>ob", _G.toggle_dbee, { desc = "Dbee UI" })
vim.keymap.set("n", "<leader>od", function()
  Snacks.terminal({ "lazydocker" })
end, { desc = "LazyDocker" })
vim.keymap.set("n", "<leader>os", sonar.scan, { desc = "Sonar Scan" })
vim.keymap.set("n", "<leader>oS", sonar.doctor, { desc = "Sonar Doctor" })
vim.keymap.set("n", "<leader>go", function()
  Snacks.picker.git_branches()
end, { desc = "Git Branches" })

vim.keymap.set("n", "<leader>E", function()
  Snacks.explorer({ cwd = vim.uv.cwd(), hidden = true, ignored = true })
end, { desc = "Explorer Snacks (cwd, all files)" })

vim.keymap.set({ "n", "t" }, "<A-t>", toggle_terminal_mode, { desc = "Toggle terminal mode" })
vim.keymap.set({ "n", "t" }, "<M-t>", toggle_terminal_mode, { desc = "Toggle terminal mode" })
vim.keymap.set({ "n", "t" }, "†", toggle_terminal_mode, { desc = "Toggle terminal mode" })
vim.keymap.set({ "n", "t" }, "<C-S-t>", open_terminal, { desc = "Open terminal" })
vim.keymap.set("n", "<A-d>", close_current_buffer, { desc = "Close buffer" })
vim.keymap.set("n", "<M-d>", close_current_buffer, { desc = "Close buffer" })
vim.keymap.set("n", "∂", close_current_buffer, { desc = "Close buffer" })
-- Fechar janela: <leader>wd (LazyVim). Alt/Option+w nunca chega aqui: o AeroSpace usa alt-w (modo windows).
-- ∂ e † continuam: no terminal do VS Code o Option não é Meta e chega como esses caracteres.

vim.keymap.set("n", "<leader>dn", function()
  dotnet.build(dotnet.find_root())
end, { desc = "Build .NET" })

vim.keymap.set("n", "<leader>dc", function()
  local dap = require("dap")
  if vim.bo.filetype == "cs" and not dap.session() then
    vim.cmd("silent! wall")
  end

  dap.continue()
end, { desc = "Run/Continue" })

vim.keymap.set("n", "<leader>dR", function()
  local dap = require("dap")
  if dap.session() then
    dap.restart()
    return
  end

  if vim.bo.filetype == "cs" then
    vim.cmd("silent! wall")
  end

  dap.continue()
end, { desc = "Restart Debugging" })
