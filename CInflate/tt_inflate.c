#include "tt_inflate.h"

#include <string.h>
#include <zlib.h>

int32_t tt_inflate_raw(const uint8_t *src, int32_t src_len, uint8_t *dst, int32_t dst_len) {
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit2(&stream, -15) != Z_OK) {
        return -1;
    }
    stream.next_in = (Bytef *)src;
    stream.avail_in = (uInt)src_len;
    stream.next_out = dst;
    stream.avail_out = (uInt)dst_len;
    int rc = inflate(&stream, Z_FINISH);
    uLong written = stream.total_out;
    inflateEnd(&stream);
    if (rc != Z_STREAM_END) {
        return -1;
    }
    return (int32_t)written;
}
