module praxo_plugin
  use iso_fortran_env, only: real64
  use praxo_types
  use praxo_json
  implicit none
  private
  public :: plugin_manifest, parse_manifest

  type :: plugin_manifest
    character(:), allocatable :: id, version, kind, protocol, isolation
    type(json_document) :: document
  end type
contains
  subroutine parse_manifest(raw, manifest, error)
    character(*), intent(in) :: raw
    type(plugin_manifest), intent(out) :: manifest
    type(sdk_error), intent(out) :: error
    type(json_document) :: doc
    integer :: entry, caps, permissions, limits, health, signature, node, i, j, section
    integer, allocatable :: children(:), list(:)
    real(real64) :: number
    character(:), allocatable :: entry_type, required, text
    logical :: ok
    error%code = 'PLUGIN_INVALID'
    block
      type(sdk_error) :: parsing
      call parse_json(raw, doc, parsing)
      if (parsing%failed()) return
    end block
    if (.not. keys(1, '|schemaVersion|id|version|kind|entrypoint|protocol|capabilities|'// &
      'permissions|limits|health|isolation|signature|sbom|')) return
    number = json_real(doc, json_get(doc, 1, 'schemaVersion'), ok)
    if (.not. ok .or. abs(number - 1) > 0) return
    if (.not. same_string(json_text(doc, json_get(doc, 1, 'schemaVersion')), '1')) return
    if (.not. dns(string_field(1, 'id'))) return
    if (.not. semver(string_field(1, 'version'))) return
    text = string_field(1, 'kind')
    if (len(text) /= len_trim(text)) return
    select case (text)
    case ('tool.provider.v1', 'model.provider.v1', 'policy.provider.v1', 'memory.provider.v1', 'sandbox.provider.v1')
    case default
      return
    end select
    if (.not. same_string(string_field(1, 'protocol'), 'jsonrpc-2')) return
    entry = json_get(doc, 1, 'entrypoint')
    if (.not. keys(entry, '|type|command|module|image|args|dir|')) return
    entry_type = string_field(entry, 'type')
    if (len(entry_type) /= len_trim(entry_type)) return
    select case (entry_type)
    case ('process'); required = 'command'
    case ('wasm'); required = 'module'
    case ('container'); required = 'image'
    case default; return
    end select
    if (len(string_field(entry, required)) == 0) return
    if (.not. same_string(string_field(1, 'isolation'), entry_type)) return
    children = json_children(doc, entry)
    do i = 1, size(children)
      if (doc%nodes(children(i))%name == 'args') then
        if (.not. string_array(children(i))) return
      else
        if (json_kind(doc, children(i)) /= 'S') return
      end if
    end do
    caps = json_get(doc, 1, 'capabilities')
    if (caps /= 0) then
      if (.not. string_array(caps)) return
      children = json_children(doc, caps)
      do i = 1, size(children)
        if (len(json_text(doc, children(i))) == 0) return
        do j = 1, i - 1
          if (same_string(json_text(doc, children(i)), json_text(doc, children(j)))) return
        end do
      end do
    end if
    permissions = json_get(doc, 1, 'permissions')
    if (permissions /= 0) then
      if (.not. keys(permissions, '|filesystem|network|env|')) return
      children = json_children(doc, permissions)
      do i = 1, size(children)
        node = children(i)
        if (doc%nodes(node)%name == 'env') then
          if (.not. string_array(node)) return
          list = json_children(doc, node)
          do j = 1, size(list)
            if (.not. env_name(json_text(doc, list(j)))) return
          end do
          cycle
        end if
        if (json_kind(doc, node) /= 'A') return
        list = json_children(doc, node)
        do j = 1, size(list)
          if (doc%nodes(node)%name == 'filesystem') then
            if (.not. keys(list(j), '|path|mode|')) return
            if (len(string_field(list(j), 'path')) == 0) return
            text = string_field(list(j), 'mode')
            if (text /= 'read' .and. text /= 'write' .and. text /= 'readwrite') return
          else
            if (.not. keys(list(j), '|host|port|')) return
            if (len(string_field(list(j), 'host')) == 0) return
            number = json_real(doc, json_get(doc, list(j), 'port'), ok)
            if (.not. ok) return
            if (number < 1 .or. number > 65535 .or. abs(number - aint(number)) > 0) return
          end if
        end do
      end do
    end if
    limits = json_get(doc, 1, 'limits')
    health = json_get(doc, 1, 'health')
    do section = 1, 2
      node = limits
      if (section == 2) node = health
      if (node == 0) cycle
      if (section == 1) then
        if (.not. keys(node, '|memoryMB|cpuMillis|timeoutMs|maxInflight|')) return
      else
        if (.not. keys(node, '|method|intervalMs|')) return
      end if
      children = json_children(doc, node)
      do i = 1, size(children)
        if (doc%nodes(children(i))%name == 'method') then
          if (json_kind(doc, children(i)) /= 'S') return
        else
          number = json_real(doc, children(i), ok)
          if (.not. ok) return
          if (number < 0 .or. abs(number - aint(number)) > 0) return
        end if
      end do
    end do
    node = json_get(doc, health, 'intervalMs')
    if (node > 0) then
      number = json_real(doc, node, ok)
      if (number > 0 .and. string_field(health, 'method') == '') return
    end if
    signature = json_get(doc, 1, 'signature')
    if (signature > 0 .and. json_kind(doc, signature) /= 'Z') then
      if (.not. keys(signature, '|algorithm|keyId|')) return
      if (len(string_field(signature, 'algorithm')) == 0 .or. len(string_field(signature, 'keyId')) == 0) return
    end if
    node = json_get(doc, 1, 'sbom')
    if (node > 0) then
      if (json_kind(doc, node) /= 'S') return
      text = json_text(doc, node)
      do i = 1, len(text)
        if (text(i:i) == achar(92)) text(i:i) = '/'
      end do
      if (len(text) > 0) then
        if (text(1:1) == '/' .or. index(text, ':') > 0) return
        if (index('/'//text//'/', '/../') > 0) return
      end if
    end if
    manifest%id = string_field(1, 'id')
    manifest%version = string_field(1, 'version')
    manifest%kind = string_field(1, 'kind')
    manifest%protocol = 'jsonrpc-2'
    manifest%isolation = entry_type
    manifest%document = doc
    deallocate(error%code)
  contains
    logical function keys(parent, allowed) result(valid)
      integer, intent(in) :: parent
      character(*), intent(in) :: allowed
      integer, allocatable :: entries(:)
      integer :: k
      valid = .false.
      if (json_kind(doc, parent) /= 'O') return
      entries = json_children(doc, parent)
      do k = 1, size(entries)
        if (index(allowed, '|'//doc%nodes(entries(k))%name//'|') == 0) return
        if (index(doc%nodes(entries(k))%name, '|') > 0) return
      end do
      valid = .true.
    end function

    function string_field(parent, key) result(value)
      integer, intent(in) :: parent
      character(*), intent(in) :: key
      character(:), allocatable :: value
      integer :: index
      index = json_get(doc, parent, key)
      value = ''
      if (json_kind(doc, index) == 'S') value = json_text(doc, index)
    end function

    logical function string_array(parent) result(valid)
      integer, intent(in) :: parent
      integer, allocatable :: entries(:)
      integer :: k
      valid = .false.
      if (json_kind(doc, parent) /= 'A') return
      entries = json_children(doc, parent)
      do k = 1, size(entries)
        if (json_kind(doc, entries(k)) /= 'S') return
      end do
      valid = .true.
    end function
  end subroutine

  logical function dns(text) result(valid)
    character(*), intent(in) :: text
    integer :: i, first
    valid = .false.
    if (len(text) < 3 .or. index(text, '.') == 0) return
    first = 1
    do i = 1, len(text) + 1
      if (i <= len(text)) then
        if (index('abcdefghijklmnopqrstuvwxyz0123456789-.', text(i:i)) == 0) return
        if (text(i:i) /= '.') cycle
      end if
      if (i == first) return
      if (text(first:first) == '-' .or. text(i - 1:i - 1) == '-') return
      first = i + 1
    end do
    valid = .true.
  end function

  logical function semver(text) result(valid)
    character(*), intent(in) :: text
    integer :: cursor, first, part
    valid = .false.
    cursor = 1
    do part = 1, 3
      first = cursor
      do while (cursor <= len(text))
        if (text(cursor:cursor) < '0' .or. text(cursor:cursor) > '9') exit
        cursor = cursor + 1
      end do
      if (cursor == first) return
      if (cursor - first > 1 .and. text(first:first) == '0') return
      if (part == 3) exit
      if (cursor > len(text)) return
      if (text(cursor:cursor) /= '.') return
      cursor = cursor + 1
    end do
    if (cursor <= len(text)) then
      if (text(cursor:cursor) == '-') then
        cursor = cursor + 1
        first = cursor
        do while (cursor <= len(text))
          if (text(cursor:cursor) == '+') exit
          if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-', text(cursor:cursor)) == 0) return
          cursor = cursor + 1
        end do
        if (cursor == first) return
      end if
      if (cursor <= len(text)) then
        if (text(cursor:cursor) /= '+') return
        cursor = cursor + 1
        first = cursor
        do while (cursor <= len(text))
          if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-', text(cursor:cursor)) == 0) return
          cursor = cursor + 1
        end do
        if (cursor == first) return
      end if
    end if
    valid = cursor > len(text)
  end function

  logical function env_name(text) result(valid)
    character(*), intent(in) :: text
    integer :: i
    valid = .false.
    if (len(text) == 0) return
    if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_', text(1:1)) == 0) return
    do i = 2, len(text)
      if (index('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_', text(i:i)) == 0) return
    end do
    valid = .true.
  end function
end module
