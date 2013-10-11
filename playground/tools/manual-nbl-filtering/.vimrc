" macros for manual flagging of wrong sequences
" Ondrej Bojar
"
" Open an nbestlist in gvim, drag mouse over full words and hit <F1>
" Then use extract_rules.pl to get the forbidden patterns, see
" ./extract_rules.pl < sample-marked
"
vmap <F1> di******<ESC>hhP
