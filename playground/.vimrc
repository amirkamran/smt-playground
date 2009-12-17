au BufNewFile,BufRead *bleu* so hilite


au BufNewFile,BufRead *bleu*,modelstat,mertstat,evalstat set nowrap
au BufNewFile,BufRead *bleu*,modelstat,mertstat,evalstat set ts=1
au BufNewFile,BufRead *bleu*,modelstat,mertstat,evalstat set hls

" quickjudge annotations
au BufNewFile,BufRead *.anot map <F1> 0i*<ESC>j
au BufNewFile,BufRead *.anot map <F2> 0i**<ESC>j

