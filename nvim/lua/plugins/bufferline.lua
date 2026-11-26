return {
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      local promowiki = require("promowiki")
      local palette = promowiki.get_palette()
      local active_bg = promowiki.options.transparent_background and "NONE" or palette.base
      local inactive_bg = promowiki.options.transparent_background and "NONE" or palette.mantle
      local separator_fg = promowiki.options.transparent_background and palette.surface2 or palette.crust

      opts.options = opts.options or {}
      opts.highlights = vim.tbl_deep_extend("force", opts.highlights or {}, {
        background = { fg = palette.overlay1, bg = inactive_bg },
        buffer_visible = { fg = palette.subtext0, bg = inactive_bg },
        buffer_selected = { fg = palette.text, bg = active_bg, bold = true, italic = false },
        tab = { fg = palette.overlay1, bg = inactive_bg },
        tab_selected = { fg = palette.sky, bg = active_bg, bold = true, italic = false },
        separator = { fg = separator_fg, bg = inactive_bg },
        separator_visible = { fg = separator_fg, bg = inactive_bg },
        separator_selected = { fg = palette.sky, bg = active_bg },
        indicator_selected = { fg = palette.sky, bg = active_bg, bold = true },
        modified = { fg = palette.teal, bg = inactive_bg },
        modified_visible = { fg = palette.teal, bg = inactive_bg },
        modified_selected = { fg = palette.teal, bg = active_bg },
        close_button = { fg = palette.subtext0, bg = inactive_bg },
        close_button_visible = { fg = palette.subtext0, bg = inactive_bg },
        close_button_selected = { fg = palette.sky, bg = active_bg },
      })

      local filter = opts.options.custom_filter
      local formatter = opts.options.name_formatter
      opts.options.custom_filter = function(buf, bufnums)
        local name = vim.api.nvim_buf_get_name(buf)
        local ft = vim.bo[buf].filetype

        if ft == "snacks_dashboard" or name:match("nvim%-treesitter") then
          return false
        end

        if filter then
          return filter(buf, bufnums)
        end

        return true
      end

      opts.options.name_formatter = function(element)
        if element.tabnr then
          local tabpage = vim.api.nvim_list_tabpages()[element.tabnr]
          if tabpage then
            local ok, name = pcall(vim.api.nvim_tabpage_get_var, tabpage, "dbee_tab_name")
            if ok and type(name) == "string" and name ~= "" then
              return name
            end
          end
        end

        if formatter then
          return formatter(element)
        end
      end
    end,
  },
}
