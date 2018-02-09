//
//  Gunzip.swift
//  C2
//
//  Created by Kota on 2/8/18.
//
import Foundation
import Compression
private extension Data {
	func gunzip(to: OutputStream, with: Int) throws {
		try withUnsafeBytes { (src: UnsafePointer<UInt8>) in
			let src_size: Int = count
			let src_ptr: UnsafePointer<UInt8> = src
			let dst_size: Int = with
			let dst_ptr: UnsafeMutablePointer<UInt8> = .allocate(capacity: dst_size)
			var stream: compression_stream = compression_stream(dst_ptr: dst_ptr, dst_size: dst_size, src_ptr: src, src_size: src_size, state: nil)
			guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
				return
			}
			defer {
				compression_stream_destroy(&stream)
			}
			repeat {
				stream.dst_ptr = dst_ptr
				stream.dst_size = dst_size
				switch compression_stream_process(&stream, 0) {
				case COMPRESSION_STATUS_OK:
					let total: Int = dst_size - stream.dst_size
					guard 0 < total, try to.send(buffer: dst_ptr, count: total) == total else {
						throw "fail"
					}
				case COMPRESSION_STATUS_END:
					let total: Int = dst_size - stream.dst_size
					guard 0 < total, try to.send(buffer: dst_ptr, count: total) == total else {
						throw "fail"
					}
					return
				case COMPRESSION_STATUS_ERROR:
					throw "error"
				default:
					fatalError()
				}
			} while stream.dst_size < dst_size
		}
	}
}
private extension OutputStream {
	func send(buffer: UnsafePointer<UInt8>, count: Int) throws -> Int {
		let done: Int = write(buffer, maxLength: count)
		guard 0 < done else {
			throw "stream closed"
		}
		if done < count {
			return try done + send(buffer: buffer.advanced(by: done), count: count - done)
		} else {
			return done
		}
	}
}
private extension Stream {
	class func makefifo(maximum: Int) throws -> (InputStream, OutputStream) {
		var i: InputStream?
		var o: OutputStream?
		getBoundStreams(withBufferSize: maximum, inputStream: &i, outputStream: &o)
		guard let iStream: InputStream = i, let oStream: OutputStream = o else {
			throw "stream"
		}
		return (iStream, oStream)
	}
}
class Gunzip {
	let stream: InputStream
	let nslock: NSLock
	let thread: Thread
	let reader: Data
	var buffer: Data
	init(url: URL, options: Data.ReadingOptions = .mappedRead, maximum: Int = 65536) throws {
		let(ist, ost): (InputStream, OutputStream) = try Stream.makefifo(maximum: 2 * maximum)
		do {
			let data = try Data(contentsOf: url, options: options)
			var seek: Int = 0
			
			let magic: UInt16 = data.advanced(by: seek).toValue()
			guard magic == 0x8b1f else { throw "invalid magic" }
			seek += MemoryLayout.size(ofValue: magic)
			guard seek < data.count else { throw "less data" }
			
			let method: UInt8 = data.advanced(by: seek).toValue()
			guard method == 0x8 else { throw "invalid method" }
			seek += MemoryLayout.size(ofValue: method)
			guard seek < data.count else { throw "less data" }
			
			let flags: UInt8 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: flags)
			guard seek < data.count else { throw "less data" }
			
			let time: UInt32 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: time)
			guard seek < data.count else { throw "less data" }
			
			let extra: UInt8 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: extra)
			guard seek < data.count else { throw "less data" }
			
			let os: UInt8 = data.advanced(by: seek).toValue()
			seek += MemoryLayout.size(ofValue: os)
			guard seek < data.count else { throw "less data" }
			
			guard 0 == ( flags & ( 1 << 1 ) ) else {
				throw "multipart has been not implemented"
			}
			
			let field: Data = 0 == ( flags & ( 1 << 2 ) ) ? Data() : data.advanced(by: seek).toBuffer(size: UInt16.self)
			seek += 0 == ( flags & ( 1 << 2 ) ) ? 0 : ( field.count + MemoryLayout<UInt16>.size )
			guard seek < data.count else { throw "less data" }
			
			let original: String = 0 == ( flags & ( 1 << 3 ) ) ? "" : data.advanced(by: seek).toString()
			seek += 0 == ( flags & ( 1 << 3 ) ) ? 0 : ( original.count + 1 )
			guard seek < data.count else { throw "less data" }
			
			let comment: String = 0 == ( flags & ( 1 << 4 ) ) ? "" : data.advanced(by: seek).toString()
			seek += 0 == ( flags & ( 1 << 4 ) ) ? 0 : ( comment.count + 1 )
			guard seek < data.count else { throw "less data" }
			
			thread = Thread {
				ost.open()
				defer {
					ost.close()
				}
				try?data.advanced(by: seek).gunzip(to: ost, with: 65536)
			}
		}
		nslock = NSLock()
		stream = ist
		reader = Data(count: maximum)
		buffer = Data()
		stream.open()
		thread.start()
	}
	deinit {
		thread.cancel()
		stream.close()
	}
}
extension Gunzip: Supplier {
	func readValue<T: Strideable>() throws -> T {
		return try readData(count: MemoryLayout<T>.stride).withUnsafeBytes { $0.pointee }
	}
	func readArray<T: Strideable>(count: Int) throws -> [T] {
		return try readData(count: MemoryLayout<T>.stride * count).withUnsafeBytes {
			Array(UnsafeBufferPointer(start: $0, count: count))
		}
	}
	func readData(count: Int) throws -> Data {
		nslock.lock()
		defer {
			nslock.unlock()
		}
		while buffer.count < count {
			let size: Int = reader.withUnsafeBytes { stream.read(UnsafeMutablePointer(mutating: $0), maxLength: reader.count) }
			guard 0 < size else {
				break
			}
			buffer.append(reader.subdata(in: 0..<size))
		}
		guard count <= buffer.count else {
			throw "less data"
		}
		defer {
			buffer.removeSubrange(0..<count)
		}
		return buffer.subdata(in: 0..<count)
	}
}
