//
//  Gunzip.swift
//  C2
//
//  Created by Kota on 2/8/18.
//
import Foundation
import Compression
internal class Gunzip {
	enum ErrorCases: Error {
		case magic
		case method
		case lessdata
		case stream
		case no(feature: String)
	}
	let cache: Data
	let whole: Data
	var stream: compression_stream
	var buffer: Data
	init(url: URL, options: Data.ReadingOptions = .alwaysMapped, cache bytes: Int = 65536) throws {
		
		let data = try Data(contentsOf: url, options: options)
		
		do {
			var seek: Int = 0
			
			let magic: UInt16 = data.advanced(by: seek).toValue()
			guard magic == 0x8b1f else { throw ErrorCases.magic }
			seek += MemoryLayout.size(ofValue: magic)
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			let method: UInt8 = data.advanced(by: seek).toValue()
			guard method == 0x8 else { throw ErrorCases.method }
			seek += MemoryLayout.size(ofValue: method)
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			let flags: UInt8 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: flags)
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			let time: UInt32 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: time)
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			let extra: UInt8 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: extra)
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			let os: UInt8 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: os)
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			guard 0 == ( flags & ( 1 << 1 ) ) else {
				throw ErrorCases.no(feature: "multipart")
			}
			
			let field: Data = 0 == ( flags & ( 1 << 2 ) ) ? Data() : data.advanced(by: seek).toBuffer(size: UInt16.self)
			seek += 0 == ( flags & ( 1 << 2 ) ) ? 0 : ( field.count + MemoryLayout<UInt16>.size )
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			guard seek < data.count else { throw ErrorCases.lessdata }
			let original: String = 0 == ( flags & ( 1 << 3 ) ) ? "" : data.advanced(by: seek).toString()
			seek += 0 == ( flags & ( 1 << 3 ) ) ? 0 : ( original.count + 1 )
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			guard seek < data.count else { throw ErrorCases.lessdata }
			let comment: String = 0 == ( flags & ( 1 << 4 ) ) ? "" : data.advanced(by: seek).toString()
			seek += 0 == ( flags & ( 1 << 4 ) ) ? 0 : ( comment.count + 1 )
			guard seek < data.count else { throw ErrorCases.lessdata }
			
			cache = Data(count: bytes)
			whole = data.advanced(by: seek)
			
			buffer = Data()
			stream = compression_stream(dst_ptr: cache.withUnsafeBytes{UnsafeMutablePointer(mutating: $0)}, dst_size: cache.count, src_ptr: whole.withUnsafeBytes{$0}, src_size: whole.count, state: nil)
			
			guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
				throw ErrorCases.stream
			}
		}
	}
	deinit {
		guard compression_stream_destroy(&stream) == COMPRESSION_STATUS_OK else {
			fatalError()
		}
	}
}
extension Gunzip: Supplier {
	func readValue<T: Strideable>() throws -> T {
		return try readData(count: MemoryLayout<T>.stride).withUnsafeBytes {
			$0.pointee
		}
	}
	func readArray<T: Strideable>(count: Int) throws -> [T] {
		return try readData(count: MemoryLayout<T>.stride * count).withUnsafeBytes {
			Array(UnsafeBufferPointer(start: $0, count: count))
		}
	}
	func readData(count: Int) throws -> Data {
		loop: while buffer.count < count {
			stream.dst_ptr = cache.withUnsafeBytes { UnsafeMutablePointer(mutating: $0) }
			stream.dst_size = cache.count
			switch compression_stream_process(&stream, 0) {
			case COMPRESSION_STATUS_OK:
				buffer.append(cache)
			case COMPRESSION_STATUS_END:
				buffer.append(cache.subdata(in: cache.startIndex..<cache.endIndex.advanced(by: -stream.dst_size)))
				if buffer.count < count {
					throw ErrorCases.lessdata
				}
				break loop
			case COMPRESSION_STATUS_ERROR:
				throw ErrorCases.stream
			default:
				fatalError()
			}
		}
		defer {
			buffer.removeSubrange(0..<count)
		}
		return buffer.subdata(in: buffer.startIndex..<buffer.startIndex.advanced(by: count))
	}
	func reset() {
		stream.src_ptr = whole.withUnsafeBytes { $0 }
		stream.src_size = whole.count
	}
}
