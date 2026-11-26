-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local dashboard_group = vim.api.nvim_create_augroup("keveen_dashboard_cleanup", { clear = true })

local function is_real_window(win)
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  local name = vim.api.nvim_buf_get_name(buf)

  return ft ~= "snacks_dashboard" and (vim.fn.buflisted(buf) == 1 or name ~= "")
end

local function close_dashboard_windows()
  if not vim.iter(vim.api.nvim_list_wins()):any(is_real_window) then
    return
  end

  local changed = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "snacks_dashboard" then
      changed = true
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  if changed then
    vim.schedule(function()
      if _G.nvim_bufferline then
        pcall(_G.nvim_bufferline)
      end
    end)
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "SessionLoadPost", "WinEnter" }, {
  group = dashboard_group,
  callback = close_dashboard_windows,
})

local autosave_group = vim.api.nvim_create_augroup("keveen_autosave", { clear = true })

local function parent_dir_exists(path)
  local dir = vim.fs.dirname(path)
  if not dir or dir == "" then
    return false
  end

  local stat = vim.uv.fs_stat(dir)
  return stat and stat.type == "directory" or false
end

local function should_autosave(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local bo = vim.bo[buf]
  local name = vim.api.nvim_buf_get_name(buf)
  local dbee_state_dir = vim.fn.stdpath("state") .. "/dbee/"

  if bo.filetype == "dbee" or name:find(dbee_state_dir, 1, true) == 1 then
    return false
  end

  return bo.modified
    and bo.modifiable
    and not bo.readonly
    and bo.buftype == ""
    and name ~= ""
    and parent_dir_exists(name)
end

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost", "BufLeave" }, {
  group = autosave_group,
  callback = function(event)
    if should_autosave(event.buf) then
      vim.api.nvim_buf_call(event.buf, function()
        vim.cmd("update")
      end)
    end
  end,
})

-- herdr (prefix+e) abre o scrollback em $EDITOR num arquivo herdr-scrollback-*.
-- Ao copiar dali, remove o recuo comum e a quebra de linha final, para colar
-- comandos no shell sem espaços na frente nem Enter no fim.
local herdr_scrollback_group = vim.api.nvim_create_augroup("keveen_herdr_scrollback", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = herdr_scrollback_group,
  callback = function()
    local event = vim.v.event
    if event.operator ~= "y" or not vim.api.nvim_buf_get_name(0):find("herdr%-scrollback%-") then
      return
    end

    local lines = vim.deepcopy(event.regcontents)
    local indent
    for _, line in ipairs(lines) do
      if line:match("%S") then
        local width = #line:match("^%s*")
        indent = indent and math.min(indent, width) or width
      end
    end

    for i, line in ipairs(lines) do
      lines[i] = (line:sub((indent or 0) + 1):gsub("%s+$", ""))
    end

    vim.schedule(function()
      vim.fn.setreg("+", lines, "c")
    end)
  end,
})
