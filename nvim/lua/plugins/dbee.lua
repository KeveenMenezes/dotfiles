return {
  {
    "kndndrj/nvim-dbee",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    lazy = true,
    cmd = { "Dbee" },
    build = function()
      require("dbee").install()
    end,
    opts = function()
      local dbee_layouts = require("config.dbee_layouts")
      return {
        float_options = {
          border = "rounded",
        },
        window_layout = dbee_layouts.floating,
        result = {
          page_size = 20,
        },
      }
    end,
    config = function(_, opts)
      local ResultUI = require("dbee.ui.result")

      if not ResultUI._keveen_defer_result_render then
        ResultUI._keveen_defer_result_render = true

        function ResultUI:on_call_state_changed(data)
          local call = data.call

          if not self.current_call or call.id ~= self.current_call.id then
            return
          end

          self.current_call = call

          if call.state == "executing" or call.state == "retrieving" then
            self.stop_progress()
            self:display_progress()
          elseif call.state == "archived" then
            self.stop_progress()
            vim.schedule(function()
              if not self.current_call or self.current_call.id ~= call.id then
                return
              end

              local ok = pcall(self.page_current, self)
              if not ok then
                self:set_default_result_window()
              end
            end)
          elseif call.state == "executing_failed" or call.state == "retrieving_failed" or call.state == "canceled" then
            self.stop_progress()
            self:display_status()
          else
            self.stop_progress()
          end
        end
      end

      require("dbee").setup(opts)
    end,
  },
}
