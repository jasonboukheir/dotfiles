if "_SOURCED_ZSH" not-in $env {
    # Run zsh -l -i to source login profiles, get its env output, parse into a record
    let zsh_env_lines = (zsh -l -i -c "env" | lines)
    let zsh_env = ($zsh_env_lines | each { |line|
    let split = ($line | split row -n 1 "=")
    { ($split.0): ($split.1? | default "") }
    } | reduce --fold {} { |it, acc| $acc | merge $it })

    # Exclude conflicting/unnecessary vars (customize this list as needed)
    let excludes = [
        "config" "_" "FILE_PWD" "PWD" "SHLVL" "CURRENT_FILE"
        "STARSHIP_SESSION_KEY"
        "PROMPT_COMMAND" "PROMPT_COMMAND_RIGHT" "PROMPT_INDICATOR"
        "PROMPT_INDICATOR_VI_INSERT" "PROMPT_INDICATOR_VI_NORMAL"
        "PROMPT_MULTILINE_INDICATOR"
        "TRANSIENT_PROMPT_COMMAND_RIGHT" "TRANSIENT_PROMPT_MULTILINE_INDICATOR"
    ]

    # Filter and load
    let filtered_env = ($zsh_env | reject -o ...$excludes)
    load-env $filtered_env

    $env._SOURCED_ZSH = true
}
