" cleantab.vim -- Vim lib which add Clean command in order to clean unordered tabline
" @Author:      luffah (luffah AT runbox com)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2026-05-17
" @Last Change: 2026-06-30
" @Revision:    1


"@global g:cleantab_sort_grouping_variables
"(list of dict) Buffer variables to use when sorting tabs
"[ {'name': <varname>, 'type': <'buffer'(default) or 'tab'>,
"   'default': <default_value> (default: 0), 'expected': <expected_value>',
"   'position': <'before'(default) or 'after'> } ]
"default is : [{'name':'use', 'expected': 1}]
"meaning if `let b:use = 1` is defined on a buffer then put it before other
"tabs grouping with other buffers having b:use = 1
"If many groups apply then the last take priority.
let g:cleantab_sort_grouping_variables = get(g:,'cleantab_sort_grouping_variables',
            \ [{'name':'use', 'expected': 1}]
            \)

"@command Clean <opts> <patterns>
"Clean tabs (and then tabline)..
"   Options are in shell style:
"    -h help
"    <X  >X  to target tabs between strict min and max
"    ! to invert patterns (close all except current if no pattern)
"    -b close buffers matching patterns
"    -e close unammed buffers
"    -E close empty buffers
"    -H wipeout hidden buffers
"    -u wipeout unlisted buffers
"    -t close tabs matching patterns [default if no other option]
"    -d close double tabs [default if no other option]
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
        unsilent echo " ! to invert the patterns"
        unsilent echo " -b close buffers matching patterns"
        unsilent echo " -e close unammed buffers"
        unsilent echo " -E close empty buffers"
        unsilent echo " -H wipeout hidden buffers"
        unsilent echo " -u wipeout unlisted buffers"
        unsilent echo " -t close tabs matching patterns [default if no other option]"
        unsilent echo " -d close double tabs [default if no other option]"
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

    let l:tests_to_close = []
    let l:invert=0
    for l:a in l:args
        if l:a == '!'
            let l:invert = 1
            if len(l:args) == 1
                call add(l:tests_to_close, 'l:i != ' . bufnr())
            endif
            continue
        endif
        call add(l:tests_to_close, 'bufname(l:i) '.( l:invert ? '!' : '=' ).'~ "'.escape(l:a, '"').'"')
    endfor
    if l:nopat
        if (l:tabcloseall || (l:tabclose && l:idx_focus))
           call s:MarkTabToClose(l:min_idx, l:max_idx, [])
        endif
    else
        if l:rmbuff
            call s:CloseBuffers(l:tests_to_close)
        endif
        if l:tabclose
           call s:MarkTabToClose(l:min_idx, l:max_idx, l:tests_to_close)
        endif
    endif

    for l:nr in range(tabpagenr('$'),1,-1)
        if gettabvar(l:nr, 'tab_to_close', 0)
            exe l:nr.'tabclose'
        endif
    endfor

    if l:closeunammedbuffers
        call s:CloseBuffers(["bufname(l:i) =~ '^$'"])
    endif

    if l:closeemptybuffers
        call s:CloseBuffers(["(empty(getbufinfo(l:i)) || (getbufinfo(l:i)[0]['lnum'] == 1 && getbufline(l:i,'$') == ['']))"])
    endif

    if l:wipeouthiddenbuffers
        call s:CloseBuffers(["(!empty(getbufinfo(l:i)) && (getbufinfo(l:i)[0]['hidden'] == 1))"], 'bwipeout')
    endif

    if l:wipeoutunlistedbuffers
        call s:CloseBuffers(["(!empty(getbufinfo(l:i)) && (getbufinfo(l:i)[0]['listed'] == 0))"], 'bwipeout')
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

func! s:CloseBuffers(tests, ...)
    let l:op = get(a:000, 0, 'bd')
    for l:i in range(1, bufnr('$'))
        if bufexists(l:i) && buflisted(l:i)
            for l:test in a:tests
                if eval(l:test)
                    exe l:i.l:op
                endif
            endfor
        endif
    endfor
endfu

func! s:MarkTabToClose(min, max, tests)
    let l:to_close=0
    for l:nr in range(1, tabpagenr('$'))
        let l:ok = 1
        for l:i in tabpagebuflist(l:nr)
            if ((l:nr < a:max) && (l:nr > a:min))
                let l:any = 0
                for l:test in a:tests
                    if eval(l:test)
                        let l:any = 1
                        break
                    endif
                endfor
            else
                let l:any = 1
            endif
            if ! l:any
                let l:ok = 0
                break
            endif
        endfor
        if l:ok
            call settabvar(l:nr, 'tab_to_close', 1)
        endif
    endfor
endfu

func! s:sortTabsExpandName(mods)
    let l:res = []
    for l:m in a:mods
        let l:part = expand(l:m)
        if l:m == '%:t'
            if l:part =~ '^\d\+\(\.[a-z]\{1,4\}\)\?$'
                let l:path = expand('%:p')
                if l:path =~ '/.*/'
                    let l:part = split(l:path, '/')[-2] .'/'. l:part
                endif
            endif
        endif
        call add(l:res, l:part)
    endfor
    return l:res
endfu

func! s:SortTabs(...)
    let l:curbuf = bufnr()
    let l:curwin = win_getid()
    let l:cache_buf = {}
    1tabnext
    for l:i in range(1, tabpagenr('$'))
        let l:i1 = bufnr()
        if ! has_key(l:cache_buf, l:i1)
            let l:cache_buf[l:i1] = join(s:sortTabsExpandName(a:000), '!')
            for l:var in g:cleantab_sort_grouping_variables
                if get(l:var, 'position', 'before') == 'after'
                    let l:group_char = nr2char(0xffff)
                else
                    let l:group_char = nr2char(0x0001)
                endif
                if get(get(l:var, 'type', 'buffer') == 'tab' ? t: : b:, l:var['name'], get(l:var, 'default', 0)) == l:var['expected']
                    let l:cache_buf[l:i1] = l:group_char.l:var['name'].'!'.l:cache_buf[l:i1]
                endif
            endfor
        endif
        tabnext
    endfor
    for l:i in range(tabpagenr('$'),1,-1)
        tabfirst
        for l:j in range(1,l:i)
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
    call win_gotoid(l:curwin)
endfun
