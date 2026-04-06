" Grim vim integration
" Add to your .vimrc:
"   source /path/to/grim/vim/grim.vim

let s:grim_bin = expand('<sfile>:p:h:h') . '/bin/grim'

" Run a grim command and show output in a scratch split
function! s:GrimRun(args)
    let output = systemlist(shellescape(s:grim_bin) . ' ' . a:args)
    if v:shell_error
        echohl ErrorMsg | echo join(output, "\n") | echohl None
        return
    endif

    " Detect --output value to set filetype
    let ft = ''
    let m = matchlist(a:args, '--output\s\+\(\S\+\)')
    if !empty(m)
        let fmt = m[1]
        if fmt ==# 'json' | let ft = 'json'
        elseif fmt ==# 'md'  | let ft = 'markdown'
        endif
    endif

    new
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
    call setline(1, output)
    if !empty(ft)
        execute 'setlocal filetype=' . ft
    endif
endfunction

" Tab completion: first arg = command name, subsequent args = --flags
function! s:GrimComplete(ArgLead, CmdLine, CursorPos)
    let args = split(a:CmdLine)[1:]

    if empty(args) || (len(args) == 1 && !empty(a:ArgLead))
        let lines = systemlist(shellescape(s:grim_bin) . ' grim_command_list --output tsv 2>/dev/null')[1:]
        let names = map(lines, 'split(v:val, "\t")[0]')
        return filter(names, 'v:val =~# "^" . a:ArgLead')
    endif

    let cmd = args[0]
    let lines = systemlist(shellescape(s:grim_bin) . ' grim_command_show ' . shellescape(cmd) . ' --output tsv 2>/dev/null')[1:]
    let flags = map(lines, '"--" . split(v:val, "\t")[0]')
    return filter(flags, 'v:val =~# "^" . a:ArgLead')
endfunction

command! -nargs=+ -complete=customlist,<SID>GrimComplete Grim call <SID>GrimRun(<q-args>)
