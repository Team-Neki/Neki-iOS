//
//  QRCodeDumpDocumentWriter.swift
//  Neki-iOS
//
//  Created by SwainYun on 10/30/26.
//

import CoreFoundation
import Foundation

enum QRCodeDumpDocumentWriter {
    private static let bufferCapacity = 64 * 1_024

    static func write(
        sourceFileURL: URL,
        uploadFileURL: URL,
        sourceURL: URL,
        finalURL: URL,
        encodingName: String?,
        maximumOutputSize: Int64
    ) throws {
        let input = try FileHandle(forReadingFrom: sourceFileURL)
        let output = try FileHandle(forWritingTo: uploadFileURL)
        defer {
            try? input.close()
            try? output.close()
        }

        var comments = "<!-- source: \(sourceURL.absoluteString) -->\n"
        if finalURL != sourceURL {
            comments += "<!-- final: \(finalURL.absoluteString) -->\n"
        }
        var writtenByteCount: Int64 = 0
        try write(
            Data(comments.utf8),
            to: output,
            writtenByteCount: &writtenByteCount,
            maximumOutputSize: maximumOutputSize
        )

        let resolvedEncoding = try resolveEncoding(named: encodingName, input: input)
        try transcodeToUTF8(
            input: input,
            output: output,
            sourceEncoding: resolvedEncoding,
            writtenByteCount: &writtenByteCount,
            maximumOutputSize: maximumOutputSize
        )
        try output.synchronize()
    }
}

private extension QRCodeDumpDocumentWriter {
    static func resolveEncoding(named encodingName: String?, input: FileHandle) throws -> String.Encoding {
        guard let encodingName else { return .utf8 }
        guard let encoding = stringEncoding(forIANAName: encodingName) else {
            throw QRCodeDumpError.unsupportedStringEncoding
        }
        guard encoding != .utf8 else { return .utf8 }
        guard isStatelessEncodingName(encodingName) else {
            throw QRCodeDumpError.unsupportedStringEncoding
        }
        return try resolveByteOrder(for: encoding, input: input)
    }

    static func resolveByteOrder(for encoding: String.Encoding, input: FileHandle) throws -> String.Encoding {
        guard encoding == .utf16 || encoding == .utf32 else { return encoding }
        let byteOrderMark = try input.read(upToCount: 4) ?? Data()
        try input.seek(toOffset: 0)

        if encoding == .utf16 {
            if byteOrderMark.starts(with: [0xFF, 0xFE]) {
                try input.seek(toOffset: 2)
                return .utf16LittleEndian
            }
            if byteOrderMark.starts(with: [0xFE, 0xFF]) {
                try input.seek(toOffset: 2)
                return .utf16BigEndian
            }
        }
        if encoding == .utf32 {
            if byteOrderMark.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
                try input.seek(toOffset: 4)
                return .utf32LittleEndian
            }
            if byteOrderMark.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
                try input.seek(toOffset: 4)
                return .utf32BigEndian
            }
        }
        throw QRCodeDumpError.stringDecodingFailed
    }

    static func transcodeToUTF8(
        input: FileHandle,
        output: FileHandle,
        sourceEncoding: String.Encoding,
        writtenByteCount: inout Int64,
        maximumOutputSize: Int64
    ) throws {
        var pending = Data()

        while let chunk = try input.read(upToCount: bufferCapacity), chunk.isEmpty == false {
            try Task.checkCancellation()
            pending.append(chunk)
            let conversion = try decodeLargestPrefix(from: pending, encoding: sourceEncoding)
            try write(
                Data(conversion.string.utf8),
                to: output,
                writtenByteCount: &writtenByteCount,
                maximumOutputSize: maximumOutputSize
            )
            pending = conversion.remainder
        }

        guard pending.isEmpty else {
            try Task.checkCancellation()
            guard let string = String(data: pending, encoding: sourceEncoding) else {
                throw QRCodeDumpError.stringDecodingFailed
            }
            try write(
                Data(string.utf8),
                to: output,
                writtenByteCount: &writtenByteCount,
                maximumOutputSize: maximumOutputSize
            )
            return
        }
    }

    static func write(
        _ data: Data,
        to output: FileHandle,
        writtenByteCount: inout Int64,
        maximumOutputSize: Int64
    ) throws {
        let byteCount = Int64(data.count)
        guard byteCount <= maximumOutputSize - writtenByteCount else {
            throw QRCodeDumpError.responseTooLarge
        }
        try output.write(contentsOf: data)
        writtenByteCount += byteCount
    }

    static func decodeLargestPrefix(from data: Data, encoding: String.Encoding) throws -> (string: String, remainder: Data) {
        let maximumEncodedSequenceLength = 4
        let maximumRemainderLength = min(maximumEncodedSequenceLength - 1, data.count)

        for remainderLength in 0...maximumRemainderLength {
            let prefixEndIndex = data.index(data.endIndex, offsetBy: -remainderLength)
            let prefix = Data(data[..<prefixEndIndex])
            guard let string = String(data: prefix, encoding: encoding) else { continue }
            return (string, Data(data[prefixEndIndex...]))
        }
        throw QRCodeDumpError.stringDecodingFailed
    }

    static func isStatelessEncodingName(_ name: String) -> Bool {
        let normalizedName = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return normalizedName.contains("iso2022") == false &&
        normalizedName.hasPrefix("hz") == false &&
        normalizedName.contains("utf7") == false
    }

    static func stringEncoding(forIANAName name: String) -> String.Encoding? {
        let encoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard encoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
    }
}
