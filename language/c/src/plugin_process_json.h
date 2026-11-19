static int px_escape(char **cursor, const char *end, const char *value) {
    if (value == NULL) value = "";
    for (const unsigned char *p = (const unsigned char *)value; *p; p++) {
        if (*cursor + 8 >= end) return 0;
        switch (*p) {
        case '"': *(*cursor)++ = '\\'; *(*cursor)++ = '"'; break;
        case '\\': *(*cursor)++ = '\\'; *(*cursor)++ = '\\'; break;
        case '\n': *(*cursor)++ = '\\'; *(*cursor)++ = 'n'; break;
        case '\r': *(*cursor)++ = '\\'; *(*cursor)++ = 'r'; break;
        case '\t': *(*cursor)++ = '\\'; *(*cursor)++ = 't'; break;
        default:
            if (*p < 0x20)
                (*cursor) += snprintf(*cursor, (size_t)(end - *cursor),
                    "\\u%04x", *p);
            else
                *(*cursor)++ = (char)*p;
            break;
        }
    }
    return 1;
}
