syntax on
set number
set noswapfile
set hlsearch
set ignorecase
set incsearch
set ruler
set ai
set mouse=a
set smartindent
set tabstop=2
set shiftwidth=2
set expandtab

highlight Comment ctermfg=lightblue
highlight String ctermfg=lightgreen

inoremap jj <ESC>
let mapleader = "'"

let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"
set ttimeout
set ttimeoutlen=1
set listchars=tab:>-,trail:~,extends:>,precedes:<,space:.
set ttyfast
