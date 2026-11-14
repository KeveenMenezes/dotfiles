# env.nu
#
# Installed by:
# version = "0.111.0"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.
# PATH
$env.PATH = ($env.PATH | split row (char esep) | prepend [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
    "/usr/local/go/bin"
    "/usr/local/share/dotnet"
    ($env.HOME + "/.dotnet/tools")
    ($env.HOME + "/.nvm/versions/node/v23.11.1/bin")
    ($env.HOME + "/.aspire/bin")
    ($env.HOME + "/.local/bin")
    "/opt/homebrew/opt/mysql-client/bin"
    "/opt/homebrew/opt/ruby/bin"
    "/opt/homebrew/lib/ruby/gems/4.0.0/bin"
    ($env.HOME + "/Library/Android/sdk/cmdline-tools/latest/bin")
    ($env.HOME + "/Library/Android/sdk/platform-tools")
    ($env.HOME + "/Library/Android/sdk/build-tools/35.0.0")
] | uniq)

# Env vars
# Variáveis de projeto/infra (hosts, usuários, endpoints) ficam em autoload/local.nu,
# que não é versionado. Veja nushell/autoload/local.nu.example.
$env.GOOGLE_APPLICATION_CREDENTIALS = ($env.HOME + "/.config/gcloud/application_default_credentials.json")
$env.JAVA_HOME = "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
$env.ANDROID_HOME = ($env.HOME + "/Library/Android/sdk")

# Disable Aspire CLI update check (was causing dotnet run/build to hang indefinitely)
$env.ASPIRE_VERSION_CHECK_DISABLED = "true"

# Ctrl+R fica com o atuin (histórico por pasta/repo); "" desliga o Ctrl+R do fzf.
$env.FZF_CTRL_R_COMMAND = ""
