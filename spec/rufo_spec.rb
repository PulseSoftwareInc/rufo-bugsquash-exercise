require "spec_helper"
require "pp"

def assert_format(code, expected = code, **options)
  expected = expected.rstrip + "\n"

  line = caller_locations[0].lineno

  ex = it "formats #{code.inspect} (line: #{line})" do
    actual = Rufo.format(code, **options)
    if actual != expected
      fail "Expected\n\n~~~\n#{code}\n~~~\nto format to:\n\n~~~\n#{expected}\n~~~\n\nbut got:\n\n~~~\n#{actual}\n~~~\n\n  diff = #{expected.inspect}\n         #{actual.inspect}"
    end

    second = Rufo.format(actual, **options)
    if second != actual
      fail "Idempotency check failed. Expected\n\n~~~\n#{actual}\n~~~\nto format to:\n\n~~~\n#{actual}\n~~~\n\nbut got:\n\n~~~\n#{second}\n~~~\n\n  diff = #{second.inspect}\n         #{actual.inspect}"
    end
  end

  # This is so we can do `rspec spec/rufo_spec.rb:26` and
  # refer to line numbers for assert_format
  ex.metadata[:line_number] = line
end

RSpec.describe Rufo do
  # New Testcases
  assert_format "begin\nrescue A\nend"
  assert_format "begin\nrescue A\nrescue B\nend"

  # Empty
  assert_format "", ""

  # Comments
  assert_format "# foo"
  assert_format "# foo\n# bar"
  assert_format "1   # foo", "1 # foo"
  assert_format "# a\n\n# b"
  assert_format "# a\n\n\n# b", "# a\n\n# b"
  assert_format "# a\n1", "# a\n1"
  assert_format "# a\n\n\n1", "# a\n\n1"
  assert_format "1 # a\n# b"
  assert_format "1 # a\n\n# b"
  assert_format "1 # a\n\n2 # b"
  assert_format "1 # a\n\n\n2 # b", "1 # a\n\n2 # b"
  assert_format "1 # a\n\n\n\n\n\n\n2 # b", "1 # a\n\n2 # b"
  assert_format "1 # a\n\n\n# b\n\n\n # c\n 2 # b", "1 # a\n\n# b\n\n# c\n2 # b"

  # Nil
  assert_format "nil"

  # Bool
  assert_format "false"
  assert_format "true"

  # String literals
  assert_format "'hello'"
  assert_format %("hello")
  assert_format %Q("hello")
  assert_format %("\\n")
  assert_format %("hello \#{1} foo")
  assert_format %("hello \#{  1   } foo"), %("hello \#{1} foo")
  assert_format %("hello \#{\n1} foo"), %("hello \#{1} foo")

  # Heredoc
  assert_format "<<-EOF\n  foo\n  bar\nEOF"
  assert_format "foo  1 , <<-EOF , 2 \n  foo\n  bar\nEOF", "foo 1, <<-EOF, 2\n  foo\n  bar\nEOF"
  assert_format "foo  1 , <<-EOF1 , 2 , <<-EOF2 , 3 \n  foo\n  bar\nEOF1\n  baz \nEOF2", "foo 1, <<-EOF1, 2, <<-EOF2, 3\n  foo\n  bar\nEOF1\n  baz \nEOF2"
  assert_format "foo  1 , <<-EOF1 , 2 , <<-EOF2 \n  foo\n  bar\nEOF1\n  baz \nEOF2", "foo 1, <<-EOF1, 2, <<-EOF2\n  foo\n  bar\nEOF1\n  baz \nEOF2"
  assert_format "foo(1 , <<-EOF , 2 )\n  foo\n  bar\nEOF", "foo(1, <<-EOF, 2)\n  foo\n  bar\nEOF"

  # Heredoc with tilde
  assert_format "<<~EOF\n  foo\n   bar\nEOF", "<<~EOF\n  foo\n   bar\nEOF"
  assert_format "<<~EOF\n  \#{1}\n   bar\nEOF"
  assert_format "begin \n <<~EOF\n  foo\n   bar\nEOF\n end", "begin\n  <<~EOF\n    foo\n     bar\n  EOF\nend"

  # Symbol literals
  assert_format ":foo"
  assert_format %(:"foo")
  assert_format %(:"foo\#{1}")
  assert_format ":*"

  # Numbers
  assert_format "123"

  # Assignment
  assert_format "a   =   1", "a = 1"
  assert_format "a   =  \n2", "a =\n  2"
  assert_format "a   =   # hello \n2", "a = # hello\n  2"
  assert_format "a =   if 1 \n 2 \n end", "a = if 1\n      2\n    end"
  assert_format "a =   unless 1 \n 2 \n end", "a = unless 1\n      2\n    end"
  assert_format "a =   begin\n1 \n end", "a = begin\n  1\nend"
  assert_format "a =   case\n when 1 \n 2 \n end", "a = case\n    when 1\n      2\n    end"

  # Multiple assignent
  assert_format "a =   1  ,   2", "a = 1, 2"
  assert_format "a , b  = 2 ", "a, b = 2"
  assert_format "a , b, ( c, d )  = 2 ", "a, b, (c, d) = 2"
  assert_format " *x = 1", "*x = 1"
  assert_format " a , b , *x = 1", "a, b, *x = 1"
  assert_format " *x , a , b = 1", "*x, a, b = 1"
  assert_format " a, b, *x, c, d = 1", "a, b, *x, c, d = 1"

  # Assign + op
  assert_format "a += 2"
  assert_format "a += \n 2", "a +=\n  2"

  # Inline if
  assert_format "1  ?   2    :  3", "1 ? 2 : 3"
  assert_format "1 ? \n 2 : 3", "1 ?\n  2 : 3"
  assert_format "1 ? 2 : \n 3", "1 ? 2 :\n  3"

  # Suffix if/unless/rescue/while/until
  assert_format "1   if  2", "1 if 2"
  assert_format "1   unless  2", "1 unless 2"
  assert_format "1   rescue  2", "1 rescue 2"
  assert_format "1   while  2", "1 while 2"
  assert_format "1   until  2", "1 until 2"

  # If
  assert_format "if 1\n2\nend", "if 1\n  2\nend"
  assert_format "if 1\n\n2\n\nend", "if 1\n  2\nend"
  assert_format "if 1\n\nend", "if 1\nend"
  assert_format "if 1;end", "if 1\nend"
  assert_format "if 1 # hello\nend", "if 1 # hello\nend"
  assert_format "if 1 # hello\n\nend", "if 1 # hello\nend"
  assert_format "if 1 # hello\n1\nend", "if 1 # hello\n  1\nend"
  assert_format "if 1;# hello\n1\nend", "if 1 # hello\n  1\nend"
  assert_format "if 1 # hello\n # bye\nend", "if 1 # hello\n  # bye\nend"
  assert_format "if 1; 2; else; end", "if 1\n  2\nelse\nend"
  assert_format "if 1; 2; else; 3; end", "if 1\n  2\nelse\n  3\nend"
  assert_format "if 1; 2; else # comment\n 3; end", "if 1\n  2\nelse # comment\n  3\nend"
  assert_format "begin\nif 1\n2\nelse\n3\nend\nend", "begin\n  if 1\n    2\n  else\n    3\n  end\nend"
  assert_format "if 1 then 2 else 3 end", "if 1\n  2\nelse\n  3\nend"
  assert_format "if 1 \n 2 \n elsif 3 \n 4 \n end", "if 1\n  2\nelsif 3\n  4\nend"

  # Unless
  assert_format "unless 1\n2\nend", "unless 1\n  2\nend"
  assert_format "unless 1\n2\nelse\nend", "unless 1\n  2\nelse\nend"

  # While
  assert_format "while  1 ; end", "while 1; end"
  assert_format "while  1 \n end", "while 1\nend"
  assert_format "while  1 \n 2 \n 3 \n end", "while 1\n  2\n  3\nend"
  assert_format "while  1  # foo \n 2 \n 3 \n end", "while 1 # foo\n  2\n  3\nend"

  # Until
  assert_format "until  1 ; end", "until 1; end"

  # Case
  assert_format "case \n when 1 then 2 \n end", "case\nwhen 1 then 2\nend"
  assert_format "case \n when 1 then 2 \n when 3 then 4 \n end", "case\nwhen 1 then 2\nwhen 3 then 4\nend"
  assert_format "case \n when 1 then 2 else 3 \n end", "case\nwhen 1 then 2\nelse 3\nend"
  assert_format "case \n when 1 ; 2 \n end", "case\nwhen 1; 2\nend"
  assert_format "case \n when 1 \n 2 \n end", "case\nwhen 1\n  2\nend"
  assert_format "case \n when 1 \n 2 \n 3 \n end", "case\nwhen 1\n  2\n  3\nend"
  assert_format "case \n when 1 \n 2 \n 3 \n when 4 \n 5 \n end", "case\nwhen 1\n  2\n  3\nwhen 4\n  5\nend"
  assert_format "case 123 \n when 1 \n 2 \n end", "case 123\nwhen 1\n  2\nend"
  assert_format "case  # foo \n when 1 \n 2 \n end", "case # foo\nwhen 1\n  2\nend"
  assert_format "case \n when 1  # comment \n 2 \n end", "case\nwhen 1 # comment\n  2\nend"
  assert_format "case \n when 1 then 2 else \n 3 \n end", "case\nwhen 1 then 2\nelse\n  3\nend"
  assert_format "case \n when 1 then 2 else ; \n 3 \n end", "case\nwhen 1 then 2\nelse\n  3\nend"
  assert_format "case \n when 1 then 2 else  # comm \n 3 \n end", "case\nwhen 1 then 2\nelse # comm\n  3\nend"
  assert_format "begin \n case \n when 1 \n 2 \n when 3 \n 4 \n  else \n 5 \n end \n end", "begin\n  case\n  when 1\n    2\n  when 3\n    4\n  else\n    5\n  end\nend"
  assert_format "case \n when 1 then \n 2 \n end", "case\nwhen 1\n  2\nend"
  assert_format "case \n when 1 then ; \n 2 \n end", "case\nwhen 1\n  2\nend"
  assert_format "case \n when 1 ; \n 2 \n end", "case\nwhen 1\n  2\nend"
  assert_format "case \n when 1 , \n 2 ; \n 3 \n end", "case\nwhen 1,\n     2\n  3\nend"
  assert_format "case \n when 1 , 2,  # comm\n \n 3 \n end", "case\nwhen 1, 2, # comm\n     3\nend"
  assert_format "begin \n case \n when :x \n # comment \n 2 \n end \n end", "begin\n  case\n  when :x\n    # comment\n    2\n  end\nend"

  # Variables
  assert_format "a = 1\n  a", "a = 1\na"

  # Instance variable
  assert_format "@foo"

  # Constants and paths
  assert_format "Foo"
  assert_format "Foo::Bar::Baz"
  assert_format "Foo::Bar::Baz"
  assert_format "Foo:: Bar:: Baz", "Foo::Bar::Baz"
  assert_format "Foo:: \nBar", "Foo::Bar"
  assert_format "::Foo"
  assert_format "::Foo::Bar"

  # Calls
  assert_format "foo"
  assert_format "foo()"
  assert_format "foo(  )", "foo()"
  assert_format "foo( \n\n )", "foo()"
  assert_format "foo(  1  )", "foo(1)"
  assert_format "foo(  1 ,   2 )", "foo(1, 2)"
  assert_format "foo   1", "foo 1"
  assert_format "foo   1,  2", "foo 1, 2"
  assert_format "foo   1,  *x ", "foo 1, *x"
  assert_format "foo   1,  *x , 2  ", "foo 1, *x, 2"
  assert_format "foo   1,  *x , 2 , 3 ", "foo 1, *x, 2, 3"
  assert_format "foo   1,  *x , 2 , 3 , *z , *w , 4 ", "foo 1, *x, 2, 3, *z, *w, 4"
  assert_format "foo   *x ", "foo *x"
  assert_format "foo   1, \n  *x ", "foo 1,\n    *x"
  assert_format "foo   1,  *x , *y ", "foo 1, *x, *y"
  assert_format "foo   1,  **x", "foo 1, **x"
  assert_format "foo   1,  \n **x", "foo 1,\n    **x"
  assert_format "foo   1,  **x , **y", "foo 1, **x, **y"
  assert_format "foo   1,  :bar  =>  2 , :baz  =>  3", "foo 1, :bar => 2, :baz => 3"
  assert_format "foo   1,  bar:  2 , baz:  3", "foo 1, bar: 2, baz: 3"
  assert_format "foo   1, \n bar:  2 , baz:  3", "foo 1,\n    bar: 2, baz: 3"
  assert_format "foo 1, \n 2", "foo 1,\n    2"
  assert_format "foo(1, \n 2)", "foo(1,\n    2)"
  assert_format "foo(\n1, \n 2)", "foo(\n  1,\n  2\n)"
  assert_format "foo(\n1, \n 2 \n)", "foo(\n  1,\n  2\n)"
  assert_format "begin\n foo(\n1, \n 2 \n) \n end", "begin\n  foo(\n    1,\n    2\n  )\nend"
  assert_format "begin\n foo(1, \n 2 \n ) \n end", "begin\n  foo(1,\n      2)\nend"
  assert_format "begin\n foo(1, \n 2, \n ) \n end", "begin\n  foo(1,\n      2)\nend"
  assert_format "begin\n foo(\n 1, \n 2, \n ) \n end", "begin\n  foo(\n    1,\n    2,\n  )\nend"
  assert_format "begin\n foo(\n 1, \n 2, ) \n end", "begin\n  foo(\n    1,\n    2,\n  )\nend"
  assert_format "begin\n foo(\n1, \n 2) \n end", "begin\n  foo(\n    1,\n    2\n  )\nend"
  assert_format "begin\n foo(\n1, \n 2 # comment\n) \n end", "begin\n  foo(\n    1,\n    2 # comment\n  )\nend"
  assert_format "foo(bar(\n1,\n))", "foo(bar(\n  1,\n))"
  assert_format "foo(bar(\n  1,\n  baz(\n    2\n  )\n))"
  assert_format "foo  &block", "foo &block"
  assert_format "foo 1 ,  &block", "foo 1, &block"
  assert_format "foo(1 ,  &block)", "foo(1, &block)"

  # Calls with receiver
  assert_format "foo . bar", "foo.bar"
  assert_format "foo:: bar", "foo::bar"
  assert_format "foo . bar . baz", "foo.bar.baz"
  assert_format "foo . bar( 1 , 2 )", "foo.bar(1, 2)"
  assert_format "foo . \n bar", "foo.\n  bar"
  assert_format "foo . \n bar . \n baz", "foo.\n  bar.\n  baz"
  assert_format "foo \n . bar", "foo\n  .bar"
  assert_format "foo \n . bar \n . baz", "foo\n  .bar\n  .baz"
  assert_format "foo . bar \n . baz", "foo.bar\n   .baz"
  assert_format "foo . bar \n . baz \n . qux", "foo.bar\n   .baz\n   .qux"
  assert_format "foo . bar( x.y ) \n . baz \n . qux", "foo.bar(x.y)\n   .baz\n   .qux"
  assert_format "foo.bar 1, \n x: 1, \n y: 2", "foo.bar 1,\n        x: 1,\n        y: 2"

  # Blocks
  assert_format "foo   {   }", "foo { }"
  assert_format "foo   {  1 }", "foo { 1 }"
  assert_format "foo   {  1 ; 2 }", "foo { 1; 2 }"
  assert_format "foo   {  1 \n 2 }", "foo do\n  1\n  2\nend"
  assert_format "foo { \n  1 }", "foo do\n  1\nend"
  assert_format "begin \n foo   {  1  } \n end", "begin\n  foo { 1 }\nend"
  assert_format "foo   { | x , y | }", "foo { |x, y| }"
  assert_format "foo   { | ( x ) , z | }", "foo { |(x), z| }"
  assert_format "foo   { | ( x , y ) , z | }", "foo { |(x, y), z| }"
  assert_format "foo   { | ( x , ( y , w ) ) , z | }", "foo { |(x, (y, w)), z| }"
  assert_format "foo   { | bar: 1 , baz: 2 | }", "foo { |bar: 1, baz: 2| }"
  assert_format "foo   { | *z | }", "foo { |*z| }"
  assert_format "foo   { | **z | }", "foo { |**z| }"
  assert_format "foo   { | bar = 1 | }", "foo { |bar = 1| }"
  assert_format "foo   { | x , y | 1 }", "foo { |x, y| 1 }"
  assert_format "foo { | x | \n  1 }", "foo do |x|\n  1\nend"
  assert_format "foo { | x , \n y | \n  1 }", "foo do |x,\n        y|\n  1\nend"
  assert_format "foo   do   end", "foo do\nend"
  assert_format "foo   do 1  end", "foo do\n  1\nend"

  # Calls with receiver and block
  assert_format "foo.bar 1 do \n end", "foo.bar 1 do\nend"
  assert_format "foo::bar 1 do \n end", "foo::bar 1 do\nend"
  assert_format "foo.bar baz, 2 do \n end", "foo.bar baz, 2 do\nend"

  # Super
  assert_format "super"
  assert_format "super 1"
  assert_format "super 1, \n 2", "super 1,\n      2"
  assert_format "super( 1 )", "super(1)"
  assert_format "super( 1 , 2 )", "super(1, 2)"

  # Return
  assert_format "return"
  assert_format "return  1", "return 1"
  assert_format "return  1 , 2", "return 1, 2"
  assert_format "return  1 , \n 2", "return 1,\n       2"

  # Break
  assert_format "break"
  assert_format "break  1", "break 1"
  assert_format "break  1 , 2", "break 1, 2"
  assert_format "break  1 , \n 2", "break 1,\n      2"

  # Next
  assert_format "next"
  assert_format "next  1", "next 1"
  assert_format "next  1 , 2", "next 1, 2"
  assert_format "next  1 , \n 2", "next 1,\n     2"

  # Yield
  assert_format "yield"
  assert_format "yield  1", "yield 1"
  assert_format "yield  1 , 2", "yield 1, 2"
  assert_format "yield  1 , \n 2", "yield 1,\n      2"
  assert_format "yield( 1 , 2 )", "yield(1, 2)"

  # Array access
  assert_format "foo[ ]", "foo[]"
  assert_format "foo[ \n ]", "foo[]"
  assert_format "foo[ 1 ]", "foo[1]"
  assert_format "foo[ 1 , 2 , 3 ]", "foo[1, 2, 3]"
  assert_format "foo[ 1 , \n 2 , \n 3 ]", "foo[1,\n    2,\n    3]"
  assert_format "foo[ \n 1 , \n 2 , \n 3 ]", "foo[\n  1,\n  2,\n  3]"
  assert_format "foo[ *x ]", "foo[*x]"

  # Array setter
  assert_format "foo[ ]  =  1", "foo[] = 1"
  assert_format "foo[ 1 , 2 ]  =  3", "foo[1, 2] = 3"

  # Property setter
  assert_format "foo . bar  =  1", "foo.bar = 1"
  assert_format "foo . bar  = \n 1", "foo.bar =\n  1"
  assert_format "foo . \n bar  = \n 1", "foo.\n  bar =\n  1"

  # Range
  assert_format "1 .. 2", "1..2"
  assert_format "1 ... 2", "1...2"

  # Regex
  assert_format "//"
  assert_format "//ix"
  assert_format "/foo/"
  assert_format "/foo \#{1 + 2} /"
  assert_format "%r( foo )"

  # Unary operators
  assert_format "- x", "-x"
  assert_format "+ x", "+x"

  # Binary operators
  assert_format "1   +   2", "1 + 2"
  assert_format "1+2", "1 + 2"
  assert_format "1   +  \n 2", "1 +\n  2"
  assert_format "1   +  # hello \n 2", "1 + # hello\n  2"
  assert_format "1 +\n2+\n3", "1 +\n  2 +\n  3"
  assert_format "1  &&  2", "1 && 2"
  assert_format "1  ||  2", "1 || 2"
  assert_format "1*2", "1*2"
  assert_format "1* 2", "1*2"
  assert_format "1 *2", "1 * 2"
  assert_format "1/2", "1/2"
  assert_format "1**2", "1**2"

  # Class
  assert_format "class   Foo  \n  end", "class Foo\nend"
  assert_format "class   Foo  < Bar \n  end", "class Foo < Bar\nend"
  assert_format "class Foo\n\n1\n\nend", "class Foo\n  1\nend"
  assert_format "class Foo  ;  end", "class Foo; end"
  assert_format "class Foo; \n  end", "class Foo\nend"

  # Module
  assert_format "module   Foo  \n  end", "module Foo\nend"
  assert_format "module Foo ; end", "module Foo; end"

  # Semicolons and spaces
  assert_format "123;", "123"
  assert_format "1   ;   2", "1; 2"
  assert_format "1   ;  ;   2", "1; 2"
  assert_format "1  \n  2", "1\n2"
  assert_format "1  \n   \n  2", "1\n\n2"
  assert_format "1  \n ; ; ; \n  2", "1\n\n2"
  assert_format "1 ; \n ; \n ; ; \n  2", "1\n\n2"
  assert_format "123; # hello", "123 # hello"
  assert_format "1;\n2", "1\n2"
  assert_format "begin\n 1 ; 2 \n end", "begin\n  1; 2\nend"

  # begin/end
  assert_format "begin; end", "begin\nend"
  assert_format "begin; 1; end", "begin\n  1\nend"
  assert_format "begin\n 1 \n end", "begin\n  1\nend"
  assert_format "begin\n 1 \n 2 \n end", "begin\n  1\n  2\nend"
  assert_format "begin \n begin \n 1 \n end \n 2 \n end", "begin\n  begin\n    1\n  end\n  2\nend"
  assert_format "begin # hello\n end", "begin # hello\nend"
  assert_format "begin;# hello\n end", "begin # hello\nend"
  assert_format "begin\n 1  # a\nend", "begin\n  1 # a\nend"
  assert_format "begin\n 1  # a\n # b \n 3 # c \n end", "begin\n  1 # a\n  # b\n  3 # c\nend"
  assert_format "begin\nend\n\n# foo"

  # begin/rescue/end
  assert_format "begin \n 1 \n rescue \n 2 \n end", "begin\n  1\nrescue\n  2\nend"
  assert_format "begin \n 1 \n rescue   Foo \n 2 \n end", "begin\n  1\nrescue Foo\n  2\nend"
  assert_format "begin \n 1 \n rescue  =>   ex  \n 2 \n end", "begin\n  1\nrescue => ex\n  2\nend"
  assert_format "begin \n 1 \n rescue  Foo  =>  ex \n 2 \n end", "begin\n  1\nrescue Foo => ex\n  2\nend"
  assert_format "begin \n 1 \n rescue  Foo  , Bar , Baz =>  ex \n 2 \n end", "begin\n  1\nrescue Foo, Bar, Baz => ex\n  2\nend"
  assert_format "begin \n 1 \n rescue  Foo  , \n Bar , \n Baz =>  ex \n 2 \n end", "begin\n  1\nrescue Foo,\n       Bar,\n       Baz => ex\n  2\nend"
  assert_format "begin \n 1 \n ensure \n 2 \n end", "begin\n  1\nensure\n  2\nend"
  assert_format "begin \n 1 \n else \n 2 \n end", "begin\n  1\nelse\n  2\nend"

  # Parentheses
  assert_format "  ( 1 ) ", "(1)"
  assert_format "  ( 1 ; 2 ) ", "(1; 2)"

  # Method definition
  assert_format "  def   foo \n end", "def foo\nend"
  assert_format "  def   foo ; end", "def foo\nend"
  assert_format "  def   foo() \n end", "def foo\nend"
  assert_format "  def   foo ( \n ) \n end", "def foo\nend"
  assert_format "  def   foo ( x ) \n end", "def foo(x)\nend"
  assert_format "  def   foo ( x , y ) \n end", "def foo(x, y)\nend"
  assert_format "  def   foo x \n end", "def foo(x)\nend"
  assert_format "  def   foo x , y \n end", "def foo(x, y)\nend"
  assert_format "  def   foo \n 1 \n end", "def foo\n  1\nend"
  assert_format "  def   foo( * x ) \n 1 \n end", "def foo(*x)\n  1\nend"
  assert_format "  def   foo( a , * x ) \n 1 \n end", "def foo(a, *x)\n  1\nend"
  assert_format "  def   foo( a , * x, b ) \n 1 \n end", "def foo(a, *x, b)\n  1\nend"
  assert_format "  def   foo ( x  =  1 ) \n end", "def foo(x = 1)\nend"
  assert_format "  def   foo ( x  =  1, * y ) \n end", "def foo(x = 1, *y)\nend"
  assert_format "  def   foo ( & block ) \n end", "def foo(&block)\nend"
  assert_format "  def   foo ( a: , b: ) \n end", "def foo(a:, b:)\nend"
  assert_format "  def   foo ( a: 1 , b: 2  ) \n end", "def foo(a: 1, b: 2)\nend"
  assert_format "  def   foo ( x, \n y ) \n end", "def foo(x,\n        y)\nend"
  assert_format "  def   foo ( a: 1, \n b: 2 ) \n end", "def foo(a: 1,\n        b: 2)\nend"
  assert_format "  def   foo (\n x, \n y ) \n end", "def foo(\n        x,\n        y)\nend"
  assert_format "  def   foo ( a: 1, &block ) \n end", "def foo(a: 1, &block)\nend"
  assert_format "  def   foo ( a: 1, \n &block ) \n end", "def foo(a: 1,\n        &block)\nend"

  # Method definition with receiver
  assert_format " def foo . \n bar; end", "def foo.bar\nend"
  assert_format " def self . \n bar; end", "def self.bar\nend"

  # Array literal
  assert_format " [  ] ", "[]"
  assert_format " [  1 ] ", "[1]"
  assert_format " [  1 , 2 ] ", "[1, 2]"
  assert_format " [  1 , 2 , ] ", "[1, 2]"
  assert_format " [ \n 1 , 2 ] ", "[\n  1, 2,\n]"
  assert_format " [ \n 1 , 2, ] ", "[\n  1, 2,\n]"
  assert_format " [ \n 1 , 2 , \n 3 , 4 ] ", "[\n  1, 2,\n  3, 4,\n]"
  assert_format " [ \n 1 , \n 2] ", "[\n  1,\n  2,\n]"
  assert_format " [  # comment \n 1 , \n 2] ", "[ # comment\n  1,\n  2,\n]"
  assert_format " [ \n 1 ,  # comment  \n 2] ", "[\n  1, # comment\n  2,\n]"
  assert_format " [  1 , \n 2, 3, \n 4 ] ", "[1,\n 2, 3,\n 4]"
  assert_format " [  1 , \n 2, 3, \n 4, ] ", "[1,\n 2, 3,\n 4]"
  assert_format " [  1 , \n 2, 3, \n 4,\n ] ", "[1,\n 2, 3,\n 4]"
  assert_format " [  1 , \n 2, 3, \n 4, # foo \n ] ", "[1,\n 2, 3,\n 4 # foo\n]"
  assert_format " begin\n [ \n 1 , 2 ] \n end ", "begin\n  [\n    1, 2,\n  ]\nend"
  assert_format " [ \n 1 # foo\n ]", "[\n  1, # foo\n]"
  assert_format " [ *x ] ", "[*x]"
  assert_format " [ *x , 1 ] ", "[*x, 1]"
  assert_format " x = [{\n foo: 1\n}]", "x = [{\n  foo: 1,\n}]"
  assert_format " x = [{\n foo: 1\n}]", "x = [{\n  foo: 1,\n}]"

  # Array literal with %w
  assert_format " %w(  ) ", "%w()"
  assert_format " %w( one ) ", "%w(one)"
  assert_format " %w( one   two \n three ) ", "%w(one two\n  three)"
  assert_format " %w( \n one ) ", "%w(\n  one)"
  assert_format " %w( \n one \n ) ", "%w(\n  one\n  )"

  # Array literal with %i
  assert_format " %i(  ) ", "%i()"
  assert_format " %i( one ) ", "%i(one)"
  assert_format " %i( one   two \n three ) ", "%i(one two\n  three)"

  # Hash literal
  assert_format " { }", "{}"
  assert_format " { :foo   =>   1 }", "{:foo => 1}"
  assert_format " { :foo   =>   1 , 2  =>  3  }", "{:foo => 1, 2 => 3}"
  assert_format " { \n :foo   =>   1 ,\n 2  =>  3  }", "{\n  :foo => 1,\n  2    => 3,\n}"
  assert_format " { **x }", "{**x}"
  assert_format " { foo:  1 }", "{foo: 1}"
  assert_format " { :foo   => \n  1 }", "{:foo => 1}"

  # Lambdas
  assert_format "-> { } ", "->{ }"
  assert_format "-> {   1   } ", "->{ 1 }"
  assert_format "-> {   1 ; 2  } ", "->{ 1; 2 }"
  assert_format "-> {   1 \n 2  } ", "->{\n  1\n  2\n}"
  assert_format "-> do  1 \n 2  end ", "->do\n  1\n  2\nend"
  assert_format "-> ( x ){ } ", "->(x) { }"

  # class << self
  assert_format "class  <<  self \n 1 \n end", "class << self\n  1\nend"

  # Multiple classes, modules and methods are separated with two lines
  assert_format "def foo\nend\ndef bar\nend", "def foo\nend\n\ndef bar\nend"
  assert_format "class Foo\nend\nclass Bar\nend", "class Foo\nend\n\nclass Bar\nend"
  assert_format "module Foo\nend\nmodule Bar\nend", "module Foo\nend\n\nmodule Bar\nend"
  assert_format "1\ndef foo\nend", "1\n\ndef foo\nend"

  # Align successive comments
  assert_format "1 # one \n 123 # two", "1   # one\n123 # two"
  assert_format "1 # one \n 123 # two \n 4 \n 5 # lala", "1   # one\n123 # two\n4\n5 # lala"
  assert_format "foobar( # one \n 1 # two \n)", "foobar( # one\n  1     # two\n)"

  # Align successive assignments
  assert_format "x = 1 \n xyz = 2\n\n w = 3", "x   = 1\nxyz = 2\n\nw = 3"
  assert_format "x = 1 \n foo[bar] = 2\n\n w = 3", "x        = 1\nfoo[bar] = 2\n\nw = 3"
  assert_format "x = 1; x = 2 \n xyz = 2\n\n w = 3", "x = 1; x = 2\nxyz = 2\n\nw = 3"
  assert_format "a = begin\n b = 1 \n abc = 2 \n end", "a = begin\n  b   = 1\n  abc = 2\nend"
  assert_format "a = 1\n a += 2", "a  = 1\na += 2"
  assert_format "foo = 1\n a += 2", "foo = 1\na  += 2"

  # Align successive hash keys
  assert_format "{ \n 1 => 2, \n 123 => 4 }", "{\n  1   => 2,\n  123 => 4,\n}"
  assert_format "{ \n foo: 1, \n barbaz: 2 }", "{\n  foo:    1,\n  barbaz: 2,\n}"
  assert_format "foo bar: 1, \n barbaz: 2", "foo bar:    1,\n    barbaz: 2"
  assert_format "foo(\n  bar: 1, \n barbaz: 2)", "foo(\n  bar:    1,\n  barbaz: 2\n)"
  assert_format "def foo(x, \n y: 1, \n bar: 2)\nend", "def foo(x,\n        y:   1,\n        bar: 2)\nend"
  assert_format "{1 => 2}\n{123 => 4}"

  # Settings
  assert_format "begin \n 1 \n end", "begin\n    1\nend", indent_size: 4
  assert_format "1 # one\n 123 # two", "1 # one\n123 # two", align_comments: false
  assert_format "foo { \n  1 }", "foo {\n  1\n}", convert_brace_to_do: false
  assert_format "x = 1 \n xyz = 2\n\n w = 3", "x = 1\nxyz = 2\n\nw = 3", align_assignments: false
  assert_format "{ \n foo: 1, \n barbaz: 2 }", "{\n  foo: 1,\n  barbaz: 2,\n}", align_hash_keys: false
end
