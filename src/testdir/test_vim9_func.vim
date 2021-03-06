" Test various aspects of the Vim9 script language.

source check.vim
source term_util.vim
source view_util.vim
source vim9.vim
source screendump.vim

func Test_def_basic()
  def SomeFunc(): string
    return 'yes'
  enddef
  call assert_equal('yes', SomeFunc())
endfunc

def ReturnString(): string
  return 'string'
enddef

def ReturnNumber(): number
  return 123
enddef

let g:notNumber = 'string'

def ReturnGlobal(): number
  return g:notNumber
enddef

def Test_return_something()
  assert_equal('string', ReturnString())
  assert_equal(123, ReturnNumber())
  assert_fails('ReturnGlobal()', 'E1029: Expected number but got string', '', 1, 'ReturnGlobal')
enddef

def Test_missing_return()
  CheckDefFailure(['def Missing(): number',
                   '  if g:cond',
                   '    echo "no return"',
                   '  else',
                   '    return 0',
                   '  endif'
                   'enddef'], 'E1027:')
  CheckDefFailure(['def Missing(): number',
                   '  if g:cond',
                   '    return 1',
                   '  else',
                   '    echo "no return"',
                   '  endif'
                   'enddef'], 'E1027:')
  CheckDefFailure(['def Missing(): number',
                   '  if g:cond',
                   '    return 1',
                   '  else',
                   '    return 2',
                   '  endif'
                   '  return 3'
                   'enddef'], 'E1095:')
enddef

let s:nothing = 0
def ReturnNothing()
  s:nothing = 1
  if true
    return
  endif
  s:nothing = 2
enddef

def Test_return_nothing()
  ReturnNothing()
  assert_equal(1, s:nothing)
enddef

func Increment()
  let g:counter += 1
endfunc

def Test_call_ufunc_count()
  g:counter = 1
  Increment()
  Increment()
  Increment()
  # works with and without :call
  assert_equal(4, g:counter)
  call assert_equal(4, g:counter)
  unlet g:counter
enddef

def MyVarargs(arg: string, ...rest: list<string>): string
  let res = arg
  for s in rest
    res ..= ',' .. s
  endfor
  return res
enddef

def Test_call_varargs()
  assert_equal('one', MyVarargs('one'))
  assert_equal('one,two', MyVarargs('one', 'two'))
  assert_equal('one,two,three', MyVarargs('one', 'two', 'three'))
enddef

def MyDefaultArgs(name = 'string'): string
  return name
enddef

def MyDefaultSecond(name: string, second: bool  = true): string
  return second ? name : 'none'
enddef

def Test_call_default_args()
  assert_equal('string', MyDefaultArgs())
  assert_equal('one', MyDefaultArgs('one'))
  assert_fails('MyDefaultArgs("one", "two")', 'E118:', '', 3, 'Test_call_default_args')

  assert_equal('test', MyDefaultSecond('test'))
  assert_equal('test', MyDefaultSecond('test', true))
  assert_equal('none', MyDefaultSecond('test', false))

  CheckScriptFailure(['def Func(arg: number = asdf)', 'enddef', 'defcompile'], 'E1001:')
  CheckScriptFailure(['def Func(arg: number = "text")', 'enddef', 'defcompile'], 'E1013: argument 1: type mismatch, expected number but got string')
enddef

def Test_nested_function()
  def Nested(arg: string): string
    return 'nested ' .. arg
  enddef
  assert_equal('nested function', Nested('function'))

  CheckDefFailure(['def Nested()', 'enddef', 'Nested(66)'], 'E118:')
  CheckDefFailure(['def Nested(arg: string)', 'enddef', 'Nested()'], 'E119:')

  CheckDefFailure(['func Nested()', 'endfunc'], 'E1086:')
  CheckDefFailure(['def s:Nested()', 'enddef'], 'E1075:')
  CheckDefFailure(['def b:Nested()', 'enddef'], 'E1075:')
enddef

func Test_call_default_args_from_func()
  call assert_equal('string', MyDefaultArgs())
  call assert_equal('one', MyDefaultArgs('one'))
  call assert_fails('call MyDefaultArgs("one", "two")', 'E118:', '', 3, 'Test_call_default_args_from_func')
endfunc

def Test_nested_global_function()
  let lines =<< trim END
      vim9script
      def Outer()
          def g:Inner(): string
              return 'inner'
          enddef
      enddef
      defcompile
      Outer()
      assert_equal('inner', g:Inner())
      delfunc g:Inner
      Outer()
      assert_equal('inner', g:Inner())
      delfunc g:Inner
      Outer()
      assert_equal('inner', g:Inner())
      delfunc g:Inner
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      def Outer()
          def g:Inner(): string
              return 'inner'
          enddef
      enddef
      defcompile
      Outer()
      Outer()
  END
  CheckScriptFailure(lines, "E122:")

  lines =<< trim END
      vim9script
      def Func()
        echo 'script'
      enddef
      def Outer()
        def Func()
          echo 'inner'
        enddef
      enddef
      defcompile
  END
  CheckScriptFailure(lines, "E1073:")
enddef

def Test_global_local_function()
  let lines =<< trim END
      vim9script
      def g:Func(): string
          return 'global'
      enddef
      def Func(): string
          return 'local'
      enddef
      assert_equal('global', g:Func())
      assert_equal('local', Func())
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      def g:Funcy()
        echo 'funcy'
      enddef
      s:Funcy()
  END
  CheckScriptFailure(lines, 'E117:')
enddef

func TakesOneArg(arg)
  echo a:arg
endfunc

def Test_call_wrong_args()
  CheckDefFailure(['TakesOneArg()'], 'E119:')
  CheckDefFailure(['TakesOneArg(11, 22)'], 'E118:')
  CheckDefFailure(['bufnr(xxx)'], 'E1001:')
  CheckScriptFailure(['def Func(Ref: func(s: string))'], 'E475:')

  let lines =<< trim END
    vim9script
    def Func(s: string)
      echo s
    enddef
    Func([])
  END
  call CheckScriptFailure(lines, 'E1013: argument 1: type mismatch, expected string but got list<unknown>', 5)
enddef

" Default arg and varargs
def MyDefVarargs(one: string, two = 'foo', ...rest: list<string>): string
  let res = one .. ',' .. two
  for s in rest
    res ..= ',' .. s
  endfor
  return res
enddef

def Test_call_def_varargs()
  assert_fails('MyDefVarargs()', 'E119:', '', 1, 'Test_call_def_varargs')
  assert_equal('one,foo', MyDefVarargs('one'))
  assert_equal('one,two', MyDefVarargs('one', 'two'))
  assert_equal('one,two,three', MyDefVarargs('one', 'two', 'three'))
  CheckDefFailure(['MyDefVarargs("one", 22)'],
      'E1013: argument 2: type mismatch, expected string but got number')
  CheckDefFailure(['MyDefVarargs("one", "two", 123)'],
      'E1013: argument 3: type mismatch, expected string but got number')

  let lines =<< trim END
      vim9script
      def Func(...l: list<string>)
        echo l
      enddef
      Func('a', 'b', 'c')
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      def Func(...l: list<string>)
        echo l
      enddef
      Func()
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
      vim9script
      def Func(...l: list<string>)
        echo l
      enddef
      Func(1, 2, 3)
  END
  CheckScriptFailure(lines, 'E1013: argument 1: type mismatch')

  lines =<< trim END
      vim9script
      def Func(...l: list<string>)
        echo l
      enddef
      Func('a', 9)
  END
  CheckScriptFailure(lines, 'E1013: argument 2: type mismatch')

  lines =<< trim END
      vim9script
      def Func(...l: list<string>)
        echo l
      enddef
      Func(1, 'a')
  END
  CheckScriptFailure(lines, 'E1013: argument 1: type mismatch')
enddef

def Test_call_call()
  let l = [3, 2, 1]
  call('reverse', [l])
  assert_equal([1, 2, 3], l)
enddef

let s:value = ''

def FuncOneDefArg(opt = 'text')
  s:value = opt
enddef

def FuncTwoDefArg(nr = 123, opt = 'text'): string
  return nr .. opt
enddef

def FuncVarargs(...arg: list<string>): string
  return join(arg, ',')
enddef

def Test_func_type_varargs()
  let RefDefArg: func(?string)
  RefDefArg = FuncOneDefArg
  RefDefArg()
  assert_equal('text', s:value)
  RefDefArg('some')
  assert_equal('some', s:value)

  let RefDef2Arg: func(?number, ?string): string
  RefDef2Arg = FuncTwoDefArg
  assert_equal('123text', RefDef2Arg())
  assert_equal('99text', RefDef2Arg(99))
  assert_equal('77some', RefDef2Arg(77, 'some'))

  CheckDefFailure(['let RefWrong: func(string?)'], 'E1010:')
  CheckDefFailure(['let RefWrong: func(?string, string)'], 'E1007:')

  let RefVarargs: func(...list<string>): string
  RefVarargs = FuncVarargs
  assert_equal('', RefVarargs())
  assert_equal('one', RefVarargs('one'))
  assert_equal('one,two', RefVarargs('one', 'two'))

  CheckDefFailure(['let RefWrong: func(...list<string>, string)'], 'E110:')
  CheckDefFailure(['let RefWrong: func(...list<string>, ?string)'], 'E110:')
enddef

" Only varargs
def MyVarargsOnly(...args: list<string>): string
  return join(args, ',')
enddef

def Test_call_varargs_only()
  assert_equal('', MyVarargsOnly())
  assert_equal('one', MyVarargsOnly('one'))
  assert_equal('one,two', MyVarargsOnly('one', 'two'))
  CheckDefFailure(['MyVarargsOnly(1)'], 'E1013: argument 1: type mismatch, expected string but got number')
  CheckDefFailure(['MyVarargsOnly("one", 2)'], 'E1013: argument 2: type mismatch, expected string but got number')
enddef

def Test_using_var_as_arg()
  writefile(['def Func(x: number)',  'let x = 234', 'enddef', 'defcompile'], 'Xdef')
  assert_fails('so Xdef', 'E1006:', '', 1, 'Func')
  delete('Xdef')
enddef

def DictArg(arg: dict<string>)
  arg['key'] = 'value'
enddef

def ListArg(arg: list<string>)
  arg[0] = 'value'
enddef

def Test_assign_to_argument()
  # works for dict and list
  let d: dict<string> = {}
  DictArg(d)
  assert_equal('value', d['key'])
  let l: list<string> = []
  ListArg(l)
  assert_equal('value', l[0])

  CheckScriptFailure(['def Func(arg: number)', 'arg = 3', 'enddef', 'defcompile'], 'E1090:')
enddef

def Test_call_func_defined_later()
  assert_equal('one', g:DefinedLater('one'))
  assert_fails('NotDefined("one")', 'E117:', '', 2, 'Test_call_func_defined_later')
enddef

func DefinedLater(arg)
  return a:arg
endfunc

def Test_call_funcref()
  assert_equal(3, g:SomeFunc('abc'))
  assert_fails('NotAFunc()', 'E117:', '', 2, 'Test_call_funcref') # comment after call
  assert_fails('g:NotAFunc()', 'E117:', '', 3, 'Test_call_funcref')

  let lines =<< trim END
    vim9script
    def RetNumber(): number
      return 123
    enddef
    let Funcref: func: number = function('RetNumber')
    assert_equal(123, Funcref())
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
    vim9script
    def RetNumber(): number
      return 123
    enddef
    def Bar(F: func: number): number
      return F()
    enddef
    let Funcref = function('RetNumber')
    assert_equal(123, Bar(Funcref))
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
    vim9script
    def UseNumber(nr: number)
      echo nr
    enddef
    let Funcref: func(number) = function('UseNumber')
    Funcref(123)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
    vim9script
    def UseNumber(nr: number)
      echo nr
    enddef
    let Funcref: func(string) = function('UseNumber')
  END
  CheckScriptFailure(lines, 'E1012: type mismatch, expected func(string) but got func(number)')

  lines =<< trim END
    vim9script
    def EchoNr(nr = 34)
      g:echo = nr
    enddef
    let Funcref: func(?number) = function('EchoNr')
    Funcref()
    assert_equal(34, g:echo)
    Funcref(123)
    assert_equal(123, g:echo)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
    vim9script
    def EchoList(...l: list<number>)
      g:echo = l
    enddef
    let Funcref: func(...list<number>) = function('EchoList')
    Funcref()
    assert_equal([], g:echo)
    Funcref(1, 2, 3)
    assert_equal([1, 2, 3], g:echo)
  END
  CheckScriptSuccess(lines)

  lines =<< trim END
    vim9script
    def OptAndVar(nr: number, opt = 12, ...l: list<number>): number
      g:optarg = opt
      g:listarg = l
      return nr
    enddef
    let Funcref: func(number, ?number, ...list<number>): number = function('OptAndVar')
    assert_equal(10, Funcref(10))
    assert_equal(12, g:optarg)
    assert_equal([], g:listarg)

    assert_equal(11, Funcref(11, 22))
    assert_equal(22, g:optarg)
    assert_equal([], g:listarg)

    assert_equal(17, Funcref(17, 18, 1, 2, 3))
    assert_equal(18, g:optarg)
    assert_equal([1, 2, 3], g:listarg)
  END
  CheckScriptSuccess(lines)
enddef

let SomeFunc = function('len')
let NotAFunc = 'text'

def CombineFuncrefTypes()
  # same arguments, different return type
  let Ref1: func(bool): string
  let Ref2: func(bool): number
  let Ref3: func(bool): any
  Ref3 = g:cond ? Ref1 : Ref2

  # different number of arguments
  let Refa1: func(bool): number
  let Refa2: func(bool, number): number
  let Refa3: func: number
  Refa3 = g:cond ? Refa1 : Refa2

  # different argument types
  let Refb1: func(bool, string): number
  let Refb2: func(string, number): number
  let Refb3: func(any, any): number
  Refb3 = g:cond ? Refb1 : Refb2
enddef

def FuncWithForwardCall()
  return g:DefinedEvenLater("yes")
enddef

def DefinedEvenLater(arg: string): string
  return arg
enddef

def Test_error_in_nested_function()
  # Error in called function requires unwinding the call stack.
  assert_fails('FuncWithForwardCall()', 'E1096:', '', 1, 'FuncWithForwardCall')
enddef

def Test_return_type_wrong()
  CheckScriptFailure([
        'def Func(): number',
        'return "a"',
        'enddef',
        'defcompile'], 'expected number but got string')
  CheckScriptFailure([
        'def Func(): string',
        'return 1',
        'enddef',
        'defcompile'], 'expected string but got number')
  CheckScriptFailure([
        'def Func(): void',
        'return "a"',
        'enddef',
        'defcompile'],
        'E1096: Returning a value in a function without a return type')
  CheckScriptFailure([
        'def Func()',
        'return "a"',
        'enddef',
        'defcompile'],
        'E1096: Returning a value in a function without a return type')

  CheckScriptFailure([
        'def Func(): number',
        'return',
        'enddef',
        'defcompile'], 'E1003:')

  CheckScriptFailure(['def Func(): list', 'return []', 'enddef'], 'E1008:')
  CheckScriptFailure(['def Func(): dict', 'return {}', 'enddef'], 'E1008:')
  CheckScriptFailure(['def Func()', 'return 1'], 'E1057:')

  CheckScriptFailure([
        'vim9script',
        'def FuncB()',
        '  return 123',
        'enddef',
        'def FuncA()',
        '   FuncB()',
        'enddef',
        'defcompile'], 'E1096:')
enddef

def Test_arg_type_wrong()
  CheckScriptFailure(['def Func3(items: list)', 'echo "a"', 'enddef'], 'E1008: Missing <type>')
  CheckScriptFailure(['def Func4(...)', 'echo "a"', 'enddef'], 'E1055: Missing name after ...')
  CheckScriptFailure(['def Func5(items:string)', 'echo "a"'], 'E1069:')
  CheckScriptFailure(['def Func5(items)', 'echo "a"'], 'E1077:')
enddef

def Test_vim9script_call()
  let lines =<< trim END
    vim9script
    let var = ''
    def MyFunc(arg: string)
       var = arg
    enddef
    MyFunc('foobar')
    assert_equal('foobar', var)

    let str = 'barfoo'
    str->MyFunc()
    assert_equal('barfoo', var)

    g:value = 'value'
    g:value->MyFunc()
    assert_equal('value', var)

    let listvar = []
    def ListFunc(arg: list<number>)
       listvar = arg
    enddef
    [1, 2, 3]->ListFunc()
    assert_equal([1, 2, 3], listvar)

    let dictvar = {}
    def DictFunc(arg: dict<number>)
       dictvar = arg
    enddef
    {'a': 1, 'b': 2}->DictFunc()
    assert_equal(#{a: 1, b: 2}, dictvar)
    def CompiledDict()
      {'a': 3, 'b': 4}->DictFunc()
    enddef
    CompiledDict()
    assert_equal(#{a: 3, b: 4}, dictvar)

    #{a: 3, b: 4}->DictFunc()
    assert_equal(#{a: 3, b: 4}, dictvar)

    ('text')->MyFunc()
    assert_equal('text', var)
    ("some")->MyFunc()
    assert_equal('some', var)

    # line starting with single quote is not a mark
    # line starting with double quote can be a method call
    'asdfasdf'->MyFunc()
    assert_equal('asdfasdf', var)
    "xyz"->MyFunc()
    assert_equal('xyz', var)

    def UseString()
      'xyork'->MyFunc()
    enddef
    UseString()
    assert_equal('xyork', var)

    def UseString2()
      "knife"->MyFunc()
    enddef
    UseString2()
    assert_equal('knife', var)

    # prepending a colon makes it a mark
    new
    setline(1, ['aaa', 'bbb', 'ccc'])
    normal! 3Gmt1G
    :'t
    assert_equal(3, getcurpos()[1])
    bwipe!

    MyFunc(
        'continued'
        )
    assert_equal('continued',
            var
            )

    call MyFunc(
        'more'
          ..
          'lines'
        )
    assert_equal(
        'morelines',
        var)
  END
  writefile(lines, 'Xcall.vim')
  source Xcall.vim
  delete('Xcall.vim')
enddef

def Test_vim9script_call_fail_decl()
  let lines =<< trim END
    vim9script
    let var = ''
    def MyFunc(arg: string)
       let var = 123
    enddef
    defcompile
  END
  CheckScriptFailure(lines, 'E1054:')
enddef

def Test_vim9script_call_fail_type()
  let lines =<< trim END
    vim9script
    def MyFunc(arg: string)
      echo arg
    enddef
    MyFunc(1234)
  END
  CheckScriptFailure(lines, 'E1013: argument 1: type mismatch, expected string but got number')
enddef

def Test_vim9script_call_fail_const()
  let lines =<< trim END
    vim9script
    const var = ''
    def MyFunc(arg: string)
       var = 'asdf'
    enddef
    defcompile
  END
  writefile(lines, 'Xcall_const.vim')
  assert_fails('source Xcall_const.vim', 'E46:', '', 1, 'MyFunc')
  delete('Xcall_const.vim')
enddef

" Test that inside :function a Python function can be defined, :def is not
" recognized.
func Test_function_python()
  CheckFeature python3
  let py = 'python3'
  execute py "<< EOF"
def do_something():
  return 1
EOF
endfunc

def Test_delfunc()
  let lines =<< trim END
    vim9script
    def g:GoneSoon()
      echo 'hello'
    enddef

    def CallGoneSoon()
      GoneSoon()
    enddef
    defcompile

    delfunc g:GoneSoon
    CallGoneSoon()
  END
  writefile(lines, 'XToDelFunc')
  assert_fails('so XToDelFunc', 'E933:', '', 1, 'CallGoneSoon')
  assert_fails('so XToDelFunc', 'E933:', '', 1, 'CallGoneSoon')

  delete('XToDelFunc')
enddef

def Test_redef_failure()
  writefile(['def Func0(): string',  'return "Func0"', 'enddef'], 'Xdef')
  so Xdef
  writefile(['def Func1(): string',  'return "Func1"', 'enddef'], 'Xdef')
  so Xdef
  writefile(['def! Func0(): string', 'enddef', 'defcompile'], 'Xdef')
  assert_fails('so Xdef', 'E1027:', '', 1, 'Func0')
  writefile(['def Func2(): string',  'return "Func2"', 'enddef'], 'Xdef')
  so Xdef
  delete('Xdef')

  assert_equal(0, g:Func0())
  assert_equal('Func1', g:Func1())
  assert_equal('Func2', g:Func2())

  delfunc! Func0
  delfunc! Func1
  delfunc! Func2
enddef

def Test_vim9script_func()
  let lines =<< trim END
    vim9script
    func Func(arg)
      echo a:arg
    endfunc
    Func('text')
  END
  writefile(lines, 'XVim9Func')
  so XVim9Func

  delete('XVim9Func')
enddef

" Test for internal functions returning different types
func Test_InternalFuncRetType()
  let lines =<< trim END
    def RetFloat(): float
      return ceil(1.456)
    enddef

    def RetListAny(): list<any>
      return items({'k': 'v'})
    enddef

    def RetListString(): list<string>
      return split('a:b:c', ':')
    enddef

    def RetListDictAny(): list<dict<any>>
      return getbufinfo()
    enddef

    def RetDictNumber(): dict<number>
      return wordcount()
    enddef

    def RetDictString(): dict<string>
      return environ()
    enddef
  END
  call writefile(lines, 'Xscript')
  source Xscript

  call assert_equal(2.0, RetFloat())
  call assert_equal([['k', 'v']], RetListAny())
  call assert_equal(['a', 'b', 'c'], RetListString())
  call assert_notequal([], RetListDictAny())
  call assert_notequal({}, RetDictNumber())
  call assert_notequal({}, RetDictString())
  call delete('Xscript')
endfunc

" Test for passing too many or too few arguments to internal functions
func Test_internalfunc_arg_error()
  let l =<< trim END
    def! FArgErr(): float
      return ceil(1.1, 2)
    enddef
    defcompile
  END
  call writefile(l, 'Xinvalidarg')
  call assert_fails('so Xinvalidarg', 'E118:', '', 1, 'FArgErr')
  let l =<< trim END
    def! FArgErr(): float
      return ceil()
    enddef
    defcompile
  END
  call writefile(l, 'Xinvalidarg')
  call assert_fails('so Xinvalidarg', 'E119:', '', 1, 'FArgErr')
  call delete('Xinvalidarg')
endfunc

let s:funcResult = 0

def FuncNoArgNoRet()
  s:funcResult = 11
enddef

def FuncNoArgRetNumber(): number
  s:funcResult = 22
  return 1234
enddef

def FuncNoArgRetString(): string
  s:funcResult = 45
  return 'text'
enddef

def FuncOneArgNoRet(arg: number)
  s:funcResult = arg
enddef

def FuncOneArgRetNumber(arg: number): number
  s:funcResult = arg
  return arg
enddef

def FuncTwoArgNoRet(one: bool, two: number)
  s:funcResult = two
enddef

def FuncOneArgRetString(arg: string): string
  return arg
enddef

def FuncOneArgRetAny(arg: any): any
  return arg
enddef

def Test_func_type()
  let Ref1: func()
  s:funcResult = 0
  Ref1 = FuncNoArgNoRet
  Ref1()
  assert_equal(11, s:funcResult)

  let Ref2: func
  s:funcResult = 0
  Ref2 = FuncNoArgNoRet
  Ref2()
  assert_equal(11, s:funcResult)

  s:funcResult = 0
  Ref2 = FuncOneArgNoRet
  Ref2(12)
  assert_equal(12, s:funcResult)

  s:funcResult = 0
  Ref2 = FuncNoArgRetNumber
  assert_equal(1234, Ref2())
  assert_equal(22, s:funcResult)

  s:funcResult = 0
  Ref2 = FuncOneArgRetNumber
  assert_equal(13, Ref2(13))
  assert_equal(13, s:funcResult)
enddef

def Test_repeat_return_type()
  let res = 0
  for n in repeat([1], 3)
    res += n
  endfor
  assert_equal(3, res)

  res = 0
  for n in add([1, 2], 3)
    res += n
  endfor
  assert_equal(6, res)
enddef

def Test_argv_return_type()
  next fileone filetwo
  let res = ''
  for name in argv()
    res ..= name
  endfor
  assert_equal('fileonefiletwo', res)
enddef

def Test_func_type_part()
  let RefVoid: func: void
  RefVoid = FuncNoArgNoRet
  RefVoid = FuncOneArgNoRet
  CheckDefFailure(['let RefVoid: func: void', 'RefVoid = FuncNoArgRetNumber'], 'E1012: type mismatch, expected func() but got func(): number')
  CheckDefFailure(['let RefVoid: func: void', 'RefVoid = FuncNoArgRetString'], 'E1012: type mismatch, expected func() but got func(): string')

  let RefAny: func(): any
  RefAny = FuncNoArgRetNumber
  RefAny = FuncNoArgRetString
  CheckDefFailure(['let RefAny: func(): any', 'RefAny = FuncNoArgNoRet'], 'E1012: type mismatch, expected func(): any but got func()')
  CheckDefFailure(['let RefAny: func(): any', 'RefAny = FuncOneArgNoRet'], 'E1012: type mismatch, expected func(): any but got func(number)')

  let RefNr: func: number
  RefNr = FuncNoArgRetNumber
  RefNr = FuncOneArgRetNumber
  CheckDefFailure(['let RefNr: func: number', 'RefNr = FuncNoArgNoRet'], 'E1012: type mismatch, expected func(): number but got func()')
  CheckDefFailure(['let RefNr: func: number', 'RefNr = FuncNoArgRetString'], 'E1012: type mismatch, expected func(): number but got func(): string')

  let RefStr: func: string
  RefStr = FuncNoArgRetString
  RefStr = FuncOneArgRetString
  CheckDefFailure(['let RefStr: func: string', 'RefStr = FuncNoArgNoRet'], 'E1012: type mismatch, expected func(): string but got func()')
  CheckDefFailure(['let RefStr: func: string', 'RefStr = FuncNoArgRetNumber'], 'E1012: type mismatch, expected func(): string but got func(): number')
enddef

def Test_func_type_fails()
  CheckDefFailure(['let ref1: func()'], 'E704:')

  CheckDefFailure(['let Ref1: func()', 'Ref1 = FuncNoArgRetNumber'], 'E1012: type mismatch, expected func() but got func(): number')
  CheckDefFailure(['let Ref1: func()', 'Ref1 = FuncOneArgNoRet'], 'E1012: type mismatch, expected func() but got func(number)')
  CheckDefFailure(['let Ref1: func()', 'Ref1 = FuncOneArgRetNumber'], 'E1012: type mismatch, expected func() but got func(number): number')
  CheckDefFailure(['let Ref1: func(bool)', 'Ref1 = FuncTwoArgNoRet'], 'E1012: type mismatch, expected func(bool) but got func(bool, number)')
  CheckDefFailure(['let Ref1: func(?bool)', 'Ref1 = FuncTwoArgNoRet'], 'E1012: type mismatch, expected func(?bool) but got func(bool, number)')
  CheckDefFailure(['let Ref1: func(...bool)', 'Ref1 = FuncTwoArgNoRet'], 'E1012: type mismatch, expected func(...bool) but got func(bool, number)')

  CheckDefFailure(['let RefWrong: func(string ,number)'], 'E1068:')
  CheckDefFailure(['let RefWrong: func(string,number)'], 'E1069:')
  CheckDefFailure(['let RefWrong: func(bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, bool)'], 'E1005:')
  CheckDefFailure(['let RefWrong: func(bool):string'], 'E1069:')
enddef

def Test_func_return_type()
  let nr: number
  nr = FuncNoArgRetNumber()
  assert_equal(1234, nr)

  nr = FuncOneArgRetAny(122)
  assert_equal(122, nr)

  let str: string
  str = FuncOneArgRetAny('yes')
  assert_equal('yes', str)

  CheckDefFailure(['let str: string', 'str = FuncNoArgRetNumber()'], 'E1012: type mismatch, expected string but got number')
enddef

def MultiLine(
    arg1: string,
    arg2 = 1234,
    ...rest: list<string>
      ): string
  return arg1 .. arg2 .. join(rest, '-')
enddef

def MultiLineComment(
    arg1: string, # comment
    arg2 = 1234, # comment
    ...rest: list<string> # comment
      ): string # comment
  return arg1 .. arg2 .. join(rest, '-')
enddef

def Test_multiline()
  assert_equal('text1234', MultiLine('text'))
  assert_equal('text777', MultiLine('text', 777))
  assert_equal('text777one', MultiLine('text', 777, 'one'))
  assert_equal('text777one-two', MultiLine('text', 777, 'one', 'two'))
enddef

func Test_multiline_not_vim9()
  call assert_equal('text1234', MultiLine('text'))
  call assert_equal('text777', MultiLine('text', 777))
  call assert_equal('text777one', MultiLine('text', 777, 'one'))
  call assert_equal('text777one-two', MultiLine('text', 777, 'one', 'two'))
endfunc


" When using CheckScriptFailure() for the below test, E1010 is generated instead
" of E1056.
func Test_E1056_1059()
  let caught_1056 = 0
  try
    def F():
      return 1
    enddef
  catch /E1056:/
    let caught_1056 = 1
  endtry
  call assert_equal(1, caught_1056)

  let caught_1059 = 0
  try
    def F5(items : list)
      echo 'a'
    enddef
  catch /E1059:/
    let caught_1059 = 1
  endtry
  call assert_equal(1, caught_1059)
endfunc

func DelMe()
  echo 'DelMe'
endfunc

def Test_error_reporting()
  # comment lines at the start of the function
  let lines =<< trim END
    " comment
    def Func()
      # comment
      # comment
      invalid
    enddef
    defcompile
  END
  call writefile(lines, 'Xdef')
  try
    source Xdef
    assert_report('should have failed')
  catch /E476:/
    assert_match('Invalid command: invalid', v:exception)
    assert_match(', line 3$', v:throwpoint)
  endtry

  # comment lines after the start of the function
  lines =<< trim END
    " comment
    def Func()
      let x = 1234
      # comment
      # comment
      invalid
    enddef
    defcompile
  END
  call writefile(lines, 'Xdef')
  try
    source Xdef
    assert_report('should have failed')
  catch /E476:/
    assert_match('Invalid command: invalid', v:exception)
    assert_match(', line 4$', v:throwpoint)
  endtry

  lines =<< trim END
    vim9script
    def Func()
      let db = #{foo: 1, bar: 2}
      # comment
      let x = db.asdf
    enddef
    defcompile
    Func()
  END
  call writefile(lines, 'Xdef')
  try
    source Xdef
    assert_report('should have failed')
  catch /E716:/
    assert_match('_Func, line 3$', v:throwpoint)
  endtry

  call delete('Xdef')
enddef

def Test_deleted_function()
  CheckDefExecFailure([
      'let RefMe: func = function("g:DelMe")',
      'delfunc g:DelMe',
      'echo RefMe()'], 'E117:')
enddef

def Test_unknown_function()
  CheckDefExecFailure([
      'let Ref: func = function("NotExist")',
      'delfunc g:NotExist'], 'E700:')
enddef

def RefFunc(Ref: func(string): string): string
  return Ref('more')
enddef

def Test_closure_simple()
  let local = 'some '
  assert_equal('some more', RefFunc({s -> local .. s}))
enddef

def MakeRef()
  let local = 'some '
  g:Ref = {s -> local .. s}
enddef

def Test_closure_ref_after_return()
  MakeRef()
  assert_equal('some thing', g:Ref('thing'))
  unlet g:Ref
enddef

def MakeTwoRefs()
  let local = ['some']
  g:Extend = {s -> local->add(s)}
  g:Read = {-> local}
enddef

def Test_closure_two_refs()
  MakeTwoRefs()
  assert_equal('some', join(g:Read(), ' '))
  g:Extend('more')
  assert_equal('some more', join(g:Read(), ' '))
  g:Extend('even')
  assert_equal('some more even', join(g:Read(), ' '))

  unlet g:Extend
  unlet g:Read
enddef

def ReadRef(Ref: func(): list<string>): string
  return join(Ref(), ' ')
enddef

def ExtendRef(Ref: func(string), add: string)
  Ref(add)
enddef

def Test_closure_two_indirect_refs()
  MakeTwoRefs()
  assert_equal('some', ReadRef(g:Read))
  ExtendRef(g:Extend, 'more')
  assert_equal('some more', ReadRef(g:Read))
  ExtendRef(g:Extend, 'even')
  assert_equal('some more even', ReadRef(g:Read))

  unlet g:Extend
  unlet g:Read
enddef

def MakeArgRefs(theArg: string)
  let local = 'loc_val'
  g:UseArg = {s -> theArg .. '/' .. local .. '/' .. s}
enddef

def MakeArgRefsVarargs(theArg: string, ...rest: list<string>)
  let local = 'the_loc'
  g:UseVararg = {s -> theArg .. '/' .. local .. '/' .. s .. '/' .. join(rest)}
enddef

def Test_closure_using_argument()
  MakeArgRefs('arg_val')
  assert_equal('arg_val/loc_val/call_val', g:UseArg('call_val'))

  MakeArgRefsVarargs('arg_val', 'one', 'two')
  assert_equal('arg_val/the_loc/call_val/one two', g:UseVararg('call_val'))

  unlet g:UseArg
  unlet g:UseVararg
enddef

def MakeGetAndAppendRefs()
  let local = 'a'

  def Append(arg: string)
    local ..= arg
  enddef
  g:Append = Append

  def Get(): string
    return local
  enddef
  g:Get = Get
enddef

def Test_closure_append_get()
  MakeGetAndAppendRefs()
  assert_equal('a', g:Get())
  g:Append('-b')
  assert_equal('a-b', g:Get())
  g:Append('-c')
  assert_equal('a-b-c', g:Get())

  unlet g:Append
  unlet g:Get
enddef

def Test_nested_closure()
  let local = 'text'
  def Closure(arg: string): string
    return local .. arg
  enddef
  assert_equal('text!!!', Closure('!!!'))
enddef

func GetResult(Ref)
  return a:Ref('some')
endfunc

def Test_call_closure_not_compiled()
  let text = 'text'
  g:Ref = {s ->  s .. text}
  assert_equal('sometext', GetResult(g:Ref))
enddef

def Test_sort_return_type()
  let res: list<number>
  res = [1, 2, 3]->sort()
enddef

def Test_getqflist_return_type()
  let l = getqflist()
  assert_equal([], l)

  let d = getqflist(#{items: 0})
  assert_equal(#{items: []}, d)
enddef

def Test_getloclist_return_type()
  let l = getloclist(1)
  assert_equal([], l)

  let d = getloclist(1, #{items: 0})
  assert_equal(#{items: []}, d)
enddef

def Test_copy_return_type()
  let l = copy([1, 2, 3])
  let res = 0
  for n in l
    res += n
  endfor
  assert_equal(6, res)

  let dl = deepcopy([1, 2, 3])
  res = 0
  for n in dl
    res += n
  endfor
  assert_equal(6, res)

  dl = deepcopy([1, 2, 3], true)
enddef

def Test_extend_return_type()
  let l = extend([1, 2], [3])
  let res = 0
  for n in l
    res += n
  endfor
  assert_equal(6, res)
enddef

def Test_garbagecollect()
  garbagecollect(true)
enddef

def Test_insert_return_type()
  let l = insert([2, 1], 3)
  let res = 0
  for n in l
    res += n
  endfor
  assert_equal(6, res)
enddef

def Test_keys_return_type()
  const var: list<string> = #{a: 1, b: 2}->keys()
  assert_equal(['a', 'b'], var)
enddef

def Test_reverse_return_type()
  let l = reverse([1, 2, 3])
  let res = 0
  for n in l
    res += n
  endfor
  assert_equal(6, res)
enddef

def Test_remove_return_type()
  let l = remove(#{one: [1, 2], two: [3, 4]}, 'one')
  let res = 0
  for n in l
    res += n
  endfor
  assert_equal(3, res)
enddef

def Test_filter_return_type()
  let l = filter([1, 2, 3], {-> 1})
  let res = 0
  for n in l
    res += n
  endfor
  assert_equal(6, res)
enddef

def Test_bufnr()
  let buf = bufnr()
  assert_equal(buf, bufnr('%'))

  buf = bufnr('Xdummy', true)
  assert_notequal(-1, buf)
  exe 'bwipe! ' .. buf
enddef

def Test_col()
  new
  setline(1, 'asdf')
  assert_equal(5, col([1, '$']))
enddef

def Test_char2nr()
  assert_equal(12354, char2nr('???', true))
enddef

def Test_getreg_return_type()
  let s1: string = getreg('"')
  let s2: string = getreg('"', 1)
  let s3: list<string> = getreg('"', 1, 1)
enddef

def Wrong_dict_key_type(items: list<number>): list<number>
  return filter(items, {_, val -> get({val: 1}, 'x')})
enddef

def Test_wrong_dict_key_type()
  assert_fails('Wrong_dict_key_type([1, 2, 3])', 'E1029:')
enddef

def Line_continuation_in_def(dir: string = ''): string
    let path: string = empty(dir)
            \ ? 'empty'
            \ : 'full'
    return path
enddef

def Test_line_continuation_in_def()
  assert_equal('full', Line_continuation_in_def('.'))
enddef

def Line_continuation_in_lambda(): list<number>
  let x = range(97, 100)
      ->map({_, v -> nr2char(v)
          ->toupper()})
      ->reverse()
  return x
enddef

def Test_line_continuation_in_lambda()
  assert_equal(['D', 'C', 'B', 'A'], Line_continuation_in_lambda())
enddef

func Test_silent_echo()
  CheckScreendump

  let lines =<< trim END
    vim9script
    def EchoNothing()
      silent echo ''
    enddef
    defcompile
  END
  call writefile(lines, 'XTest_silent_echo')

  " Check that the balloon shows up after a mouse move
  let buf = RunVimInTerminal('-S XTest_silent_echo', {'rows': 6})
  call term_sendkeys(buf, ":abc")
  call VerifyScreenDump(buf, 'Test_vim9_silent_echo', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_silent_echo')
endfunc

""""""" builtin functions that behave differently in Vim9

def Test_bufname()
  split SomeFile
  assert_equal('SomeFile', bufname('%'))
  edit OtherFile
  assert_equal('SomeFile', bufname('#'))
  close
enddef

def Test_bufwinid()
  let origwin = win_getid()
  below split SomeFile
  let SomeFileID = win_getid()
  below split OtherFile
  below split SomeFile
  assert_equal(SomeFileID, bufwinid('SomeFile'))

  win_gotoid(origwin)
  only
  bwipe SomeFile
  bwipe OtherFile
enddef

def Test_count()
  assert_equal(3, count('ABC ABC ABC', 'b', true))
  assert_equal(0, count('ABC ABC ABC', 'b', false))
enddef

def Test_expand()
  split SomeFile
  assert_equal(['SomeFile'], expand('%', true, true))
  close
enddef

def Test_getbufinfo()
  let bufinfo = getbufinfo(bufnr())
  assert_equal(bufinfo, getbufinfo('%'))

  edit Xtestfile1
  hide edit Xtestfile2
  hide enew
  getbufinfo(#{bufloaded: true, buflisted: true, bufmodified: false})
      ->len()->assert_equal(3)
  bwipe Xtestfile1 Xtestfile2
enddef

def Test_getbufline()
  e SomeFile
  let buf = bufnr()
  e #
  let lines = ['aaa', 'bbb', 'ccc']
  setbufline(buf, 1, lines)
  assert_equal(lines, getbufline('#', 1, '$'))

  bwipe!
enddef

def Test_getchangelist()
  new
  setline(1, 'some text')
  let changelist = bufnr()->getchangelist()
  assert_equal(changelist, getchangelist('%'))
  bwipe!
enddef

def Test_getchar()
  while getchar(0)
  endwhile
  assert_equal(0, getchar(true))
enddef

def Test_getcompletion()
  set wildignore=*.vim,*~
  let l = getcompletion('run', 'file', true)
  assert_equal([], l)
  set wildignore&
enddef

def Test_getreg()
  let lines = ['aaa', 'bbb', 'ccc']
  setreg('a', lines)
  assert_equal(lines, getreg('a', true, true))
enddef

def Test_glob()
  assert_equal(['runtest.vim'], glob('runtest.vim', true, true, true))
enddef

def Test_globpath()
  assert_equal(['./runtest.vim'], globpath('.', 'runtest.vim', true, true, true))
enddef

def Test_has()
  assert_equal(1, has('eval', true))
enddef

def Test_hasmapto()
  assert_equal(0, hasmapto('foobar', 'i', true))
  iabbrev foo foobar
  assert_equal(1, hasmapto('foobar', 'i', true))
  iunabbrev foo
enddef

def Test_index()
  assert_equal(3, index(['a', 'b', 'a', 'B'], 'b', 2, true))
enddef

def Test_list2str_str2list_utf8()
  let s = "\u3042\u3044"
  let l = [0x3042, 0x3044]
  assert_equal(l, str2list(s, true))
  assert_equal(s, list2str(l, true))
enddef

def SID(): number
  return expand('<SID>')
          ->matchstr('<SNR>\zs\d\+\ze_$')
          ->str2nr()
enddef

def Test_maparg()
  let lnum = str2nr(expand('<sflnum>'))
  map foo bar
  assert_equal(#{
        lnum: lnum + 1,
        script: 0,
        mode: ' ',
        silent: 0,
        noremap: 0,
        lhs: 'foo',
        lhsraw: 'foo',
        nowait: 0,
        expr: 0,
        sid: SID(),
        rhs: 'bar',
        buffer: 0},
        maparg('foo', '', false, true))
  unmap foo
enddef

def Test_mapcheck()
  iabbrev foo foobar
  assert_equal('foobar', mapcheck('foo', 'i', true))
  iunabbrev foo
enddef

def Test_nr2char()
  assert_equal('a', nr2char(97, true))
enddef

def Test_readdir()
   eval expand('sautest')->readdir({e -> e[0] !=# '.'})
   eval expand('sautest')->readdirex({e -> e.name[0] !=# '.'})
enddef

def Test_search()
  new
  setline(1, ['foo', 'bar'])
  let val = 0
  # skip expr returns boolean
  assert_equal(2, search('bar', 'W', 0, 0, {-> val == 1}))
  :1
  assert_equal(0, search('bar', 'W', 0, 0, {-> val == 0}))
  # skip expr returns number, only 0 and 1 are accepted
  :1
  assert_equal(2, search('bar', 'W', 0, 0, {-> 0}))
  :1
  assert_equal(0, search('bar', 'W', 0, 0, {-> 1}))
  assert_fails("search('bar', '', 0, 0, {-> -1})", 'E1023:')
  assert_fails("search('bar', '', 0, 0, {-> -1})", 'E1023:')
enddef

def Test_searchcount()
  new
  setline(1, "foo bar")
  :/foo
  assert_equal(#{
      exact_match: 1,
      current: 1,
      total: 1,
      maxcount: 99,
      incomplete: 0,
    }, searchcount(#{recompute: true}))
  bwipe!
enddef

def Test_searchdecl()
  assert_equal(1, searchdecl('blah', true, true))
enddef

def Test_setbufvar()
   setbufvar(bufnr('%'), '&syntax', 'vim')
   assert_equal('vim', &syntax)
   setbufvar(bufnr('%'), '&ts', 16)
   assert_equal(16, &ts)
   settabwinvar(1, 1, '&syntax', 'vam')
   assert_equal('vam', &syntax)
   settabwinvar(1, 1, '&ts', 15)
   assert_equal(15, &ts)
   setlocal ts=8

   setbufvar('%', 'myvar', 123)
   assert_equal(123, getbufvar('%', 'myvar'))
enddef

def Test_setloclist()
  let items = [#{filename: '/tmp/file', lnum: 1, valid: true}]
  let what = #{items: items}
  setqflist([], ' ', what)
  setloclist(0, [], ' ', what)
enddef

def Test_setreg()
  setreg('a', ['aaa', 'bbb', 'ccc'])
  let reginfo = getreginfo('a')
  setreg('a', reginfo)
  assert_equal(reginfo, getreginfo('a'))
enddef 

def Test_spellsuggest()
  if !has('spell')
    MissingFeature 'spell'
  else
    spellsuggest('marrch', 1, true)->assert_equal(['March'])
  endif
enddef

def Test_split()
  split('  aa  bb  ', '\W\+', true)->assert_equal(['', 'aa', 'bb', ''])
enddef

def Test_str2nr()
  str2nr("1'000'000", 10, true)->assert_equal(1000000)
enddef

def Test_strchars()
  strchars("A\u20dd", true)->assert_equal(1)
enddef

def Test_submatch()
  let pat = 'A\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)\(.\)'
  let Rep = {-> range(10)->map({_, v -> submatch(v, true)})->string()}
  let actual = substitute('A123456789', pat, Rep, '')
  let expected = "[['A123456789'], ['1'], ['2'], ['3'], ['4'], ['5'], ['6'], ['7'], ['8'], ['9']]"
  assert_equal(expected, actual)
enddef

def Test_synID()
  new
  setline(1, "text")
  assert_equal(0, synID(1, 1, true))
  bwipe!
enddef

def Test_term_gettty()
  if !has('terminal')
    MissingFeature 'terminal'
  else
    let buf = Run_shell_in_terminal({})
    assert_notequal('', term_gettty(buf, true))
    StopShellInTerminal(buf)
  endif
enddef

def Test_term_start()
  if !has('terminal')
    MissingFeature 'terminal'
  else
    botright new
    let winnr = winnr()
    term_start(&shell, #{curwin: true})
    assert_equal(winnr, winnr())
    bwipe!
  endif
enddef

def Test_timer_paused()
  let id = timer_start(50, {-> 0})
  timer_pause(id, true)
  let info = timer_info(id)
  assert_equal(1, info[0]['paused'])
  timer_stop(id)
enddef

def Test_win_splitmove()
  split
  win_splitmove(1, 2, #{vertical: true, rightbelow: true})
  close
enddef

""""""" end of builtin functions

def Fibonacci(n: number): number
  if n < 2
    return n
  else
    return Fibonacci(n - 1) + Fibonacci(n - 2)
  endif
enddef

def Test_recursive_call()
  assert_equal(6765, Fibonacci(20))
enddef

def TreeWalk(dir: string): list<any>
  return readdir(dir)->map({_, val ->
            fnamemodify(dir .. '/' .. val, ':p')->isdirectory()
               ? {val: TreeWalk(dir .. '/' .. val)}
               : val
             })
enddef

def Test_closure_in_map()
  mkdir('XclosureDir/tdir', 'p')
  writefile(['111'], 'XclosureDir/file1')
  writefile(['222'], 'XclosureDir/file2')
  writefile(['333'], 'XclosureDir/tdir/file3')

  assert_equal(['file1', 'file2', {'tdir': ['file3']}], TreeWalk('XclosureDir'))

  delete('XclosureDir', 'rf')
enddef

def Test_partial_call()
  let Xsetlist = function('setloclist', [0])
  Xsetlist([], ' ', {'title': 'test'})
  assert_equal({'title': 'test'}, getloclist(0, {'title': 1}))

  Xsetlist = function('setloclist', [0, [], ' '])
  Xsetlist({'title': 'test'})
  assert_equal({'title': 'test'}, getloclist(0, {'title': 1}))

  Xsetlist = function('setqflist')
  Xsetlist([], ' ', {'title': 'test'})
  assert_equal({'title': 'test'}, getqflist({'title': 1}))

  Xsetlist = function('setqflist', [[], ' '])
  Xsetlist({'title': 'test'})
  assert_equal({'title': 'test'}, getqflist({'title': 1}))
enddef

def Test_cmd_modifier()
  tab echo '0'
  CheckDefFailure(['5tab echo 3'], 'E16:')
enddef

def Test_restore_modifiers()
  # check that when compiling a :def function command modifiers are not messed
  # up.
  let lines =<< trim END
      vim9script
      set eventignore=
      autocmd QuickFixCmdPost * copen
      def AutocmdsDisabled()
          eval 0
      enddef
      func Func()
        noautocmd call s:AutocmdsDisabled()
        let g:ei_after = &eventignore
      endfunc
      Func()
  END
  CheckScriptSuccess(lines)
  assert_equal('', g:ei_after)
enddef


" vim: ts=8 sw=2 sts=2 expandtab tw=80 fdm=marker
