let g:ale_python_pyls_use_global = 1
let g:ale_python_yapf_use_global = 1
let g:ale_python_pylint_executable = 'python $(which pylint)'

let g:ale_completion_enabled = 1
let g:ale_completion_delay = 100
let g:ale_completion_max_suggestions = 50

let g:ale_fixers = {
\    '*': ['remove_trailing_lines', 'trim_whitespace'],
\    'javascript': ['prettier'],
\    'json' : ['prettier']
\}

let g:ale_fix_on_save = 1
