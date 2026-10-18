#ifndef TT_INFLATE_H
#define TT_INFLATE_H

#include <stdint.h>

int32_t tt_inflate_raw(const uint8_t *src, int32_t src_len, uint8_t *dst, int32_t dst_len);

#endif
