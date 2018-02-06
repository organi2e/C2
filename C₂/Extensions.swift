//
//  Extensions.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Foundation
import Compression
internal enum ErrorCases: Error {
	case NoModelFound(name: String)
	case NoPlistFound(name: String)
	case NoEntityFound(name: String)
	case NoRecourdFound(name: String)
	case NoResourceFound(name: String, extension: String)
	case InvalidFormat(of: Any, for: Any)
	case NoImplemented(feature: String)
	case NoFileDownload(from: URL)
	case UnknownError(message: String)
}
internal extension NSManagedObject {
	class var entityName: String {
		return String(describing: self)
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
			self = self.advanced(by: MemoryLayout<T>.stride)
		}
		return withMemoryRebound(to: T.self, capacity: 1) {
			return $0.pointee
		}
	}
	mutating func readData(count: Int) -> Data {
		defer {
			self = self.advanced(by: count)
		}
		return Data(bytes: self, count: count)
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
	func gunzip(to: FileHandle) throws {//fixed data length -> undeterminant data length
		
		try withUnsafeBytes { (head: UnsafePointer<UInt8>) in
			
			var seek: UnsafePointer<UInt8> = head
			
			let magic: UInt16 = seek.readElement()
			guard magic == 35615 else { throw ErrorCases.InvalidFormat(of: magic, for: "magic") }
	
			let method: UInt8 = seek.readElement()
			guard method == 8 else { throw ErrorCases.InvalidFormat(of: method, for: "method") }
			
			let flags: UInt8 = seek.readElement()
			
			let time: UInt32 = seek.readElement()
			
			let extra: UInt8 = seek.readElement()
			
			let os: UInt8 = seek.readElement()
			
			guard flags & ( 1 << 1 ) == 0 else { throw ErrorCases.NoImplemented(feature: "multipart") }
			
			let field: Data = {
				guard 0 < ( flags & ( 1 << 2 ) ) else { return Data() }
				let bytes: UInt16 = seek.readElement()
				return seek.readData(count: Int(bytes))
			}()
			
			let original: String = {
				guard 0 < ( flags & ( 1 << 3 )) else { return "" }
				return seek.readString()
			}()
			
			let comment: String = {
				guard 0 < ( flags & ( 1 << 4 )) else { return "" }
				return seek.readString()
			}()
			
			let capacity: Int = MemoryLayout<compression_stream>.size
			try Data(capacity: capacity).withUnsafeBytes { (streamref: UnsafePointer<compression_stream>) in
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
							to.write(Data(bytesNoCopy: cache, count: cache.distance(to: stream.pointee.dst_ptr), deallocator: .none))
						case COMPRESSION_STATUS_END:
							to.write(Data(bytesNoCopy: cache, count: cache.distance(to: stream.pointee.dst_ptr), deallocator: .none))
							return
						case COMPRESSION_STATUS_ERROR:
							throw ErrorCases.NoEntityFound(name: "")
						default:
							fatalError()
						}
					}
				}
			}
		}
	}
}
internal extension FileHandle {
	//reference: http://www.onicos.com/staff/iz/formats/gzip.html
	func gunzip() throws -> Data {
		
		seek(toFileOffset: 0)
		
		let magic: UInt16 = readElement()
		guard magic == 35615 else { throw ErrorCases.InvalidFormat(of: magic, for: "magic") }
		
		let method: UInt8 = readElement()
		guard method == 8 else { throw ErrorCases.InvalidFormat(of: method, for: "method") }
		
		let flags: UInt8 = readElement()
		
		let time: UInt32 = readElement()
		
		let extra: UInt8 = readElement()
		
		let os: UInt8 = readElement()
		
		guard flags & ( 1 << 1 ) == 0 else { throw ErrorCases.NoImplemented(feature: "multipart") }
		
		let field: Data = {
			guard 0 < ( flags & ( 1 << 2 ) ) else { return Data() }
			let bytes: UInt16 = readElement()
			return readData(ofLength: Int(bytes))
		}()
		
		let original: String = {
			guard 0 < ( flags & ( 1 << 3 )) else { return "" }
			return readString()
		}()
		
		let comment: String = {
			guard 0 < ( flags & ( 1 << 4 )) else { return "" }
			return readString()
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
	private func readString() -> String {
		func recursive(fileHandle: FileHandle) -> Array<CChar> {
			let char: CChar = fileHandle.readElement()
			return Array<CChar>(arrayLiteral: char) + ( char == 0 ? Array<CChar>() : recursive(fileHandle: fileHandle) )
		}
		return String(cString: recursive(fileHandle: self))
	}
	private func readElement<T>() -> T {
		return readData(ofLength: MemoryLayout<T>.size).withUnsafeBytes {
			$0.pointee
		}
	}
}
