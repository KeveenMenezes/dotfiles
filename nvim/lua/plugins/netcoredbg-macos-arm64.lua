return {
  {
    "Cliffback/netcoredbg-macOS-arm64.nvim",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local dotnet = require("config.dotnet")

      require("netcoredbg-macOS-arm64").setup()

      local dap = require("dap")

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "NetCoreDbg: Launch",
          request = "launch",
          cwd = function()
            return dotnet.find_startup_root()
          end,
          program = function()
            return dotnet.find_program(dotnet.find_startup_root())
              or vim.fn.input("Path to dll: ", dotnet.find_startup_root(), "file")
          end,
          env = function()
            return dotnet.load_env(dotnet.find_startup_root())
          end,
        },
      }

      dap.listeners.on_config["dotnet.prepare_launch"] = function(config)
        return dotnet.prepare_launch(config)
      end

      dotnet.set_exception_filters(dotnet.EXCEPTION_FILTERS)
    end,
  },
}
