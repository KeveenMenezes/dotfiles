local M = {}

local uv = vim.uv or vim.loop
local home = uv.os_homedir()
local sonarw = vim.fn.expand("~/.local/bin/sonarw")
local config_dir = vim.fs.joinpath(home, ".config", "sonar")
local mason_extension_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "sonarlint-language-server", "extension")
local local_extension_dir = vim.fs.joinpath(home, ".local", "share", "sonarlint-language-server", "extension")

M.filetypes = {
  "cs",
  "dockerfile",
  "go",
  "html",
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "xml",
  "yaml",
  "yaml.docker-compose",
}

local function file_exists(path)
  return path ~= nil and uv.fs_stat(path) ~= nil
end

local function extension_dir()
  if file_exists(mason_extension_dir) then
    return mason_extension_dir
  end

  return local_extension_dir
end

local function analyzers_dir()
  return vim.fs.joinpath(extension_dir(), "analyzers")
end

local function language_server_cmd()
  local local_cmd = vim.fn.expand("~/.local/bin/sonarlint-language-server")
  if file_exists(local_cmd) then
    return local_cmd
  end

  return "sonarlint-language-server"
end

local function read_sonarw_info(root)
  if not file_exists(sonarw) then
    return {}
  end

  local output = vim.fn.system({ sonarw, "info", "--json", "--cwd", root })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= "table" then
    return {}
  end

  return decoded
end

local function has_any(patterns)
  for _, pattern in ipairs(patterns) do
    if #vim.fn.glob(pattern, false, true) > 0 then
      return true
    end
  end
  return false
end

function M.project_root(bufname)
  local target = bufname
  if target == nil or target == "" then
    target = vim.api.nvim_buf_get_name(0)
  end

  local dir = target ~= "" and vim.fs.dirname(target) or vim.fn.getcwd()
  local previous = nil

  while dir and dir ~= previous do
    if file_exists(vim.fs.joinpath(dir, ".git"))
      or file_exists(vim.fs.joinpath(dir, "sonar-project.properties"))
      or file_exists(vim.fs.joinpath(dir, "package.json"))
      or file_exists(vim.fs.joinpath(dir, "go.mod"))
      or has_any({
        vim.fs.joinpath(dir, "*.sln"),
        vim.fs.joinpath(dir, "*.csproj"),
      })
    then
      return dir
    end

    previous = dir
    dir = vim.fs.dirname(dir)
  end

  return vim.fn.getcwd()
end

local function analyzer_paths()
  local names = {
    "sonarcsharp.jar",
    "csharpenterprise.jar",
    "sonargo.jar",
    "sonarhtml.jar",
    "sonariac.jar",
    "sonarjava.jar",
    "sonarjavasymbolicexecution.jar",
    "sonarjs.jar",
    "sonarxml.jar",
  }

  local analyzers = {}
  for _, name in ipairs(names) do
    local path = vim.fs.joinpath(analyzers_dir(), name)
    if file_exists(path) then
      table.insert(analyzers, path)
    end
  end

  return analyzers
end

local function csharp_init_options()
  return {
    omnisharpDirectory = vim.fs.joinpath(extension_dir(), "omnisharp"),
    csharpOssPath = vim.fs.joinpath(analyzers_dir(), "sonarcsharp.jar"),
    csharpEnterprisePath = vim.fs.joinpath(analyzers_dir(), "csharpenterprise.jar"),
  }
end

local function connected_mode_settings(info)
  if not info.host_url or info.host_url == "" then
    return {}
  end

  return {
    sonarlint = {
      connectedMode = {
        connections = {
          sonarqube = {
            {
              connectionId = info.connection_id or "corp-sonarqube",
              serverUrl = info.host_url,
              disableNotifications = false,
            },
          },
        },
      },
    },
  }
end

function M.sonarlint_opts()
  local analyzers = analyzer_paths()
  local root = M.project_root()
  local info = read_sonarw_info(root)
  local cmd = { language_server_cmd(), "-stdio" }
  if #analyzers > 0 then
    vim.list_extend(cmd, { "-analyzers" })
    vim.list_extend(cmd, analyzers)
  end
  local opts = {
    filetypes = M.filetypes,
    connected = {
      get_credentials = function()
        return vim.fn.getenv("SONAR_TOKEN")
      end,
    },
    server = {
      cmd = cmd,
      init_options = csharp_init_options(),
      settings = connected_mode_settings(info),
      before_init = function(params, config)
        local current = read_sonarw_info(params.rootPath)
        if current.host_url and current.host_url ~= "" and current.project_key and current.project_key ~= "" then
          config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
            sonarlint = {
              connectedMode = {
                project = {
                  connectionId = current.connection_id or "corp-sonarqube",
                  projectKey = current.project_key,
                },
              },
            },
          })
        end
      end,
    },
  }

  return opts
end

local function run_in_terminal(command)
  local root = M.project_root()
  local argv = { sonarw, command, "--cwd", root }

  if _G.Snacks and Snacks.terminal then
    Snacks.terminal(argv, { cwd = root })
    return
  end

  vim.cmd("botright split")
  vim.fn.termopen(argv, { cwd = root })
  vim.cmd("startinsert")
end

function M.scan()
  run_in_terminal("scan")
end

function M.doctor()
  run_in_terminal("doctor")
end

function M.ensure_layout()
  vim.fn.mkdir(config_dir, "p")
end

return M
