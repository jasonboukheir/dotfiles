if "_SOURCED_BASH" not-in $env {
    # Run bash -l -i to source login profiles, get its env output, parse into a record
    let bash_env_lines = (bash -l -i -c "env" | lines)
    let bash_env = ($bash_env_lines | each { |line|
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
    let filtered_env = ($bash_env | reject -i ...$excludes)
    load-env $filtered_env

    $env._SOURCED_BASH = true
}
