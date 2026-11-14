program structured_output_example
  use praxo_types
  use praxo_schema
  implicit none
  type(validation_error), allocatable :: errors(:)
  type(sdk_error) :: error
  character(*), parameter :: schema_json = &
    '{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}'

  call validate_schema(schema_json, '{"name":"ok"}', errors, error)
  if (error%failed() .or. size(errors) /= 0) stop 1

  call validate_schema(schema_json, '{}', errors, error)
  if (error%failed() .or. size(errors) == 0) stop 1

  print '(a)', 'Fortran structured output example passed'
end program
