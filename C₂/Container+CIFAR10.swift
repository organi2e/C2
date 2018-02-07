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
	private func buildcifar10() throws {
		let dictionary: [String: Any] = try plist(series: CIFAR10.test)
		guard
			let rows: Int = dictionary[rowsKey]as?Int,
			let cols: Int = dictionary[colsKey]as?Int,
			let batch1: String = dictionary[CIFAR10.batch1.family]as?String,
			let meta: String = dictionary[metaKey]as?String else {
				throw ErrorCases.dictionary
		}
		let fileManager: FileManager = .default
		let cifar10: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		guard fileManager.createFile(atPath: cifar10.path, contents: nil, attributes: nil) else {
			throw ErrorCases.cache
		}
		defer {
			try?fileManager.removeItem(at: cifar10)
		}
		do {
			try Data(contentsOf: cachecifar10, options: .mappedIfSafe).gunzip(to: FileHandle(forWritingTo: cifar10))
		}
		try Data(contentsOf: cifar10, options: .mappedIfSafe).untar {
			switch $0 {
			case batch1:
				break
			case meta:
				print($1, meta)
			default:
				break
			}
		}
		
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
