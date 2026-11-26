local M = {}

local uv = vim.uv or vim.loop

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()
  return content
end

local function current_dir()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    return vim.fs.dirname(bufname)
  end

  return uv.cwd()
end

local function first_match(content, pattern)
  return content and content:match(pattern) or nil
end

local function parse_env_content(content)
  local env = {}
  for line in content:gmatch("[^\r\n]+") do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
    if key and value then
      env[key] = value:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    end
  end

  return env
end

local function merge_tables(...)
  return vim.tbl_extend("force", ...)
end

local function parse_command_line_args(command_line_args)
  if type(command_line_args) ~= "string" or command_line_args == "" then
    return nil
  end

  return vim.split(command_line_args, "%s+", { trimempty = true })
end

local function has_file(dir, name)
  return vim.fn.filereadable(vim.fs.joinpath(dir, name)) == 1
end

local function is_executable_project(csproj)
  local content = read_file(csproj) or ""
  local root = vim.fs.dirname(csproj)

  return content:match("Microsoft%.NET%.Sdk%.Web") ~= nil
    or content:match("<OutputType>%s*Exe%s*</OutputType>") ~= nil
    or content:match("<OutputType>%s*WinExe%s*</OutputType>") ~= nil
    or has_file(root, "Program.cs")
    or has_file(vim.fs.joinpath(root, "Properties"), "launchSettings.json")
end

local function startup_project_score(csproj)
  local content = read_file(csproj) or ""
  local root = vim.fs.dirname(csproj)
  local score = 0

  if content:match("Microsoft%.NET%.Sdk%.Web") then
    score = score + 100
  end
  if has_file(root, "Program.cs") then
    score = score + 50
  end
  if has_file(vim.fs.joinpath(root, "Properties"), "launchSettings.json") then
    score = score + 25
  end

  return score
end

local function launch_settings_path(start)
  local path = vim.fs.joinpath(M.find_startup_root(start), "Properties", "launchSettings.json")
  return vim.fn.filereadable(path) == 1 and path or nil
end

-- Profile names in file order: `dotnet run` picks the first one, and vim.json.decode loses key order.
local function profile_names_in_file_order(profiles, content)
  local names = vim.tbl_keys(profiles)
  local function position(name)
    return content:find('"' .. vim.pesc(name) .. '"%s*:%s*{') or math.huge
  end
  table.sort(names, function(a, b)
    local pa, pb = position(a), position(b)
    if pa ~= pb then
      return pa < pb
    end
    return a < b
  end)
  return names
end

local function select_launch_profile(profiles, content)
  if type(profiles) ~= "table" then
    return nil
  end

  local preferred_profile = vim.env.DOTNET_LAUNCH_PROFILE or vim.env.LAUNCH_PROFILE
  if preferred_profile and type(profiles[preferred_profile]) == "table" then
    return profiles[preferred_profile]
  end

  local names = profile_names_in_file_order(profiles, content)

  for _, name in ipairs(names) do
    local profile = profiles[name]
    if type(profile) == "table" and profile.commandName == "Project" then
      return profile
    end
  end

  for _, name in ipairs(names) do
    local profile = profiles[name]
    if type(profile) == "table" then
      return profile
    end
  end
end

local function load_launch_profile(start)
  local path = launch_settings_path(start)
  if not path then
    return {}
  end

  local content = read_file(path)
  if not content then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Could not parse " .. path, vim.log.levels.ERROR)
    return {}
  end

  local profile = select_launch_profile(decoded.profiles, content)
  if type(profile) ~= "table" then
    return {}
  end

  local env = type(profile.environmentVariables) == "table" and vim.deepcopy(profile.environmentVariables) or {}
  -- `dotnet run` turns applicationUrl into ASPNETCORE_URLS; launching the dll directly does not
  if type(profile.applicationUrl) == "string" and profile.applicationUrl ~= "" and not env.ASPNETCORE_URLS then
    env.ASPNETCORE_URLS = profile.applicationUrl
  end

  return {
    args = parse_command_line_args(profile.commandLineArgs),
    env = env,
  }
end

function M.find_csproj(start)
  return vim.fs.find(function(name)
    return name:match("%.csproj$")
  end, { path = start or current_dir(), upward = true, limit = 1 })[1]
end

function M.find_solution_root(start)
  local sln = vim.fs.find(function(name)
    return name:match("%.sln$")
  end, { path = start or current_dir(), upward = true, limit = 1 })[1]

  return sln and vim.fs.dirname(sln) or nil
end

function M.find_project_root(start)
  local csproj = M.find_csproj(start)
  if csproj then
    return vim.fs.dirname(csproj)
  end

  return M.find_solution_root(start) or vim.fn.getcwd()
end

function M.find_root(start)
  return M.find_project_root(start)
end

function M.find_startup_csproj(start)
  local csproj = M.find_csproj(start)
  if csproj and is_executable_project(csproj) then
    return csproj
  end

  local search_root = M.find_solution_root(start) or M.find_project_root(start)
  local candidates = vim.fn.globpath(search_root, "**/*.csproj", false, true)
  local best_csproj
  local best_score = -1

  for _, candidate in ipairs(candidates) do
    if is_executable_project(candidate) then
      local score = startup_project_score(candidate)
      if score > best_score then
        best_csproj = candidate
        best_score = score
      end
    end
  end

  return best_csproj or csproj
end

function M.find_startup_root(start)
  local startup_csproj = M.find_startup_csproj(start)
  return startup_csproj and vim.fs.dirname(startup_csproj) or M.find_project_root(start)
end

function M.project_metadata(start)
  local csproj = M.find_csproj(start)
  local root = M.find_project_root(start)
  if not csproj then
    return {
      root = root,
      assembly_name = vim.fn.fnamemodify(root, ":t"),
    }
  end

  local content = read_file(csproj) or ""
  local target_framework = first_match(content, "<TargetFramework>(.-)</TargetFramework>")
  if not target_framework then
    local frameworks = first_match(content, "<TargetFrameworks>(.-)</TargetFrameworks>")
    if frameworks then
      target_framework = vim.split(frameworks, ";", { plain = true })[1]
    end
  end

  return {
    csproj = csproj,
    root = root,
    target_framework = target_framework,
    assembly_name = first_match(content, "<AssemblyName>(.-)</AssemblyName>")
      or vim.fn.fnamemodify(csproj, ":t:r"),
  }
end

function M.find_program(start)
  local meta = M.project_metadata(start)
  local debug_root = vim.fs.joinpath(meta.root, "bin", "Debug")
  local assembly_name = meta.assembly_name

  if meta.target_framework then
    local preferred = vim.fs.joinpath(debug_root, meta.target_framework, assembly_name .. ".dll")
    if vim.fn.filereadable(preferred) == 1 then
      return preferred
    end
  end

  local candidates = vim.fn.globpath(debug_root, "**/" .. assembly_name .. ".dll", false, true)
  local newest_path
  local newest_mtime = -1

  for _, candidate in ipairs(candidates) do
    local stat = uv.fs_stat(candidate)
    local mtime = stat and stat.mtime and stat.mtime.sec or -1
    if mtime > newest_mtime then
      newest_path = candidate
      newest_mtime = mtime
    end
  end

  return newest_path
end

function M.load_env(start)
  local env_path = vim.fs.joinpath(M.find_root(start), ".env")
  local content = read_file(env_path)
  local launch_profile = load_launch_profile(start)

  return merge_tables(launch_profile.env or {}, content and parse_env_content(content) or {})
end

function M.load_args(start)
  return load_launch_profile(start).args
end

local BUILD_QF_TITLE = "dotnet build"
local BUILD_NOTIFY = { title = "dotnet build", id = "dotnet_build" }

-- straight to Snacks.notifier: noice drops `id`, and we want each status to replace the previous one
local function build_notify(msg, level)
  if _G.Snacks and Snacks.notifier then
    Snacks.notifier.notify(msg, level, BUILD_NOTIFY)
  else
    vim.notify(msg, level, BUILD_NOTIFY)
  end
end

-- MSBuild diagnostics: `path/File.cs(12,5): error CS1002: ; expected [path/Proj.csproj]`
local function parse_build_errors(output)
  local items, seen = {}, {}
  for line in output:gmatch("[^\r\n]+") do
    local file, lnum, col, code, text = line:match("^%s*(.-)%((%d+),(%d+)%)%s*:%s*error%s+(%S+)%s*:%s*(.-)%s*$")
    if file then
      text = text:gsub("%s*%[[^%]]*%]$", "")
      local key = table.concat({ file, lnum, col, code }, ":")
      if not seen[key] then
        seen[key] = true
        table.insert(items, {
          filename = file,
          lnum = tonumber(lnum),
          col = tonumber(col),
          type = "E",
          text = code .. ": " .. text,
        })
      end
    end
  end
  return items
end

local function clear_build_qf()
  if vim.fn.getqflist({ title = 0 }).title == BUILD_QF_TITLE then
    vim.fn.setqflist({}, "r", { title = BUILD_QF_TITLE, items = {} })
    pcall(vim.cmd.cclose)
  end
end

local function report_build_failure(result)
  local output = table.concat({ result.stdout or "", result.stderr or "" }, "\n")
  local items = parse_build_errors(output)
  if #items == 0 then
    build_notify(output, vim.log.levels.ERROR)
    return
  end

  vim.fn.setqflist({}, " ", { title = BUILD_QF_TITLE, items = items })
  build_notify(("Build failed: %d error(s)"):format(#items), vim.log.levels.ERROR)
  if not pcall(function() require("trouble").open({ mode = "qflist", focus = false }) end) then
    vim.cmd("copen")
  end
end

--- Builds asynchronously; errors go to the quickfix list instead of a terminal buffer.
---@param root? string
---@param on_done? fun(ok: boolean)
function M.build(root, on_done)
  root = root or M.find_project_root()
  vim.cmd("silent! wall")
  build_notify("Building " .. vim.fn.fnamemodify(root, ":t") .. "…", vim.log.levels.INFO)

  vim.system(
    { "dotnet", "build", "-nologo", "-tl:off", "-v:q", "-clp:NoSummary" },
    { cwd = root, text = true },
    vim.schedule_wrap(function(result)
      local ok = result.code == 0
      if ok then
        clear_build_qf()
        build_notify("Build succeeded", vim.log.levels.INFO)
      else
        report_build_failure(result)
      end
      if on_done then
        on_done(ok)
      end
    end)
  )
end

-- nvim-dap runs on_config listeners inside a coroutine, so the build can yield instead of freezing the UI
local function build_and_wait(root)
  local co, is_main = coroutine.running()
  if not co or is_main then
    local done, ok = false, false
    M.build(root, function(success)
      done, ok = true, success
    end)
    vim.wait(10 * 60 * 1000, function() return done end, 100)
    return ok
  end

  M.build(root, function(ok)
    coroutine.resume(co, ok)
  end)
  return coroutine.yield()
end

-- netcoredbg only offers "user-unhandled" and "all", and marks neither as default,
-- so without this no exception ever stops the debugger.
M.EXCEPTION_FILTERS = { "user-unhandled" }

---@param filters string[]
function M.set_exception_filters(filters)
  local dap = require("dap")
  for _, adapter in ipairs({ "coreclr", "netcoredbg" }) do
    dap.defaults[adapter].exception_breakpoints = filters
  end
  if dap.session() then
    dap.set_exception_breakpoints(filters)
  end
end

-- Processes worth attaching to: built apps and `dotnet <app>.dll`, minus SDK/tooling noise.
local ATTACH_NOISE = { "LanguageServer", "MSBuild", "VBCSCompiler", "netcoredbg", "dotnet%-watch", "vstest", "testhost", "sonarlint", "EasyDotnet" }

local function is_attachable(proc)
  local name = proc.name
  local built_app = name:find("/bin/[Dd]ebug/") or name:find("/bin/[Rr]elease/")
  local dotnet_dll = name:match("^%S*dotnet%s") and name:find("%.dll")
  if not (built_app or dotnet_dll) then
    return false
  end
  for _, pattern in ipairs(ATTACH_NOISE) do
    if name:find(pattern) then
      return false
    end
  end
  return true
end

function M.attach()
  require("dap").run({
    type = "coreclr",
    name = "NetCoreDbg: Attach",
    request = "attach",
    processId = function()
      return require("dap.utils").pick_process({ filter = is_attachable, prompt = "Attach to .NET process: " })
    end,
  })
end

function M.prepare_launch(config)
  if not config or (config.type ~= "coreclr" and config.type ~= "netcoredbg") or config.request ~= "launch" then
    return config
  end

  local root = M.find_startup_root(type(config.cwd) == "string" and config.cwd or nil)
  if not build_and_wait(root) then
    config.program = require("dap").ABORT
    return config
  end

  local program = M.find_program(root)
  if not program then
    vim.notify("Could not locate the built .NET DLL to debug.", vim.log.levels.ERROR)
    config.program = require("dap").ABORT
    return config
  end

  config.cwd = root
  config.program = program
  config.env = M.load_env(root)
  config.args = config.args or M.load_args(root)
  return config
end

return M
