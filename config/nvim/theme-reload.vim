" Reload common highlight groups from the current pywal palette.
if !exists('g:background') || !exists('g:foreground')
  finish
endif

execute 'highlight Normal guibg=' . g:background . ' guifg=' . g:foreground
execute 'highlight NormalNC guibg=' . g:background . ' guifg=' . g:foreground
execute 'highlight Comment guifg=' . g:color8
execute 'highlight Constant guifg=' . g:color3
execute 'highlight String guifg=' . g:color2
execute 'highlight Identifier guifg=' . g:color4
execute 'highlight Function guifg=' . g:color4 . ' gui=bold'
execute 'highlight Statement guifg=' . g:color5
execute 'highlight Type guifg=' . g:color6
execute 'highlight Special guifg=' . g:color1
execute 'highlight LineNr guifg=' . g:color8
execute 'highlight CursorLine guibg=' . g:color0
execute 'highlight CursorLineNr guifg=' . g:color3 . ' gui=bold'
execute 'highlight Visual guibg=' . g:color8
execute 'highlight Search guibg=' . g:color4 . ' guifg=' . g:background
execute 'highlight Pmenu guibg=' . g:color0 . ' guifg=' . g:foreground
execute 'highlight PmenuSel guibg=' . g:color4 . ' guifg=' . g:background
execute 'highlight StatusLine guibg=' . g:color0 . ' guifg=' . g:foreground . ' gui=bold'
execute 'highlight StatusLineNC guibg=' . g:color0 . ' guifg=' . g:color8
