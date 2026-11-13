module fake_retriever
  use iso_fortran_env, only: real64
  use praxo_retriever, only: document
  implicit none
contains
  function provide(query, limit, count) result(documents)
    character(*), intent(in) :: query
    integer, intent(in) :: limit
    integer, intent(out) :: count
    type(document), allocatable :: documents(:)
    allocate(documents(1))
    documents(1)%id = 'doc-1'
    documents(1)%content = trim(query)//':'//int_text(limit)
    documents(1)%score = 0.5_real64
    count = 1
  end function

  function int_text(value) result(text)
    integer, intent(in) :: value
    character(:), allocatable :: text
    character(16) :: buffer
    write(buffer, '(i0)') value
    text = trim(buffer)
  end function
end module

program retriever_tests
  use iso_fortran_env, only: real64
  use praxo_types, only: sdk_error
  use praxo_retriever
  use fake_retriever
  implicit none
  type(retriever) :: value
  type(sdk_error) :: error
  type(document), allocatable :: documents(:)
  value = retriever_new(provide)
  documents = retrieve_documents(value, 'hello', 3, error)
  if (error%failed()) error stop 1
  if (size(documents) /= 1) error stop 2
  if (documents(1)%id /= 'doc-1') error stop 3
  if (documents(1)%content /= 'hello:3') error stop 4
  if (abs(documents(1)%score - 0.5_real64) > 1.0e-9_real64) error stop 5
end program
