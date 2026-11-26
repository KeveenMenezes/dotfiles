-- Debug UI: one bottom panel (nvim-dap-view) instead of nvim-dap-ui's six windows,
-- breakpoints that survive restarts, and .NET-specific helpers (exceptions, attach).
local dotnet = require("config.dotnet")

local function toggle_break_on_all_exceptions()
  local current = require("dap").defaults.coreclr.exception_breakpoints
  local all = type(current) == "table" and vim.tbl_contains(current, "all")
  dotnet.set_exception_filters(all and dotnet.EXCEPTION_FILTERS or { "all", "user-unhandled" })
  vim.notify(all and "Break on: unhandled exceptions" or "Break on: ALL thrown exceptions", vim.log.levels.INFO, { title = "DAP" })
end

-- normal mode: expression under cursor; visual mode: the selection
local function eval()
  local expr
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    expr = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  end
  require("dap.ui.widgets").hover(expr)
end

return {
  -- replaced by nvim-dap-view (UI + virtual text)
  { "rcarriga/nvim-dap-ui", enabled = false },
  { "theHamsta/nvim-dap-virtual-text", enabled = false },

  {
    "igorlfs/nvim-dap-view",
    version = "1.*",
    lazy = false,
    -- stylua: ignore
    keys = {
      { "<leader>du", "<cmd>DapViewToggle<cr>", desc = "Dap View" },
      { "<leader>dW", "<cmd>DapViewWatch<cr>", desc = "Add Watch", mode = { "n", "x" } },
      { "<leader>de", eval, desc = "Eval", mode = { "n", "x" } },
    },
    opts = {
      winbar = {
        -- console merged into the panel: no extra terminal split
        sections = { "scopes", "watches", "repl", "console", "breakpoints", "exceptions", "threads" },
        default_section = "scopes",
        controls = { enabled = true },
      },
      windows = {
        size = 0.3,
        position = "below",
      },
      virtual_text = {
        enabled = true,
        position = "eol",
      },
      auto_toggle = true,
    },
  },

  {
    "Weissle/persistent-breakpoints.nvim",
    event = "BufReadPost",
    opts = {
      load_breakpoints_event = { "BufReadPost" },
    },
  },

  {
    "mfussenegger/nvim-dap",
    -- stylua: ignore
    keys = {
      { "<leader>db", function() require("persistent-breakpoints.api").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dB", function() require("persistent-breakpoints.api").set_conditional_breakpoint() end, desc = "Breakpoint Condition" },
      { "<leader>dx", function() require("persistent-breakpoints.api").clear_all_breakpoints() end, desc = "Clear All Breakpoints" },
      { "<leader>dE", toggle_break_on_all_exceptions, desc = "Toggle Break on All Exceptions" },
      { "<leader>dA", function() dotnet.attach() end, desc = "Attach to .NET Process" },
      { "<F5>", function() require("dap").continue() end, desc = "Debug: Continue" },
      { "<F9>", function() require("persistent-breakpoints.api").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "Debug: Step Out" },
    },
  },
}
