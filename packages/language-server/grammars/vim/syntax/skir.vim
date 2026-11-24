" Vim syntax file for Skir
" Language:    Skir (https://skir.build)
" Maintainer:  Tyler Fibonacci

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword skirKeyword struct enum const method import from as removed

" Built-in types
syn keyword skirType bool int32 int64 hash64 float32 float64 string bytes timestamp

" Language constants
syn keyword skirConstant true false null

" Line comments
syn match skirComment "//.*$" contains=@Spell
" Block comments
syn region skirBlockComment start="/\*" end="\*/" contains=@Spell

" Strings
syn region skirString start='"' end='"' contains=skirEscape
syn region skirString start="'" end="'" contains=skirEscape
syn match skirEscape '\\.' contained

" Numbers
syn match skirNumber '\b-\?\d\+\(\.\d\+\)\?\([eE][+-]\?\d\+\)\?\b'

" ALL_CAPS identifiers are constants; CamelCase are types
" skirTypeName must be defined first so skirUpperConst (defined last) wins for ALL_CAPS
syn match skirTypeName   '\b[A-Z][A-Za-z0-9_]*\b'
syn match skirUpperConst '\b[A-Z][A-Z0-9_]*\b'

" Highlighting links
hi def link skirKeyword      Keyword
hi def link skirType         Type
hi def link skirConstant     Constant
hi def link skirComment      Comment
hi def link skirBlockComment Comment
hi def link skirString       String
hi def link skirEscape       SpecialChar
hi def link skirNumber       Number
hi def link skirTypeName     Type
hi def link skirUpperConst   Constant

let b:current_syntax = "skir"
