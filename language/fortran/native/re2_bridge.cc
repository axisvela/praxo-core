#include "re2_bridge.h"

#include <new>
#include <string_view>
#include "re2/re2.h"

extern "C" int praxo_re2_match(const char *pattern, size_t pattern_size,
                               const char *text, size_t text_size) {
  if (pattern_size > 4096 || text_size > 262144) return 3;
  if ((!pattern && pattern_size) || (!text && text_size)) return 4;
  try {
    RE2::Options options;
    options.set_encoding(RE2::Options::EncodingUTF8);
    options.set_log_errors(false);
    options.set_max_mem(8 * 1024 * 1024);
    RE2 expression(std::string_view(pattern ? pattern : "", pattern_size), options);
    if (!expression.ok()) {
      return expression.error_code() == RE2::ErrorPatternTooLarge ? 3 : 2;
    }
    return RE2::PartialMatch(std::string_view(text ? text : "", text_size), expression) ? 1 : 0;
  } catch (const std::bad_alloc &) {
    return 3;
  } catch (...) {
    return 4;
  }
}
