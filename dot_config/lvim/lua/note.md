# Plugins keymap

## surround.vim

It's easiest to explain with examples. Press `cs"'` inside

    "Hello world!"

to change it to

    'Hello world!'

Now press `cs'<q>` to change it to

    <q>Hello world!</q>

To go full circle, press `cst"` to get

    "Hello world!"

To remove the delimiters entirely, press `ds"`.

    Hello world!

Finally, let's try out visual mode. Press a capital V (for linewise visual mode) followed by S<p class="important">.

```html
<p class="important"><em>Hello</em> world!</p>
```

    ---

## Yoink.vim #TODO map this

Commands
`:Yanks` -- Display the current yank history

`:ClearYanks` -- Delete history. This will reduce the history down to 1 entry taken from the default register.

```lua
nmap <c-n> <plug>(YoinkPostPasteSwapBack)
nmap <c-p> <plug>(YoinkPostPasteSwapForward)

nmap p <plug>(YoinkPaste_p)
nmap P <plug>(YoinkPaste_P)

" Also replace the default gp with yoink paste so we can toggle paste in this case too
nmap gp <plug>(YoinkPaste_gp)
nmap gP <plug>(YoinkPaste_gP)
```

---

## Subversive.vim #TODO map this

```lua
" s for substitute
nmap s <plug>(SubversiveSubstitute)
nmap ss <plug>(SubversiveSubstituteLine)
nmap S <plug>(SubversiveSubstituteToEndOfLine)

nmap <leader>s <plug>(SubversiveSubstituteRange)
xmap <leader>s <plug>(SubversiveSubstituteRange)
nmap <leader>ss <plug>(SubversiveSubstituteWordRange)
```
