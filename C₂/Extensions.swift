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
	case format
}
protocol Supplier {
	func readData(count: Int) throws -> Data
	func readValue<T: Strideable>() throws -> T
	func readArray<T: Strideable>(count: Int) throws -> [T]
}
extension NSManagedObject {
	convenience init(in context: NSManagedObjectContext) {
		self.init(entity: type(of: self).entity(), insertInto: context)
	}
}
extension FileHandle: Supplier {
	func readValue<T: Strideable>() throws -> T {
		return try readData(count: MemoryLayout<T>.size).withUnsafeBytes { $0.pointee }
	}
	func readArray<T: Strideable>(count: Int) throws -> [T] {
		return try readData(count: MemoryLayout<T>.stride * count).withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: count)) }
	}
	func readData(count: Int) throws -> Data {
		let data: Data = readData(ofLength: count)
		guard data.count == count else {
			seek(toFileOffset: offsetInFile-UInt64(data.count))
			throw ErrorCases.lessdata
		}
		return data
	}
	func readString() -> String {
		var array: [CChar] = []
		func recursive() -> [CChar] {
			guard let char: CChar = try?readValue(), char != 0 else {
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
internal extension Data {
	func toValue<T>() -> T {
		return withUnsafeBytes { $0.pointee }
	}
	func toArray<T>(count: Int) -> [T] {
		return withUnsafeBytes { Array(UnsafeBufferPointer(start: $0, count: count)) }
	}
	func toArray<T>() -> [T] {
		return toArray(count: count / MemoryLayout<T>.stride)
	}
	func toString() -> String {
		return withUnsafeBytes { String(cString: UnsafePointer<CChar>($0)) }
	}
	func toBuffer<T: UnsignedInteger>(size: T.Type) -> Data {
		let byte: T = toValue()
		return advanced(by: MemoryLayout<T>.stride)[0..<Int(byte)]
	}
	subscript(index: Int) -> UInt8 {
		return advanced(by: index).withUnsafeBytes { $0.pointee }
	}
	subscript(range: Range<Int>) -> Data {
		return subdata(in: startIndex.advanced(by: range.lowerBound)..<startIndex.advanced(by: range.upperBound))
	}
}
internal extension FileHandle {
	func untar(handler: (String, Data) throws -> ()) throws {
		guard let base: UInt32 = "0".unicodeScalars.first?.value else {
			throw ErrorCases.decode
		}
		while let head: Data = try?readData(count: 512) {
			let name: String = head.toString()
			switch head[156] {
			case 48://file
				let octs: [UInt8] = head[124..<135].toArray()
				let size: Int = octs.reduce(0) {
					$0 * 8 + Int($1) - Int(base)
				}
				let rounded: Int = 512 * ( ( size + 511 ) / 512 )
				try handler(name, readData(count: rounded)[0..<size])
			default:
				break
			}
		}
	}
}
internal extension Data {//mapped memory expectation
	func untar(handle: (String, Data) throws -> Void) throws {//fixed data length and split them
		try withUnsafeBytes { (head: UnsafePointer<UInt8>) in
			var seek: UnsafePointer<UInt8> = head
			while head.distance(to: seek) < count {
				let data: Data = seek.readData(count: 512)
				let name: String = data.toString()
				switch data[156] {
				case 48:
					let char: [CChar] = data[124..<136].toArray()
					let byte: String = String(cString: char)
					guard let size: Int = Int(byte, radix: 8) else {
						continue
					}
					let rounded: Int = 512 * ( ( size + 511 ) / 512 )
					try handle(name, seek.readData(count: rounded)[0..<size])
				default:
					break//nop
				}
			}
		}
	}
}
internal extension Data {//mapped memory expectation
	func gunzip(to: FileHandle) throws {//fixed data length -> undeterminant data length
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
			
			let original: String = 0 < ( flags & ( 1 << 3 )) ? seek.readString() : ""
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			let comment: String = 0 < ( flags & ( 1 << 4 )) ? seek.readString() : ""
			guard head.distance(to: seek) < count else { throw ErrorCases.lessdata }
			
			//Auto memory management by using NSData in this scope
			var stream: compression_stream = Data(capacity: MemoryLayout<compression_stream>.size).withUnsafeBytes { $0.pointee }
			guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
				return
			}
			defer {
				let success: Bool = compression_stream_destroy(&stream) == COMPRESSION_STATUS_OK
				assert(success)
			}
			stream.src_ptr = seek
			stream.src_size = count - head.distance(to: seek)
			let size: Int = 65536//should be less than 65537?
			try Data(capacity: size).withUnsafeBytes { (buffer: UnsafePointer<UInt8>) in
				while true {
					stream.dst_ptr = UnsafeMutablePointer(mutating: buffer)
					stream.dst_size = size
					switch compression_stream_process(&stream, 0) {
					case COMPRESSION_STATUS_OK:
						guard stream.dst_size == 0 else { continue }
						to.write(Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer), count: buffer.distance(to: stream.dst_ptr), deallocator: .none))
					case COMPRESSION_STATUS_END:
						to.write(Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer), count: buffer.distance(to: stream.dst_ptr), deallocator: .none))
						guard stream.dst_size == 0 else { return }
					case COMPRESSION_STATUS_ERROR:
						throw ErrorCases.decode
					default:
						fatalError()
					}
				}
			}
		}
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
