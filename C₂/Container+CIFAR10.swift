//
//  Container+CIFAR10.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Accelerate
import CoreData
import Foundation
private let urlKey: String = "url"
private let rowsKey: String = "rows"
private let colsKey: String = "cols"
private let metaKey: String = "meta"
public enum CIFAR10: Series {
	case batch1
	case batch2
	case batch3
	case batch4
	case batch5
	case test
	public static var domain: String {
		return String(describing: self)
	}
	public var family: String {
		return String(describing: self)
	}
}
private extension CIFAR10 {
	var key: String {
		return "\(domain).\(family)"
	}
}
private extension Container {
	private func cache(cifar10: Void) throws -> URL {
		let baseURL: URL = cache.appendingPathComponent(CIFAR10.domain, isDirectory: true)
		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
		return baseURL.appendingPathComponent("tgz")
	}
}
private extension NSManagedObjectContext {
	func rebuild(cifar10: CIFAR10, labels: [UInt8: String], rows: Int, cols: Int, data: Data) throws {
		try index(series: cifar10).forEach(delete)
		let data: [(UInt8, Data)] = data.chunk(width: rows * cols * 3 + 1).map {
			($0.toValue(), $0[1..<$0.count])
		}
		let width: vImagePixelCount = vImagePixelCount(cols)
		let height: vImagePixelCount = vImagePixelCount(rows)
		let rowBytes: Int = 4 * cols
		let images: [UInt8: Set<Image>] = data.reduce([UInt8: Set<Image>]()) {
			let head: UInt8 = $1.0
			let tail: Data = $1.1
			let image: Image = Image(in: self)
			image.width = UInt16(cols)
			image.height = UInt16(rows)
			image.rowBytes = UInt32(rowBytes)
			image.format = kCIFormatRGBA8
			image.data = Data(count: rowBytes * Int(height))
			image.data.withUnsafeMutableBytes { (data: UnsafeMutablePointer<UInt8>) in
				let result: Bool = tail.withUnsafeBytes {//(b, g, r, x) -> bgrx = (r, g, b, x) -> rgbx
					vImageConvert_Planar8ToBGRX8888([vImage_Buffer(data: UnsafeMutablePointer<UInt8>(mutating: $0).advanced(by: 0*Int(height*width)), height: height, width: width, rowBytes: cols)],
													[vImage_Buffer(data: UnsafeMutablePointer<UInt8>(mutating: $0).advanced(by: 1*Int(height*width)), height: height, width: width, rowBytes: cols)],
													[vImage_Buffer(data: UnsafeMutablePointer<UInt8>(mutating: $0).advanced(by: 2*Int(height*width)), height: height, width: width, rowBytes: cols)],
													255,
													[vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)],
													0) == kvImageNoError
				}
				assert(result)
			}
			return $0.merging([head: Set<Image>(arrayLiteral: image)]) {
				$0.union($1)
			}
		}
		images.forEach {
			let index: Index = Index(in: self)
			index.domain = type(of: cifar10).domain
			index.family = cifar10.family
			index.option = [:]
			index.label = labels[$0] ?? ""
			index.contents = $1
		}
	}
}
private extension Container {
	private func rebuild(cifar10: CIFAR10, labels: [UInt8: String], rows: Int, cols: Int, data: Data, context: NSManagedObjectContext) throws {
		guard let bool: Bool = get(for: cifar10.key)as?Bool, bool else {
			return
		}
		try autoreleasepool {
			try context.rebuild(cifar10: cifar10, labels: labels, rows: rows, cols: cols, data: data)
			try context.save()
			context.reset()
		}
		context.reset()
		func dispatch() {
			notification?.success(build: cifar10)
		}
		viewContext.perform(dispatch)
	}
	private func rebuild(cifar10: Void, context: NSManagedObjectContext) throws {
		let dictionary: [String: Any] = try plist(series: CIFAR10.test)
		guard
			let rows: Int = dictionary[rowsKey]as?Int,
			let cols: Int = dictionary[colsKey]as?Int,
			let batch1: String = dictionary[CIFAR10.batch1.family]as?String,
			let batch2: String = dictionary[CIFAR10.batch2.family]as?String,
			let batch3: String = dictionary[CIFAR10.batch3.family]as?String,
			let batch4: String = dictionary[CIFAR10.batch4.family]as?String,
			let batch5: String = dictionary[CIFAR10.batch5.family]as?String,
			let test: String = dictionary[CIFAR10.test.family]as?String,
			let meta: String = dictionary[metaKey]as?String else {
				throw ErrorCases.dictionary
		}
		let labels: [UInt8: String] = try autoreleasepool {
			let gunzip: Gunzip = try Gunzip(url: cache(cifar10: ()), options: .mappedRead, maximum: rows * cols * MemoryLayout<UInt8>.stride * 4)
			let untar: Untar = Untar(supplier: gunzip)
			return [UInt8: String](uniqueKeysWithValues: untar.flatMap {
				guard $0 == meta else { return nil }
				return String(data: $1, encoding: .utf8)
			}.joined().components(separatedBy: .newlines).filter{!$0.isEmpty}.enumerated().map{
					(UInt8($0), $1)
			})
		}
		let gunzip: Gunzip = try Gunzip(url: cache(cifar10: ()), options: .mappedRead, maximum: rows * cols * MemoryLayout<UInt8>.stride * 4)
		let untar: Untar = Untar(supplier: gunzip)
		try untar.forEach {
			switch $0 {
			case batch1:
				try rebuild(cifar10: .batch1, labels: labels, rows: rows, cols: cols, data: $1, context: context)
			case batch2:
				try rebuild(cifar10: .batch2, labels: labels, rows: rows, cols: cols, data: $1, context: context)
			case batch3:
				try rebuild(cifar10: .batch3, labels: labels, rows: rows, cols: cols, data: $1, context: context)
			case batch4:
				try rebuild(cifar10: .batch4, labels: labels, rows: rows, cols: cols, data: $1, context: context)
			case batch5:
				try rebuild(cifar10: .batch5, labels: labels, rows: rows, cols: cols, data: $1, context: context)
			case test:
				try rebuild(cifar10: .test, labels: labels, rows: rows, cols: cols, data: $1, context: context)
			default:
				break
			}
		}
	}
	func rebuild(cifar10: Void) throws {
		func dispatch(context: NSManagedObjectContext) {
			do {
				try rebuild(cifar10: (), context: context)
			} catch {
				failure(error: error)
			}
		}
		func dispatch() {
			do {
				let cacheURL: URL = try cache(cifar10: ())
				let fileManager: FileManager = .default
				guard fileManager.fileExists(atPath: cacheURL.path) else {
					return
				}
				performBackgroundTask(dispatch)
			} catch {
				failure(error: error)
			}
		}
		viewContext.perform(dispatch)//execlusive execution
	}
}
private extension Container {
	@objc private func cifar10(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(cifar10: ()))
		try rebuild(cifar10: ())
	}
	private func selector(cifar10: Void) -> String {
		return #selector(cifar10(url:)).description
	}
}
public extension Container {
	public func build(cifar10: CIFAR10) throws {
		let fileManager: FileManager = .default
		let cacheURL: URL = try cache(cifar10: ())
		guard
			let urlstring = try plist(series: cifar10)[urlKey]as?String,
			let url: URL = URL(string: urlstring) else {
				throw ErrorCases.dictionary
		}
		set(value: true, for: cifar10.key)
		if fileManager.fileExists(atPath: cacheURL.path) {
			try rebuild(cifar10: ())
		} else if !isDownloading(url: url) {
			let downloadTask: URLSessionDownloadTask = download(url: url)
			downloadTask.taskDescription = selector(cifar10: ())
			downloadTask.resume()
		}
	}
}
private extension Data {
	func chunk(width: Int) -> [Data] {
		return stride(from: 0, to: count, by: width).map {
			subdata(in: $0..<$0 + width)
		}
	}
}

