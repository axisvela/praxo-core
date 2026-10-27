program json_tests
  use praxo_types
  use praxo_unicode
  use praxo_json
  implicit none
  type(json_document) :: doc, restored
  type(sdk_error) :: error
  character(:), allocatable :: text, encoded
  integer :: checks = 0, cursor, i
  integer, allocatable :: children(:)

  call parse_json('{"a":[true,false,null,-1.25e+2,{"b":"x,y"}]}', doc, error)
  call check(.not. error%failed(), 'nested JSON')
  call check(size(doc%nodes) == 8, 'node count')
  children = json_children(doc, json_get(doc, 1, 'a'))
  call check(size(children) == 5, 'array children')
  encoded = encode_json(doc, 1, error)
  call check(.not. error%failed(), 'nested encoding')
  call parse_json(encoded, restored, error)
  call check(json_equal(doc, 1, restored, 1), 'nested roundtrip')
  call parse_json('"\u4e2d\u6587 \ud83d\ude00"', doc, error)
  call check(.not. error%failed(), 'Unicode escapes')
  text = json_text(doc, 1)
  call check(unicode_length(text) == 4 .and. len(text) == 11, 'Unicode decoding')
  encoded = quote_json(text//achar(0)//' '//achar(10)//achar(92)//'"', error)
  call parse_json(encoded, doc, error)
  call check(.not. error%failed(), 'escaped controls roundtrip')
  call check(json_text(doc, 1) == text//achar(0)//' '//achar(10)//achar(92)//'"', 'byte preservation')
  call parse_json('{"a":1,"a":2}', doc, error)
  call check(json_text(doc, json_get(doc, 1, 'a')) == '2', 'duplicate key lookup uses last value')
  call check(json_get(doc, 0, 'x') == 0 .and. json_kind(doc, 999) == ' ', 'safe missing lookup')

  do i = 1, 22
    select case (i)
    case (1); text = '{}{}'
    case (2); text = '[1,]'
    case (3); text = '{"a":1,}'
    case (4); text = '{a:1}'
    case (5); text = '[01]'
    case (6); text = '[1.]'
    case (7); text = '[1e+]'
    case (8); text = '"\q"'
    case (9); text = '"\ud800"'
    case (10); text = '"\udc00"'
    case (11); text = '"\ud800\u0041"'
    case (12); text = '"\u00xz"'
    case (13); text = '[true false]'
    case (14); text = '{"a" 1}'
    case (15); text = '{"a":}'
    case (16); text = '[}'
    case (17); text = '"unterminated'
    case (18); text = ''
    case (19); text = '"'//char(192)//char(128)//'"'
    case (20); text = '"'//char(237)//char(160)//char(128)//'"'
    case (21); text = '"'//char(244)//char(144)//char(128)//char(128)//'"'
    case (22); text = '"'//achar(10)//'"'
    end select
    call parse_json(text, doc, error)
    call check(error%failed(), 'malformed input rejection')
    call check(size(doc%nodes) == 0, 'failed parse exposes no nodes')
  end do
  encoded = quote_json(char(255), error)
  call check(error%failed() .and. encoded == '', 'invalid UTF8 cannot be encoded')
  call parse_json(repeat('[', 65)//repeat(']', 65), doc, error)
  call check(string_value(error%code) == 'JSON_CAPACITY', 'nesting limit')
  call parse_json('['//repeat('0,', 4096)//'0]', doc, error)
  call check(string_value(error%code) == 'JSON_CAPACITY', 'node limit')
  cursor = 1
  call decode_json_string('"x" tail', cursor, text, error)
  call check(text == 'x' .and. cursor == 4, 'string decoder cursor')
  print '(a,i0,a)', 'PASS: ', checks, ' native Fortran JSON assertions'
contains
  subroutine check(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    checks = checks + 1
    if (ok) return
    print '(a)', 'FAIL: '//label
    error stop 1
  end subroutine
end program
