
" https://stackoverflow.com/questions/26315925/get-usable-window-width-in-vim-script
function! s:GetWindowWidth() abort
    redir =>l:a |exe "sil sign place buffer=".bufnr('')|redir end
    let l:signlist=split(l:a, '\n')
    return winwidth(0) - &numberwidth - &foldcolumn - (len(signlist) > 2 ? 2 : 0)
endfun

" Get the value of a buffer variable, or a global variable if the buffer
" variable is missing.
function! s:Get(name) abort
    return get(b:, a:name, get(g:, a:name))
endfun

" Upload the given image with the given size. If `cols` and `rows` are zero, the
" best size will be computed automatically.
" The result of this function is a list of lines with text properties
" representing the image (can be used with popup_create and popup_settext).
function! terminal_images#UploadTerminalImage(filename, params) abort
    let cols = get(a:params, 'cols', 0)
    let rows = get(a:params, 'rows', 0)
    let flags = get(a:params, 'flags', '')
    " If the number of columns and rows is not provided, the script will compute
    " them automatically. We just need to limit the number of columns and rows
    " so that the image fits in the window.
    let maxcols = s:Get('terminal_images_max_columns')
    let maxrows = s:Get('terminal_images_max_rows')
    let maxcols = min([maxcols, &columns, s:GetWindowWidth() - 2])
    let maxrows = min([maxrows, &lines, winheight(0) - 2])
    let maxcols = max([1, maxcols])
    let maxrows = max([1, maxrows])
    let maxcols_str = cols ? "" : " --max-cols " . string(maxcols)
    let maxrows_str = rows ? "" : " --max-rows " . string(maxrows)
    let cols_str = cols ? " -c " . shellescape(string(cols)) : ""
    let rows_str = rows ? " -r " . shellescape(string(rows)) : ""
    let filename_expanded = resolve(expand(a:filename))
    let filename_str = shellescape(filename_expanded)
    let outfile = tempname()
    let errfile = tempname()
    let infofile = tempname()

    " We use tupimage to upload the file. We ask it to write lines
    " representing the image to `outfile` and disable outputting escape codes
    " for the image id (--noesc) because we assign them by ourselves using text
    " properties.
    let command = g:terminal_images_command .
                \ cols_str .
                \ rows_str .
                \ maxcols_str .
                \ maxrows_str .
                \ " -e " . shellescape(errfile) .
                \ " -o " . shellescape(outfile) .
                \ " --save-info " . shellescape(infofile) .
                \ " --noesc " .
                \ " --256 " .
                \ flags .
                \ " " . filename_str
    call system(command)
    if v:shell_error != 0
        if filereadable(errfile)
            let err_message = readfile(errfile)[0]
            call delete(errfile)
            throw "Uploading error: " . err_message
        endif
        throw "Command failed: " . command
    endif

    " Get image id from infofile.
    let id = ''
    for infoline in readfile(infofile)
        " The line we want looks something like "id 1234"
        let id = matchstr(infoline, '^id[ \t]\+\zs[0-9]\+\ze$')
        if id != ''
            break
        endif
    endfor
    if id == ''
        throw "Could not read id from " . infofile
    endif
    call delete(infofile)

    " Read outfile and convert it to something suitable for floating windows.
    let lines = readfile(outfile)
    let result = []
    " We use text properties to assign each line the foreground color
    " corresponding to the image id.
    let prop_type = "TerminalImagesID" . id
    for line in lines
        call add(result,
                 \ {'text': line,
                 \  'props': [{'col': 1,
                 \             'length': len(line),
                 \             'type': prop_type}]})
    endfor
    call delete(outfile)
    return result
endfun

" Find a readable file named `filename` in some plausible directories. Throw an
" exception if a file could not be found.
function! terminal_images#FindReadableFile(filename) abort
    " Try the current directory and the directory of the current file.
    let filenames = [a:filename, expand('%:p:h') . "/" . a:filename]
    " Try the current netrw directory.
    if exists('b:netrw_curdir')
        call add(filenames, b:netrw_curdir . "/" . a:filename)
    endif
    for filename in filenames
        if filereadable(filename)
            return filename
        endif
    endfor

    " In subdirectories of the directory of the current file (descend one level
    " by default).
    let globpattern = expand('%:p:h') .
                \ "/" . s:Get('terminal_images_subdir_glob') . "/" . a:filename
    let globlist = glob(globpattern, 0, 1)
    for filename in globlist
        if filereadable(filename)
            return filename
        endif
    endfor

    throw "File(s) not readable: " . string(filenames)
endfun

" Show the image under cursor in a pop-up window.
function! terminal_images#ShowImageUnderCursor(...) abort
    let silent = get(a:, 0, 0)
    try
        let filename = terminal_images#FindReadableFile(expand('<cfile>'))
    catch
        if !silent
            echohl ErrorMsg
            echo v:exception
            echohl None
        endif
        return 0
    endtry
    if !filereadable(filename)
        return
    endif
    if !silent
        let uploading_message =
                    \ popup_atcursor("Uploading " . filename, {'zindex': 1010})
    endif
    redraw
    echo "Uploading " . filename
    try
        let text = terminal_images#UploadTerminalImage(filename, {})
        redraw
        echo "Showing " . filename
    catch
        if !silent
            call popup_close(uploading_message)
        endif
        " Vim doesn't want to redraw unless I put echo in between
        redraw!
        echo
        redraw!
        echohl ErrorMsg
        echo v:exception
        echohl None
        return
    endtry
    if !silent
        call popup_close(uploading_message)
    endif
    let background_higroup =
                \ get(b:, 'terminal_images_background', 'TerminalImagesBackground')
    return popup_atcursor(text,
                \ #{wrap: 0, highlight: background_higroup, zindex: 1000})
endfun

function! s:FindBestPosition(win_width, line_widths, line, cols, rows) abort
    let best_column = a:win_width
    let best_offset = 0
    let best_rows = 0
    let best_cols = 0
    for offset in range(-a:rows, a:rows)
        if a:line + offset < 0
            continue
        endif
        if a:line + offset >= len(a:line_widths)
            break
        endif
        if offset > 0 && a:line_widths[a:line + offset] >= a:win_width
            break
        endif
        let column = 0
        for row in range(a:rows)
            if a:line + offset + row >= len(a:line_widths)
                break
            endif
            let column = max([column, a:line_widths[a:line + offset + row]])
            if column >= a:win_width
                break
            endif
            let available_width = a:win_width - column
            let newcols = min([available_width, a:cols])
            let newrows = max([1, a:rows * newcols / a:cols])
            if newrows > row + 1
                let newrowsold = newrows
                let newrows = row + 1
                let newcols = max([1, newcols * newrows / newrowsold])
            endif
            if newrows > best_rows || newcols > best_cols ||
                        \ (newrows == best_rows && newcols == best_cols &&
                        \  column + abs(offset + a:rows/2)*3 < best_column + abs(best_offset + a:rows/2)*3)
                let best_rows = newrows
                let best_cols = newcols
                let best_offset = offset
                let best_column = column
            endif
        endfor
    endfor

    let best_line = a:line + best_offset

    if best_column >= a:win_width || best_rows <= 0 || best_cols <= 0
        return []
    endif

    return [best_line, best_column, best_cols, best_rows]
endfun

function! s:GetCacheRecord(filename) abort
    let time = getftime(a:filename)
    if has_key(g:terminal_images_cache, a:filename)
        let dict = g:terminal_images_cache[a:filename]
        if time == dict.time
            return dict
        endif
    endif
    let g:terminal_images_cache[a:filename] = {'time': time}
    return g:terminal_images_cache[a:filename]
endfun

function! terminal_images#UploadPendingImages(params) abort
    let reupload = get(a:params, 'reupload', 0)
    let flags = ""
    if reupload
        let flags = " --force-upload "
    else
        let flags = " --one-way "
    endif

    let uploading_message =
                \ popup_atcursor("Uploading images", {'zindex': 1010})

    while len(g:terminal_images_pending_uploads) > 0
        let upload = remove(g:terminal_images_pending_uploads,
                    \ len(g:terminal_images_pending_uploads) - 1)
        let popup_id = upload[0]
        let filename = upload[1]
        let cols = upload[2]
        let rows = upload[3]

        let cache_record = s:GetCacheRecord(filename)

        if has_key(cache_record, 'text') && cache_record.cols == cols && cache_record.rows == rows
            let text = cache_record.text
        else
            echom "Uploading " . filename " (" . cols . "x" . rows . ")"
            call popup_settext(uploading_message, "Uploading " . filename)
            redraw
            let text = ["failed", filename]
            try
                let pos = popup_getpos(popup_id)
                let abs_pos_flags =
                            \ " -x " . pos.core_col . " -y " . pos.core_line .
                            \ " --max-terminal-cols " . pos.core_width . " "
                let text = terminal_images#UploadTerminalImage(filename,
                            \{'cols': cols, 'rows': rows,
                            \ 'flags': flags . abs_pos_flags})
                let cache_record.cols = cols
                let cache_record.rows = rows
                let cache_record.text = text
            catch
                let text = [v:exception]
            endtry
        endif
        call popup_settext(popup_id, text)
        redraw
    endwhile
    call popup_close(uploading_message)
endfun

function! terminal_images#ShowAllImages(params) abort
    let win_width = s:GetWindowWidth()
    let maxcols = s:Get('terminal_images_max_columns')
    let maxrows = s:Get('terminal_images_max_rows')
    let maxcols = min([maxcols, &columns, win_width - 2])
    let maxrows = min([maxrows, &lines, winheight(0) - 2])
    let maxcols = max([1, maxcols])
    let maxrows = max([1, maxrows])

    let match_list = []
    let line_widths = []

    for line in range(line('w0'), line('w$'))
        if line < 1
            continue
        endif
        let line_str = getline(line)
        call add(line_widths, strdisplaywidth(line_str))

        if len(match_list) >= 32
            continue
        endif

        let matches = []
        call substitute(line_str, s:Get('terminal_images_regex'), '\=add(matches, submatch(1))', 'g')
        for m in matches
            call add(match_list, [line, m])
        endfor
    endfor

    let prev_window_width = get(w:, 'terminal_images_prev_window_width', 0)
    let prev_line_widths = get(w:, 'terminal_images_prev_line_widths', [])
    let prev_match_list = get(w:, 'terminal_images_prev_match_list', [])
    let prev_finished = get(w:, 'terminal_images_prev_finished', 0)

    let differ = 0
    if !prev_finished || prev_window_width != win_width ||
                \ len(prev_line_widths) != len(line_widths) ||
                \ len(prev_match_list) != len(match_list)
        let differ = 1
    else
        for i in range(len(line_widths))
            if line_widths[i] != prev_line_widths[i]
                let differ = 1
                break
            endif
        endfor
        for i in range(len(match_list))
            if match_list[i][0] != match_list[i][0] || match_list[i][1] != match_list[i][1]
                let differ = 1
                break
            endif
        endfor
    endif

    if !differ
        let w:terminal_images_prev_finished = 1
        call terminal_images#UploadPendingImages(a:params)
        return
    endif

    call terminal_images#ClearVisibleImages()

    let w:terminal_images_prev_window_width = win_width
    let w:terminal_images_prev_line_widths = copy(line_widths)
    let w:terminal_images_prev_match_list = match_list
    let w:terminal_images_prev_finished = 0

    let file_list = []
    for mtch in match_list
        if len(file_list) >= 16
            break
        endif
        let line = mtch[0]
        let file = mtch[1]
        try
            let filename = terminal_images#FindReadableFile(file)
        catch
            continue
        endtry
        call add(file_list, [line, filename])
    endfor

    let prop_type_name = 'TerminalImageMarker_' . string(win_getid()) . '_' . string(bufnr())
    if empty(prop_type_get(prop_type_name))
        call prop_type_add(prop_type_name, {})
    endif

    for line_and_file in file_list
        let line = line_and_file[0]
        let filename = line_and_file[1]

        let cache_record = s:GetCacheRecord(filename)

        if has_key(cache_record, 'max_rows') && cache_record.max_rows == maxrows && cache_record.max_cols == maxcols
            let dims = [cache_record.optimal_cols, cache_record.optimal_rows]
        else
            let filename_esc = shellescape(filename)
            let command = g:terminal_images_command .
                        \ " --max-cols " . string(maxcols) .
                        \ " --max-rows " . string(maxrows) .
                        \ " --quiet " .
                        \ " -e /dev/null " .
                        \ " --only-dump-dims " .
                        \ filename_esc
            let dims = split(system(command), " ")
            if v:shell_error != 0 || len(dims) != 2
                continue
            endif
            let cache_record.max_rows = maxrows
            let cache_record.max_cols = maxcols
            if !has_key(cache_record, 'optimal_cols') || cache_record.optimal_cols != dims[0] || cache_record.optimal_rows != dims[1]
                let cache_record.optimal_cols = dims[0]
                let cache_record.optimal_rows = dims[1]
            endif
        endif

        let cols = str2nr(dims[0])
        let rows = str2nr(dims[1])
        let best_pos = s:FindBestPosition(win_width - 1, line_widths, line - line('w0'), cols, rows)
        if len(best_pos) == 0
            continue
        endif
        let best_line = best_pos[0]
        let best_column = best_pos[1]
        let best_cols = best_pos[2]
        let best_rows = best_pos[3]
        if best_cols < 5 || best_rows < 3
            if best_cols*2 < cols || best_rows*2 < rows
                continue
            endif
        endif
        for line_idx in range(best_rows)
            if best_pos[0] + line_idx >= len(line_widths)
                break
            endif
            let line_widths[best_pos[0] + line_idx] = best_column + best_cols
        endfor
        let b:terminal_images_propid_count =
            \ get(b:, 'terminal_images_propid_count', 0) + 1
        let propid = b:terminal_images_propid_count
        call prop_add(line, 1, #{length: len(getline(line)), type: prop_type_name, id: propid})
        let background_higroup =
            \ get(b:, 'terminal_images_background', 'TerminalImagesBackground')
        let popup_id = popup_create([filename, string(best_pos)],
                    \ #{line: best_line + line('w0') - line - 1,
                    \   col: best_column - strdisplaywidth(getline(line)),
                    \   pos: 'topleft',
                    \   close: 'click',
                    \   fixed: 1,
                    \   flip: 0,
                    \   wrap: 1,
                    \   highlight: background_higroup,
                    \   textprop: prop_type_name,
                    \   textpropid: propid,
                    \   minheight: best_rows, minwidth: best_cols,
                    \   maxheight: best_rows, maxwidth: best_cols})
        call add(g:terminal_images_pending_uploads, [popup_id, filename, best_cols, best_rows])
    endfor

    let w:terminal_images_prev_finished = 1

    call terminal_images#UploadPendingImages(a:params)
endfun

function! terminal_images#ShowAllImagesForceReupload() abort
    let g:terminal_images_cache = {}
    let g:terminal_images_pending_uploads = []
    let w:terminal_images_prev_line_widths = []
    let w:terminal_images_prev_match_list = []
    call terminal_images#ShowAllImages({'reupload': 1})
endfun

function! terminal_images#ClearVisibleImages() abort
    let w:terminal_images_prev_line_widths = []
    let w:terminal_images_prev_match_list = []
    let prop_type_name = 'TerminalImageMarker_' . string(win_getid()) . '_' . string(bufnr())
    if !empty(prop_type_get(prop_type_name))
        call prop_remove(#{type: prop_type_name, all: 1}, line('w0'), line('w$'))
    endif
endfun


function! terminal_images#CloseObscuringImages() abort
    let w:terminal_images_prev_line_widths = []
    let w:terminal_images_prev_match_list = []
    let prop_type_name = 'TerminalImageMarker_' . string(win_getid()) . '_' . string(bufnr())
    for popup_id in popup_list()
        let pos = popup_getpos(popup_id)
        if empty(pos) || !pos.visible
            continue
        endif
        let opts = popup_getoptions(popup_id)
        if !has_key(opts, 'textprop') || opts.textprop != prop_type_name
            continue
        endif
        let winpos = win_screenpos(0)
        if pos.col >= winpos[1] + winwidth(0) || pos.line >= winpos[0] + winheight(0)
                    \ || pos.col < winpos[1] || pos.line < winpos[0]
            call popup_close(popup_id)
        else
            let maxwidth = winpos[1] + winwidth(0) - pos.col
            let maxheight = winpos[0] + winheight(0) - pos.line
            if pos.height > maxheight || pos.width > maxwidth
                let pos.width = min([maxwidth, pos.width])
                let pos.height = min([maxheight, pos.height])
                call popup_move(popup_id, #{minheight: pos.height, maxheight: pos.height, minwidth: pos.width, maxwidth: pos.width})
                call popup_setoptions(popup_id, #{wrap: 0})
            endif
        endif
    endfor
endfun

function! terminal_images#ShowAllMaybe() abort
    if g:terminal_images_auto
        call terminal_images#ShowAllImages({})
    endif
endfun

function! terminal_images#CloseObscuringMaybe() abort
    if g:terminal_images_auto
        call terminal_images#CloseObscuringImages()
    endif
endfun

function! terminal_images#EnableGlobal() abort
    let g:terminal_images_auto = 1
    call terminal_images#ShowAllImages({})
    echom "Automatic image display is on"
endfun

function! terminal_images#DisableGlobal() abort
    let g:terminal_images_auto = 0
    call terminal_images#ClearVisibleImages()
    echom "Automatic image display is off"
endfun

function! terminal_images#ToggleGlobal() abort
    if g:terminal_images_auto
        call terminal_images#DisableGlobal()
    else
        call terminal_images#EnableGlobal()
    endif
endfun
