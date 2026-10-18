//
//  TTPresArchive.swift
//  TTPlayer for macOS
//
//  ttpres.dll 里每张图和每份 XML 都是一段 zip 本地头。同名文件保留先出现的那份。
//

import AppKit
import CInflate
import Foundation

enum TTPresArchive {
    static func extract(from url: URL) -> [String: Data] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        var files: [String: Data] = [:]
        var cursor = 0
        let bytes = [UInt8](data)
        let marker: [UInt8] = [0x50, 0x4B, 0x03, 0x04]

        while cursor + 30 < bytes.count {
            guard let index = indexOf(marker, in: bytes, from: cursor) else { break }
            let method = int16(bytes, index + 8)
            let compressed = int32(bytes, index + 18)
            let uncompressed = int32(bytes, index + 22)
            let nameLength = int16(bytes, index + 26)
            let extraLength = int16(bytes, index + 28)
            let nameStart = index + 30
            let dataStart = nameStart + nameLength + extraLength
            guard nameLength > 0, dataStart + compressed <= bytes.count else { break }

            let name = String(bytes: bytes[nameStart..<nameStart + nameLength], encoding: .utf8)
                ?? String(bytes: bytes[nameStart..<nameStart + nameLength], encoding: .isoLatin1)
                ?? ""
            let blob = Data(bytes[dataStart..<dataStart + compressed])
            if files[name] == nil {
                if method == 0 {
                    files[name] = blob
                } else if method == 8, let raw = inflate(blob, expected: uncompressed) {
                    files[name] = raw
                }
            }
            cursor = dataStart + max(compressed, 1)
        }
        return files
    }

    private static func inflate(_ source: Data, expected: Int) -> Data? {
        guard expected > 0 else { return Data() }
        var output = Data(count: expected)
        let written: Int32 = source.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                tt_inflate_raw(
                    src.bindMemory(to: UInt8.self).baseAddress,
                    Int32(src.count),
                    dst.bindMemory(to: UInt8.self).baseAddress,
                    Int32(dst.count)
                )
            }
        }
        guard written == expected else { return nil }
        return output
    }

    private static func indexOf(_ needle: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard needle.count > 0, start < bytes.count else { return nil }
        var index = start
        while index + needle.count <= bytes.count {
            if bytes[index] == needle[0], Array(bytes[index..<index + needle.count]) == needle {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func int16(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
    }

    private static func int32(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset])
            | (Int(bytes[offset + 1]) << 8)
            | (Int(bytes[offset + 2]) << 16)
            | (Int(bytes[offset + 3]) << 24)
    }
}

enum BMPDecoder {
    /// 24/32 位 BMP。洋红透明色变成全透明，方便圆角镂空。
    static func image(from data: Data, colorKey: NSColor) -> NSImage? {
        guard data.count > 54, data[0] == 0x42, data[1] == 0x4D else { return nil }
        let offset = int32(data, 10)
        let width = int32(data, 18)
        var height = int32(data, 22)
        let topDown = height < 0
        height = abs(height)
        let bpp = int16(data, 28)
        guard width > 0, height > 0, bpp == 24 || bpp == 32 else { return nil }

        let key = rgb(colorKey)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let stride = ((width * (bpp / 8) + 3) / 4) * 4
        guard offset + stride * height <= data.count else { return nil }

        // NSBitmapImageRep 的第一行画在底部，和 BMP 自下而上的存法一致。
        for y in 0..<height {
            let sourceY = topDown ? (height - 1 - y) : y
            let row = offset + sourceY * stride
            for x in 0..<width {
                let index = row + x * (bpp / 8)
                let b = data[index]
                let g = data[index + 1]
                let r = data[index + 2]
                let a: UInt8
                if bpp == 32 {
                    a = data[index + 3]
                } else if r == key.r && g == key.g && b == key.b {
                    a = 0
                } else {
                    a = 255
                }
                let dest = (y * width + x) * 4
                pixels[dest] = r
                pixels[dest + 1] = g
                pixels[dest + 2] = b
                pixels[dest + 3] = a
            }
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let buffer = rep.bitmapData else { return nil }

        pixels.withUnsafeBytes { raw in
            buffer.update(from: raw.bindMemory(to: UInt8.self).baseAddress!, count: pixels.count)
        }
        rep.size = NSSize(width: width, height: height)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    private static func rgb(_ color: NSColor) -> (r: UInt8, g: UInt8, b: UInt8) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        return (
            UInt8(round(converted.redComponent * 255)),
            UInt8(round(converted.greenComponent * 255)),
            UInt8(round(converted.blueComponent * 255))
        )
    }

    private static func int16(_ data: Data, _ offset: Int) -> Int {
        Int(data[offset]) | (Int(data[offset + 1]) << 8)
    }

    private static func int32(_ data: Data, _ offset: Int) -> Int {
        Int(data[offset])
            | (Int(data[offset + 1]) << 8)
            | (Int(data[offset + 2]) << 16)
            | (Int(data[offset + 3]) << 24)
    }
}
