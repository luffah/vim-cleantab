" cleantab.vim -- Vim lib which add Clean command in order to clean unordered tabline
" @Author:      luffah (luffah AT runbox com)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2026-05-17
" @Last Change: 2026-05-17
" @Revision:    1

"@command Clean <opts> <patterns>
"Clean tabs (and then tabline)..
"   Options are in shell style:
"    -h help
"    <X  >X  to target tabs between strict min and max
"    -b close buffers matching patterns
"    -e close unammed buffers
"    -E empty buffers
"    -H hidden buffers
"    -u unlisted buffers
"    -t close tabs matching patterns [default if none provided]
"    -d close double tabs [default if none provided]
"    -s sort tabs
"    -a all above
"    -A all tabs
command! -nargs=* Clean call s:Clean(<f-args>)
func! s:Clean(...)
    let l:tabclose=0
    let l:tabcloseall=0
    let l:dtabclose=0
    let l:sorttab=0
    let l:sorttab_by_path=0
    let l:sorttab_by_name=0
    let l:sorttab_by_ft=0
    let l:rmbuff=0
    let l:closeunammedbuffers=0
    let l:closeemptybuffers=0
    let l:wipeouthiddenbuffers=0
    let l:wipeoutunlistedbuffers=0
    let l:opts=''
    let l:args=[]
    let l:max_idx=tabpagenr('$') + 1
    let l:curtab=tabpagenr()
    let l:min_idx=0
    let l:idx_focus=0
    for l:a in a:000
        if l:a  =~ '<\d'
            let l:max_idx=str2nr(l:a[1:])
            let l:idx_focus=1
        elseif l:a  =~ '>\d'
            let l:min_idx=str2nr(l:a[1:])
            let l:idx_focus=1
        elseif l:a =~ '^-'
            let l:opts .= l:a[1:]
        else
            call add(l:args, l:a)
        endif
    endfor
    if l:opts == ''
        let l:opts = 'td'
    endif
    if l:opts =~# 'h'
        unsilent echo "Clean <opts> <patterns>"
        unsilent echo " -h this help"
        unsilent echo " <X  >X  to target tabs between strict min and max"
        unsilent echo " -b close buffers matching patterns"
        unsilent echo " -e close unammed buffers"
        unsilent echo " -E close empty buffers"
        unsilent echo " -H wipeout hidden buffers"
        unsilent echo " -u wipeout unlisted buffers"
        unsilent echo " -t close tabs matching patterns [default if none provided]"
        unsilent echo " -d close double tabs [default if none provided]"
        unsilent echo " -s sort tabs"
        unsilent echo " -a all above"
        unsilent echo " -A all tabs"
        return
    endif
    let l:nopat=(len(l:args) == 0)
    if l:opts =~# 'H'
        let l:wipeouthiddenbuffers=1
    endif
    if l:opts =~# 'u'
        let l:wipeoutunlistedbuffers=1
    endif
    if l:opts =~# 'E'
        let l:closeemptybuffers=1
    endif
    if l:opts =~# 'e'
        let l:closeunammedbuffers=1
    endif
    if l:opts =~# 'b'
        let l:rmbuff=1
    endif
    if l:opts =~# 't'
        let l:tabclose=1
    endif
    if l:opts =~# 's'
        let l:sorttab=1
        if l:opts =~# 'sp'
            let l:sorttab_by_path=1
        endif
        if l:opts =~# 'sn'
            let l:sorttab_by_name=1
        endif
        if l:opts =~# 'st'
            let l:sorttab_by_ft=1
        endif
    endif
    if l:opts =~# 'd'
        let l:dtabclose=1
    endif
    if l:opts  =~# 'a'
        let l:tabclose=1
        let l:rmbuff=1
        let l:sorttab=1
        let l:dtabclose=1
        let l:closeunammedbuffers=1
    endif
    if l:opts =~# 'A'
        let l:tabcloseall=1
    endif

    if l:nopat
        if (l:tabcloseall || (l:tabclose && l:idx_focus))
            tabdo call s:MarkTabToClose(l:min_idx, l:max_idx, [])
        endif
    else
        if l:tabclose
            tabdo call s:MarkTabToClose(l:min_idx, l:max_idx, l:args)
        endif
        if l:rmbuff
            for l:a in l:args
                call s:CloseBuffers('bufname(l:i) =~ "'.escape(a:pattern, '"').'"')
            endfor
        endif
    endif

    tabdo if get(t:, 'tab_to_close', 0) | tabclose | endif
exe l:curtab.'tabnext'

if l:closeunammedbuffers
    call s:CloseBuffers("bufname(l:i) =~ '^$'")
endif

if l:closeemptybuffers
    call s:CloseBuffers("(empty(getbufinfo(l:i)) || (getbufinfo(l:i)[0]['lnum'] == 1 && getbufline(l:i,'$') == ['']))")
endif

if l:wipeouthiddenbuffers
    call s:CloseBuffers("(!empty(getbufinfo(l:i)) && (getbufinfo(l:i)[0]['hidden'] == 1))", 'bwipeout')
endif

if l:wipeoutunlistedbuffers
    call s:CloseBuffers("(!empty(getbufinfo(l:i)) && (getbufinfo(l:i)[0]['listed'] == 0))", 'bwipeout')
endif

if l:dtabclose
    call s:CleanDoubleTabs()
endif

if l:sorttab
    if l:sorttab_by_path
        call s:SortTabs('%:p')
    elseif l:sorttab_by_name
        call s:SortTabs('%:t')
    elseif l:sorttab_by_ft
        call s:SortTabs('%:e', '%:t')
    else
        call s:SortTabs('%:e', '%:t', '%:p')
    endif
endif

endfu

func! s:CleanDoubleTabs()
    let l:doubles = []
    let l:all_buffers = []
    let l:all_tabs = []
    let l:t = tabpagenr()
    for l:i in range(1,tabpagenr('$'))
        let l:buflist = tabpagebuflist(l:i)
        if len(l:buflist) == 1 && bufname(l:buflist[0]) ==# ''
            call add(l:doubles, l:i)
            continue
        endif
        let l:idx = index(l:all_buffers, l:buflist)
        if l:idx == -1
            call add(l:all_buffers, l:buflist)
            call add(l:all_tabs, l:i)
        else
            call add(l:doubles, (l:i == l:t) ? l:all_tabs[l:idx] : l:i)
        endif
    endfor
    for l:tc in reverse(l:doubles)
        exe l:tc.'tabclose'
    endfor
endfu

func! s:CloseBuffers(expr, ...)
    let l:op = get(a:000, 0, 'bd')
    let l:t = tabpagenr()
    for l:i in range(1, bufnr('$'))
        if bufexists(l:i) && buflisted(l:i)
            if eval(a:expr)
                exe l:i.l:op
            endif
        endif
    endfor
endfu

func! s:MarkTabToClose(min, max, patterns)
    let l:to_close=0
    let l:nr=tabpagenr()
    if ((l:nr < a:max) && (l:nr > a:min))
        if len(a:patterns) > 0
            for l:pat in a:patterns
                if bufname() =~ l:pat
                    let t:tab_to_close = 1
                    break
                endif
            endfor
        else
            let t:tab_to_close=1
        endif
    endif
endfu

func! s:SortTabs(...)
    let l:curbuf = bufnr()
    let l:cache_buf = {}
    for l:i in range(tabpagenr('$'),1,-1)
        let l:i1 = bufnr()
        if ! has_key(l:cache_buf, l:i1)
            let l:cache_buf[l:i1] = join(map(copy(a:000), 'expand(v:val)'), ',')
        endif
        tabnext
    endfor
    for l:i in range(tabpagenr('$'),1,-1)
        tabfirst
        for l:j in range(1,l:i-1)
            let l:t1 = l:cache_buf[bufnr()]
            tabnext
            let l:t2 = l:cache_buf[bufnr()]
            if l:t1 > l:t2
                tabprevious
                exec ":tabmove ".l:j
                redrawtabline
            endif
        endfor
    endfor
    exe 'GoToBuffer '.l:curbuf
endfun
