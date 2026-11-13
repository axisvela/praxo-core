module praxo_retriever
  use iso_fortran_env, only: real64
  use praxo_types, only: sdk_error
  implicit none
  private
  public :: document, retriever_fn, retriever, retriever_new, retrieve_documents

  type :: document
    character(:), allocatable :: id
    character(:), allocatable :: content
    real(real64) :: score = 0
  end type

  abstract interface
    function retriever_fn(query, limit, count) result(documents)
      import document
      character(*), intent(in) :: query
      integer, intent(in) :: limit
      integer, intent(out) :: count
      type(document), allocatable :: documents(:)
    end function
  end interface

  type :: retriever
    procedure(retriever_fn), pointer, nopass :: retrieve => null()
  end type
contains
  function retriever_new(fn) result(value)
    procedure(retriever_fn) :: fn
    type(retriever) :: value
    value%retrieve => fn
  end function

  function retrieve_documents(self, query, limit, error) result(documents)
    type(retriever), intent(in) :: self
    character(*), intent(in) :: query
    integer, intent(in) :: limit
    type(sdk_error), intent(out) :: error
    type(document), allocatable :: documents(:)
    integer :: count
    error%code = ''
    allocate(documents(0))
    if (.not. associated(self%retrieve)) then
      error%code = 'RETRIEVER_INVALID'
      return
    end if
    if (limit < 0) then
      error%code = 'RETRIEVER_INVALID'
      return
    end if
    documents = self%retrieve(query, limit, count)
  end function
end module
