#include "praxo.h"

#include <string.h>

bool px_equals(const PxValue *left, const PxValue *right) {
    if (left == NULL || right == NULL) {
        return left == right;
    }
    if (left->type != right->type) {
        return false;
    }
    switch (left->type) {
        case PX_NULL:
            return true;
        case PX_BOOL:
            return left->as.boolean == right->as.boolean;
        case PX_NUM:
            return left->as.number == right->as.number;
        case PX_STR:
            return strcmp(left->as.string, right->as.string) == 0;
        case PX_ARR:
            if (left->as.array.len != right->as.array.len) {
                return false;
            }
            for (size_t index = 0; index < left->as.array.len; index++) {
                if (!px_equals(left->as.array.items[index],
                               right->as.array.items[index])) {
                    return false;
                }
            }
            return true;
        case PX_OBJ:
            if (left->as.object.len != right->as.object.len) {
                return false;
            }
            for (size_t index = 0; index < left->as.object.len; index++) {
                PxPair *pair = &left->as.object.pairs[index];
                if (!px_equals(pair->value, px_obj_get(right, pair->key))) {
                    return false;
                }
            }
            return true;
    }
    return false;
}
