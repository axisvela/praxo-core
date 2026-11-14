program checkpoint_example
  use praxo_types
  use praxo_checkpoint
  implicit none
  type(checkpoint_allowlist) :: allow
  type(sdk_error) :: error
  character(:), allocatable :: envelope, value

  call allow%register('order', error)
  if (error%failed()) stop 1
  envelope = allow%marshal('order', '{"value":"x"}', error)
  if (error%failed()) stop 1
  value = allow%unmarshal(envelope, error)
  if (error%failed() .or. value /= '{"value":"x"}') stop 1

  envelope = allow%marshal('missing', '{}', error)
  if (string_value(error%code) /= 'CHECKPOINT_TYPE_NOT_ALLOWED') stop 1

  print '(a)', 'Fortran checkpoint example passed'
end program
