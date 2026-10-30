#include "re2_bridge.h"

#include <cstring>

int main() {
  if (praxo_re2_match(nullptr, 0, nullptr, 0) != 1) return 1;
  if (praxo_re2_match(nullptr, 1, "a", 1) != 4) return 2;
  if (praxo_re2_match("a", 1, nullptr, 1) != 4) return 3;
  if (praxo_re2_match("a", 4097, "a", 1) != 3) return 4;
  if (praxo_re2_match("a", 1, "a", 262145) != 3) return 5;
  if (praxo_re2_match("(", 1, "a", 1) != 2) return 6;
  const char pattern[] = {'^', 'a', '\0', 'b', '$'};
  const char text[] = {'a', '\0', 'b'};
  if (praxo_re2_match(pattern, sizeof(pattern), text, sizeof(text)) != 1) return 7;
  const char *unicode_pattern = "^\\p{Han}{2}$";
  const char han[] = "\xe4\xbd\xa0\xe5\xa5\xbd";
  if (praxo_re2_match(unicode_pattern, std::strlen(unicode_pattern), han, sizeof(han) - 1) != 1) return 8;
  return 0;
}
