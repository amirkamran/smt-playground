au BufNewFile,BufRead *bleu* so hilite


au BufNewFile,BufRead *bleu*,modelstat,mertstat,evalstat set nowrap
au BufNewFile,BufRead *bleu*,modelstat,mertstat,evalstat set ts=1
au BufNewFile,BufRead *bleu*,modelstat,mertstat,evalstat set hls

" quickjudge annotations
"map q1 0i*<ESC>j
"map q2 0i**<ESC>j
"map q3 0i-<ESC>j
au BufNewFile,BufRead *.anot map q1 0i*<ESC>j
au BufNewFile,BufRead *.anot map q2 0i**<ESC>j
au BufNewFile,BufRead *.anot map q3 0i-<ESC>j
au BufNewFile,BufRead *.anot map <F1> 0i*<ESC>j
au BufNewFile,BufRead *.anot map <F2> 0i**<ESC>j
au BufNewFile,BufRead *.anot map <F3> 0i-<ESC>j
au BufNewFile,BufRead *.anot map e 0iequally-fine<ESC>j
au BufNewFile,BufRead *.anot map <F5> 0iequally-fine<ESC>j
au BufNewFile,BufRead *.anot map w 0iequally-wrong<ESC>j
au BufNewFile,BufRead *.anot map <F6> 0iequally-wrong<ESC>j
au BufNewFile,BufRead *.anot map s 0i*<ESC>j
