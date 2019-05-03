" Open NERD Tree automatically when vim starts up on opening a directory
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | exe 'cd '.argv()[0] | endif

" Map Ctrl+p to toggle NERDTree
map <C-p> :NERDTreeToggle<CR>

" Close NERDTree automatically if it's the only window left open:
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" NERDTree ignore wildcards:
let NERDTreeRespectWildIgnore = 1

