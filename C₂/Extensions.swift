//
//  Extensions.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Foundation
import Compression
internal enum ErrorCases: Error {
	case lessdata
	case multipart
	case method
	case magic
	case decode
}
extension NSManagedObject {
	convenience init(in context: NSManagedObjectContext) {
		self.init(entity: type(of: self).entity(), insertInto: context)
	}
}
extension FileHandle {
	func readData(count: Int) -> Data? {
		let previous: UInt64 = offsetInFile
		let data: Data = readData(ofLength: count)
		guard data.count == count else {
			seek(toFileOffset: previous)
			return nil
		}
		return data
	}
	func readElement<T>() -> T? {
		return readData(count: MemoryLayout<T>.size)?.withUnsafeBytes { $0.pointee }
	}
	func readArray<T>(count: Int) -> [T]? {
		return readData(count: MemoryLayout<T>.stride * count)?.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: count)) }
	}
	func readString() -> String {
		var array: [CChar] = []
		func recursive() -> [CChar] {
			guard let char: CChar = readElement(), char != 0 else {
				return []
			}
			return [char] + recursive()
		}
		return String(cString: recursive())
	}
}
internal extension Array {
	subscript(safe index: Int) -> Element? {
		guard indices.contains(index) else {
			return nil
		}
		return self[index]
	}
}
internal extension UnsafePointer {
	mutating func readElement<T>() -> T {
		defer {
			self = advanced(by: MemoryLayout<T>.size)
		}
		return withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
	}
	mutating func readArray<T>(count: Int) -> [T] {
		defer {
			self = advanced(by: MemoryLayout<T>.stride * count)
		}
		return withMemoryRebound(to: T.self, capacity: count) { Array(UnsafeBufferPointer(start: $0, count: count)) }
	}
	mutating func readData(count: Int) -> Data {
		defer {
			self = advanced(by: count)
		}
		return Data(bytesNoCopy: UnsafeMutablePointer(mutating: self), count: count, deallocator: .none)
	}
	mutating func readString() -> String {
		func recursive() -> Array<CChar> {
			let char: CChar = readElement()
			return [char] + ( char == 0 ? [] : recursive() )
		}
		return String(cString: recursive())
	}
}
internal extension Data {//mapped memory expectation
	func gunzip() throws -> URL {//fixed data length -> undeterminant data length
		let fileManager: FileManager = .default
		let url: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
		let fileHandle: FileHandle = try FileHandle(forWritingTo: url)
		defer {
			fileHandle.closeFile()
		}
		print(url)
		try withUnsafeBytes { (head: UnsafePointer<UInt8>) in
			
			var seek: UnsafePointer<UInt8> = head
			
			let magic: UInt16 = seek.readElement()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			guard magic == 35615 else {
				throw ErrorCases.magic
			}
	
			let method: UInt8 = seek.readElement()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			guard method == 8 else {
				throw ErrorCases.method
			}
			
			let flags: UInt8 = seek.readElement()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let time: UInt32 = seek.readElement()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let extra: UInt8 = seek.readElement()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let os: UInt8 = seek.readElement()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			guard flags & ( 1 << 1 ) == 0 else {
				throw ErrorCases.multipart
			}
			
			let field: Data = {
				guard 0 < ( flags & ( 1 << 2 ) ) else { return Data() }
				let bytes: UInt16 = seek.readElement()
				return seek.readData(count: Int(bytes))
			}()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let original: String = {
				guard 0 < ( flags & ( 1 << 3 )) else { return "" }
				return seek.readString()
			}()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let comment: String = {
				guard 0 < ( flags & ( 1 << 4 )) else { return "" }
				return seek.readString()
			}()
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let capacity: Int = MemoryLayout<compression_stream>.size
			try Data(count: capacity).withUnsafeBytes { (streamref: UnsafePointer<compression_stream>) in
				let stream: UnsafeMutablePointer<compression_stream> = UnsafeMutablePointer(mutating: streamref)
				guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
					return
				}
				defer {
					compression_stream_destroy(stream)
				}
				stream.pointee.src_ptr = seek
				stream.pointee.src_size = count + seek.distance(to: head)
				let size: Int = compression_decode_scratch_buffer_size(COMPRESSION_ZLIB)
				try Data(capacity: size).withUnsafeBytes { (cacheref: UnsafePointer<UInt8>) in
					let cache: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer(mutating: cacheref)
					while true {
						stream.pointee.dst_ptr = cache
						stream.pointee.dst_size = size
						switch compression_stream_process(stream, 0) {
						case COMPRESSION_STATUS_OK:
							fileHandle.write(Data(bytes: cache, count: count))
						case COMPRESSION_STATUS_END:
							fileHandle.write(Data(bytes: cache, count: cache.distance(to: stream.pointee.dst_ptr)))
							return
						case COMPRESSION_STATUS_ERROR:
							throw ErrorCases.decode
						default:
							fatalError()
						}
					}
				}
			}
		}
		return url
	}
}
/*
internal extension FileHandle {
	//reference: http://www.onicos.com/staff/iz/formats/gzip.html
	func gunzip() throws -> Data {
		
		seek(toFileOffset: 0)
		
		guard let magic: UInt16 = readElement(), magic == 35615 else { throw ErrorCases.InvalidFormat(of: magic, for: "magic") }
		
		guard let method: UInt8 = readElement(), method == 8 else { throw ErrorCases.InvalidFormat(of: method, for: "method") }
		
		let flags: UInt8 = try readElement()
		
		let time: UInt32 = try readElement()
		
		let extra: UInt8 = try readElement()
		
		let os: UInt8 = try readElement()
		
		guard flags & ( 1 << 1 ) == 0 else { throw ErrorCases.NoImplemented(feature: "multipart") }
		
		let field: Data = try {
			guard 0 < ( flags & ( 1 << 2 ) ) else { return Data() }
			let bytes: UInt16 = try readElement()
			return readData(ofLength: Int(bytes))
		}()
		
		let original: String = try {
			guard 0 < ( flags & ( 1 << 3 )) else { return "" }
			return try readString()
		}()
		
		let comment: String = try {
			guard 0 < ( flags & ( 1 << 4 )) else { return "" }
			return try readString()
		}()
		
		let data: Data = readDataToEndOfFile()
		return try data.withUnsafeBytes { (src: UnsafePointer<UInt8>) -> Data in
			let bs: Int = compression_decode_scratch_buffer_size(COMPRESSION_ZLIB)
			return try Data(capacity: bs + MemoryLayout<compression_stream>.size).withUnsafeBytes { (cache: UnsafePointer<UInt8>) -> Data in
				let ref: UnsafeMutablePointer<compression_stream> = UnsafeMutablePointer<compression_stream>(OpaquePointer(cache.advanced(by: bs)))
				let buf: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>(mutating: cache)
				guard compression_stream_init(ref, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { throw ErrorCases.UnknownError(message: "compression") }
				defer {
					guard compression_stream_destroy(ref) == COMPRESSION_STATUS_OK else { fatalError("Die") }
				}
				ref.pointee.src_ptr = src
				ref.pointee.src_size = data.count
				var result: Data = Data()
				while true {
					ref.pointee.dst_ptr = buf
					ref.pointee.dst_size = bs
					switch compression_stream_process(ref, 0) {
					case COMPRESSION_STATUS_OK:
						result.append(buf, count: bs - ref.pointee.dst_size)
					case COMPRESSION_STATUS_END:
						result.append(buf, count: bs - ref.pointee.dst_size)
						return result
					case COMPRESSION_STATUS_ERROR:
						throw ErrorCases.UnknownError(message: "gunzip parser")
					default:
						fatalError("Die")
					}
				}
			}
		}
	}
}
*/
