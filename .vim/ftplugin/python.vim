setlocal tabstop=4
setlocal softtabstop=4
setlocal shiftwidth=4
setlocal textwidth=79
setlocal expandtab
setlocal autoindent
setlocal fileformat=unix

let b:ale_fixers = ['yapf']
let b:ale_linters = ['pyls', 'pylint']
let b:ale_python_pylint_options = '--load-plugins pylint_django'
