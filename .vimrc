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

" Give more space for displaying messages.
set cmdheight=2

" Having longer updatetime leads to noticeable
" delays and poor user experience.
set updatetime=300

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
if has("nvim-0.5.0") || has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

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

" Source all files in rc directory:
for f in split(glob('~/.vim/vimrc.d/*.vim'), '\n')
	exe 'source' f
endfor

" Put these lines at the very end of your vimrc file.

" Load all plugins now.
" Plugins need to be added to runtimepath before helptags can be generated.
packloadall
" Load all of the helptags now, after plugins have been loaded.
" All messages and errors will be ignored.
silent! helptags ALL
