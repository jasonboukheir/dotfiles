" Enable syntax highlighting
syntax enable

" Enable ftplugin
filetype plugin on

" Set encoding
set encoding=utf8

" Use unix as standard file type
set ffs=unix,dos,mac

" Enable folding
set foldmethod=indent
set foldlevel=99

" Enable folding using spacebar
nnoremap <space> za

" Enable line numbers
set number

" Set wildcard ignores
set wildignore+=*.pyc,*.o,*.obj,*.svn,*.swp,*.class,*.hg,*.DS_Store,*.min.*,*.meta

" Turn off backup
set nobackup
set nowb
set noswapfile

" Use spaces instead of tabs
set expandtab
set smarttab

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4

" Smart indents
set ai
set si
set wrap

" Use present working directory for path
set path=$PWD/**

" Set ALE for omnifunc
set omnifunc=ale#completion#OmniFunc
