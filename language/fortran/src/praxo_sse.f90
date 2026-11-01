module praxo_sse
  use praxo_types, only: sdk_error
  use praxo_json
  implicit none
  private
  public :: parse_sse_stream

contains
  subroutine parse_sse_stream(text, content, error)
    character(*), intent(in) :: text
    character(:), allocatable, intent(out) :: content
    type(sdk_error), intent(out) :: error
    type(json_document) :: doc
    character(:), allocatable :: line, chunk
    integer :: start, finish, newline, i
    logical :: done

    content = ''
    error%code = ''
    done = .false.
    start = 1
    do while (start <= len(text) .and. .not. error%failed() .and. .not. done)
      newline = index(text(start:), achar(10))
      if (newline == 0) then
        finish = len(text) + 1
      else
        finish = start + newline - 1
      end if
      if (finish > start) then
        line = text(start:finish - 1)
      else
        line = ''
      end if
      line = trim(line)
      if (len_trim(line) > 0) then
        if (len_trim(line) > 1 .and. &
            line(len_trim(line):len_trim(line)) == achar(13)) then
          line = line(:len_trim(line) - 1)
        end if
        if (len(line) >= 5 .and. line(1:5) == 'data:') then
          if (len(line) > 5) then
            chunk = trim(adjustl(line(6:)))
          else
            chunk = ''
          end if
          if (len_trim(chunk) > 0) then
            if (trim(chunk) == '[DONE]') then
              done = .true.
            else
              call parse_json(trim(chunk), doc, error)
              if (error%failed()) then
                error%code = 'MODEL_STREAM'
              else
                do i = 1, size(doc%nodes)
                  if (allocated(doc%nodes(i)%name)) then
                    if (doc%nodes(i)%name == 'content' .and. json_kind(doc, i) == 'S') then
                      content = content // json_text(doc, i)
                    end if
                    if (doc%nodes(i)%name == 'finish_reason' .and. json_kind(doc, i) /= 'Z') then
                      done = .true.
                    end if
                  end if
                end do
              end if
            end if
          end if
        end if
      end if
      if (newline == 0) exit
      start = finish + 1
    end do

    if (.not. error%failed() .and. .not. done) error%code = 'MODEL_STREAM'
  end subroutine
end module
