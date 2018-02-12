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
public extension Container {
	public enum CIFAR10: Series {
		case batch1
		case batch2
		case batch3
		case batch4
		case batch5
		case batch6
		case test
		public static var domain: String {
			return String(describing: self)
		}
		public var family: String {
			return String(describing: self)
		}
	}
}
private extension Container {
	private var cachecifar10: URL {
		return cache.appendingPathComponent(CIFAR10.domain)
	}
}
private extension Container {
	private func buildcifar10(context: NSManagedObjectContext, rows: Int, cols: Int, family: String, data: Data) throws {
		try data.chunk(width: rows * cols * 3 + 1).forEach {
			let head: UInt8 = $0.toValue()
			let tail: Data = $0[1..<$0.count]
			guard tail.count == rows * cols * 3 else {
				throw "dummy"
			}
			let height: vImagePixelCount = vImagePixelCount(rows)
			let width: vImagePixelCount = vImagePixelCount(cols)
			let rowBytes: Int = 4 * cols
			let image: Image = Image(in: context)
			image.domain = CIFAR10.domain
			image.family = family
			image.option = [:]
			image.handle = Int(head)
			image.width = UInt16(width)
			image.height = UInt16(height)
			image.rowBytes = UInt32(rowBytes)
			image.format = kCIFormatRGBA8
			image.data = Data(count: rowBytes * Int(height))
			image.data.withUnsafeMutableBytes { (data: UnsafeMutablePointer<UInt8>) in
				let result: vImage_Error = tail.withUnsafeBytes {
					vImageConvert_Planar8ToBGRX8888([vImage_Buffer(data: UnsafeMutablePointer<UInt8>(mutating: $0).advanced(by: 2*Int(height*width)), height: height, width: width, rowBytes: rowBytes)],
																			   [vImage_Buffer(data: UnsafeMutablePointer<UInt8>(mutating: $0).advanced(by: 1*Int(height*width)), height: height, width: width, rowBytes: rowBytes)],
																			   [vImage_Buffer(data: UnsafeMutablePointer<UInt8>(mutating: $0).advanced(by: 0*Int(height*width)), height: height, width: width, rowBytes: rowBytes)],
																			   255,
																			   [vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)],
																			   0)
				}
				assert(result == kvImageNoError)
			}
		}
	}
	private func buildcifar10(context: NSManagedObjectContext) throws {
		let dictionary: [String: Any] = try plist(series: CIFAR10.test)
		guard
			let rows: Int = dictionary[rowsKey]as?Int,
			let cols: Int = dictionary[colsKey]as?Int,
			let batch1: String = dictionary[CIFAR10.batch1.family]as?String,
			let batch2: String = dictionary[CIFAR10.batch2.family]as?String,
			let batch3: String = dictionary[CIFAR10.batch3.family]as?String,
			let batch4: String = dictionary[CIFAR10.batch4.family]as?String,
			let batch5: String = dictionary[CIFAR10.batch5.family]as?String,
			let batch6: String = dictionary[CIFAR10.batch6.family]as?String,
			let test: String = dictionary[CIFAR10.test.family]as?String,
			let meta: String = dictionary[metaKey]as?String else {
				throw ErrorCases.dictionary
		}
		var labels: [UInt8: String] = [:]
		try Untar(supplier: Gunzip(url: cachecifar10, options: .mappedRead, maximum: rows * cols * MemoryLayout<UInt8>.stride * 4)).scan {
			switch $0 {
			case batch1:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.batch1.family, data: $1)
			case batch2:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.batch2.family, data: $1)
			case batch3:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.batch3.family, data: $1)
			case batch4:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.batch4.family, data: $1)
			case batch5:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.batch5.family, data: $1)
			case batch6:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.batch6.family, data: $1)
			case test:
				try buildcifar10(context: context, rows: rows, cols: cols, family: CIFAR10.test.family, data: $1)
			case meta:
				guard let text: String = String(data: $1, encoding: .utf8) else {
					throw "meta file is wrong"
				}
				text.components(separatedBy: .newlines).filter { !$0.isEmpty }.enumerated().forEach {
					labels.updateValue($1, forKey: UInt8($0))
				}
			default:
				break
			}
		}
		print(labels)
	}
	func buildcifar10() throws {
		func dispatch(context: NSManagedObjectContext) {
			do {
				try buildcifar10(context: context)
			} catch {
				
			}
		}
		performBackgroundTask(dispatch)
	}
}
private extension Container {
	@objc private func cifar10(location: URL) throws {
		try FileManager.default.moveItem(at: location, to: cachecifar10)
		try buildcifar10()
	}
	private var selectorcifar10: String {
		return #selector(cifar10(location:)).description
	}
}
public extension Container {
	public func build(cifar10: CIFAR10) throws {
		guard
			let string: String = try plist(series: cifar10)[urlKey]as?String,
			let url: URL = URL(string: string) else {
				throw ErrorCases.url
		}
		if FileManager.default.fileExists(atPath: cachecifar10.path) {
			try buildcifar10()
		} else if !isDownloading(url: url) {
			let downloadTask: URLSessionDownloadTask = download(url: url)
			downloadTask.taskDescription = selectorcifar10
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

