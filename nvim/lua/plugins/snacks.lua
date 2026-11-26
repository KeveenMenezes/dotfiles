local function buildRgCmd(opts)
  local expression = "(" .. table.concat(opts.sign_list, "|") .. "):"

  if opts.match_comment_symbols then
    expression = [[([^\S\r\n]*(]]
      .. table.concat(opts.comment_symbols, "|")
      .. [[)[^\S\r\n]*)\s*(]]
      .. table.concat(opts.sign_list, "|")
      .. [[):\s*]]
  end

  local rg_command = "rg -g '!{**/node_modules/*,**/.git/*}' -w '"
    .. expression
    .. "' "
    .. table.concat(opts.dirs, " ")
    .. " --hidden --follow --sortr modified --no-heading --color never --with-filename --line-number --column"

  return rg_command
end

local function getTodos(opts)
  if next(opts.sign_list) == nil then
    return {}
  end

  local rg_command = buildRgCmd(opts)

  local rg_res = vim.fn.systemlist(rg_command)
  local todos = {}

  local todo_count = 0
  for i, line in pairs(rg_res) do
    local filename, row, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
    if filename and row and col and text then
      todo_count = todo_count + 1
      local sign_sym = ""

      for _, sign_s in ipairs(opts.sign_list) do
        local start_pos, end_pos = text:find(sign_s .. ":")
        if start_pos then
          sign_sym = text:sub(start_pos, end_pos)
          text = text:sub(end_pos + 1)
        end
      end

      local todo = {
        index = i + 5 ~= 10 and i + 5 or 0,
        file = filename:match("^%s*(.-)%s*$"),
        line = row,
        column = col,
        sign = sign_sym,
        desc = text:match("^%s*(.-)%s*$"),
      }
      table.insert(todos, todo)

      if todo_count == opts.limit then
        break
      end
    end
  end

  return todos
end

local header = require("config.dashboard_header")

local function patch_dashboard_window_validity()
  local dashboard = require("snacks.dashboard")

  if dashboard._keveen_window_validity_patch then
    return
  end

  dashboard._keveen_window_validity_patch = true

  local original_open = dashboard.open

  local function resolve_window(instance)
    if type(instance.win) == "number" and instance.win > 0 and vim.api.nvim_win_is_valid(instance.win) then
      return instance.win
    end

    if instance.buf and vim.api.nvim_buf_is_valid(instance.buf) then
      local win = vim.fn.bufwinid(instance.buf)
      if win ~= -1 and vim.api.nvim_win_is_valid(win) then
        instance.win = win
        return win
      end
    end
  end

  dashboard.open = function(opts)
    local instance = original_open(opts)

    if instance._keveen_window_validity_patch then
      return instance
    end

    instance._keveen_window_validity_patch = true

    local original_update = instance.update
    instance.update = function(self, ...)
      if not resolve_window(self) then
        return
      end

      return original_update(self, ...)
    end

    instance.size = function(self)
      local win = resolve_window(self)
      if not win then
        return self._size or { width = 0, height = 0 }
      end

      return {
        width = vim.api.nvim_win_get_width(win),
        height = vim.api.nvim_win_get_height(win) + (vim.o.laststatus >= 2 and 1 or 0),
      }
    end

    local original_is_float = instance.is_float
    instance.is_float = function(self, ...)
      if not resolve_window(self) then
        return false
      end

      return original_is_float(self, ...)
    end

    return instance
  end
end

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      dashboard = {
        enabled = false,
        width = 84,
        pane_gap = 2,
        row = nil,
        autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        preset = {
          header = header,
          keys = {
            {
              { key = "n", hidden = true, action = ":ene | startinsert" },
              { key = "f", hidden = true, action = ":lua Snacks.dashboard.pick('files')" },
              { key = "r", hidden = true, action = ":lua Snacks.dashboard.pick('oldfiles')" },
              { key = "g", hidden = true, action = ":lua Snacks.dashboard.pick('live_grep')" },
              { key = "s", hidden = true, section = "session" },
              { key = "L", hidden = true, action = ":Lazy", enabled = package.loaded.lazy ~= nil },
              { key = "q", hidden = true, action = ":qa", enabled = package.loaded.lazy ~= nil },
            },
          },
        },
        formats = {
          header = { "%s", align = "center" },
          key = { "" },
          file = function(item)
            return {
              { item.key, hl = "key" },
              { " " },
              { item.file:sub(2):match("^(.*[/])"), hl = "NonText" },
              { item.file:match("([^/]+)$"), hl = "Normal" },
            }
          end,
          icon = { "" },
        },
        sections = {
          { section = "header" },
          { section = "keys" },
          {
            indent = 4,
            padding = 1,
            {
              {
                text = {
                  { "n ", hl = "key" },
                  { "New file", hl = "Normal" },
                  { "", width = 12 },
                  { "g ", hl = "key" },
                  { "Grep text", hl = "Normal" },
                },
              },
              { text = "", padding = 1 },
              {
                text = {
                  { "f ", hl = "key" },
                  { "Find file", hl = "Normal" },
                  { "", width = 11 },
                  { "s ", hl = "key" },
                  { "Reload session", hl = "Normal" },
                },
              },
              { text = "", padding = 1 },
              {
                text = {
                  { "r ", hl = "key" },
                  { "Recent files", hl = "Normal" },
                  { "", width = 8 },
                  { "L ", hl = "key" },
                  { "Lazy", hl = "Normal" },
                },
              },
            },
            { text = "", padding = 1 },
            { title = "Projects", padding = 1 },
            { section = "projects", limit = 5, padding = 1 },
            { title = "TODO List", padding = 1 },
            {
              function()
                local todo_opts = {
                  limit = 5,
                  match_comment_symbols = true,
                  comment_symbols = { "--", "//", "#", "/*" },
                  dirs = { "~/.config", "~/code" },
                  sign_list = { "TODO", "ERROR", "FIX", "FIXME", "BUG" },
                }

                local todos = getTodos(todo_opts)

                return vim.tbl_map(function(todo)
                  return {
                    autokey = true,
                    text = {
                      { tostring(todo.index) .. " ", hl = "key" },
                      { todo.sign .. string.rep(" ", 7 - #todo.sign), hl = "NonText" },
                      {
                        (todo.desc:len() > 35) and todo.desc:sub(1, 35) .. "∩àü" or todo.desc,
                        hl = "Normal",
                      },
                    },
                    action = function()
                      vim.fn.chdir(todo.file:match("^(.*[\\/])[^\\/]+$"))
                      vim.cmd("edit " .. todo.file)
                      vim.cmd(todo.line)
                    end,
                  }
                end, todos)
              end,
            },
          },
        },
      },
      bigfile = { enabled = true },
      explorer = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      lazygit = { enabled = true },
      -- hide TRACE/DEBUG chatter (e.g. roslyn_ls "Initializing: …"); still in :lua Snacks.notifier.show_history()
      notifier = { enabled = true, level = vim.log.levels.INFO },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            include = { "**/Properties/launchSettings.json" },
          },
          files = {
            include = { "**/Properties/launchSettings.json" },
          },
        },
      },
      quickfile = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      patch_dashboard_window_validity()
      vim.api.nvim_set_hl(0, "SnacksDashboardKey", { fg = "#5ceef6" })
      vim.api.nvim_set_hl(0, "SnacksDashboardTitle", { fg = "#c49aee" })
    end,
  },
}
