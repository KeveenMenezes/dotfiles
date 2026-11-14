# config.nu
#
# Installed by:
# version = "0.111.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# Disable startup banner / ASCII art
$env.config.show_banner = false
$env.config.edit_mode = "vi"

# Prom-Wiki theme
$env.config.color_config = {
    separator: "#888888"
    leading_trailing_space_bg: { attr: n }
    header: { fg: "#23d8ea" attr: b }
    empty: "#29b8db"
    bool: { || if $in { "#23d18b" } else { "#f47272" } }
    int: "#ff9e3b"
    filesize: { |e|
        if $e == 0b { "#888888" } else if $e < 1mb { "#23d8ea" } else { "#29b8db" }
    }
    duration: "#ff9e3b"
    date: { || (date now) - $in |
        if $in < 1hr { { fg: "#f47272" attr: b } }
        else if $in < 6hr { "#ff9e3b" }
        else if $in < 1day { "#ff9e3b" }
        else if $in < 3day { "#23d18b" }
        else if $in < 1wk { { fg: "#23d18b" attr: b } }
        else if $in < 6wk { "#29b8db" }
        else if $in < 52wk { "#23d8ea" }
        else { "#888888" }
    }
    range: "#aaaaaa"
    float: "#ff7d4d"
    string: "#aaaaaa"
    nothing: "#888888"
    binary: "#a579c3"
    cell-path: "#aaaaaa"
    row_index: { fg: "#23d8ea" attr: b }
    record: "#aaaaaa"
    list: "#aaaaaa"
    block: "#aaaaaa"
    hints: "#666666"
    search_result: { fg: "#101010" bg: "#23d8ea" }
    shape_and: { fg: "#a579c3" attr: b }
    shape_binary: { fg: "#a579c3" attr: b }
    shape_block: { fg: "#29b8db" attr: b }
    shape_bool: "#23d8ea"
    shape_closure: { fg: "#23d8ea" attr: b }
    shape_custom: "#23d18b"
    shape_datetime: { fg: "#23d8ea" attr: b }
    shape_directory: "#23d8ea"
    shape_external: "#23d8ea"
    shape_external_resolved: "#23d18b"
    shape_externalarg: { fg: "#23d18b" attr: b }
    shape_filepath: "#23d8ea"
    shape_flag: { fg: "#29b8db" attr: b }
    shape_float: { fg: "#ff7d4d" attr: b }
    shape_garbage: { fg: "#ffffff" bg: "#e05555" attr: b }
    shape_glob_interpolation: { fg: "#23d8ea" attr: b }
    shape_globpattern: { fg: "#23d8ea" attr: b }
    shape_int: { fg: "#ff9e3b" attr: b }
    shape_internalcall: { fg: "#23d8ea" attr: b }
    shape_keyword: { fg: "#a579c3" attr: b }
    shape_list: { fg: "#23d8ea" attr: b }
    shape_literal: "#29b8db"
    shape_match_pattern: "#23d18b"
    shape_matching_brackets: { attr: u }
    shape_nothing: "#23d8ea"
    shape_operator: "#ff9e3b"
    shape_or: { fg: "#a579c3" attr: b }
    shape_pipe: { fg: "#a579c3" attr: b }
    shape_range: { fg: "#ff9e3b" attr: b }
    shape_raw_string: { fg: "#23d18b" attr: b }
    shape_record: { fg: "#23d8ea" attr: b }
    shape_redirection: { fg: "#a579c3" attr: b }
    shape_signature: { fg: "#23d18b" attr: b }
    shape_string: "#23d18b"
    shape_string_interpolation: { fg: "#23d8ea" attr: b }
    shape_table: { fg: "#29b8db" attr: b }
    shape_vardecl: { fg: "#29b8db" attr: u }
    shape_variable: "#a579c3"
}

# Zoxide (z command)
source ~/.zoxide.nu
alias cd = z

# Aliases
alias vscode = code --enable-proposed-api=KeveenMenezes.prometheus
