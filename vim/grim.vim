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

" Tab completion: progressively complete space-separated command words, then --flags
function! s:GrimComplete(ArgLead, CmdLine, CursorPos)
    let parts = split(a:CmdLine)[1:]

    " Collect non-flag words (the command name parts)
    let cmd_words = []
    for word in parts
        if word =~# '^--' | break | endif
        call add(cmd_words, word)
    endfor

    let in_flags = len(cmd_words) < len(parts) || a:ArgLead =~# '^-'

    " Fetch all command names
    let all_lines = systemlist(shellescape(s:grim_bin) . ' command list --output tsv 2>/dev/null')[1:]
    let all_names = map(copy(all_lines), 'split(v:val, "\t")[0]')

    " If cmd_words already forms a complete command, switch to flag completion
    if !in_flags && index(all_names, join(cmd_words, ' ')) >= 0
        let in_flags = 1
    endif

    if in_flags
        let cmd = substitute(join(cmd_words, ' '), ' ', '_', 'g')
        if empty(cmd) | return [] | endif
        let flag_lines = systemlist(shellescape(s:grim_bin) . ' command show ' . shellescape(cmd) . ' --output tsv 2>/dev/null')[1:]
        let flags = map(flag_lines, '"--" . split(v:val, "\t")[0]')
        return filter(flags, 'v:val =~# "^" . a:ArgLead')
    endif

    " Complete next word of the command name
    let n = len(cmd_words)
    let prefix_words = n >= 2 ? cmd_words[0:n-2] : []
    let prefix = empty(prefix_words) ? '' : join(prefix_words, ' ') . ' '
    let search = prefix . a:ArgLead
    return filter(copy(all_names), 'v:val =~# "^" . escape(search, ".")')
endfunction

command! -nargs=+ -complete=customlist,<SID>GrimComplete Grim call <SID>GrimRun(<q-args>)
