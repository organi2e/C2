//
//  OxfordIIIT.swift
//  C2
//
//  Created by Kota Nakano on 2/16/18.
//
import CoreData
import CoreImage
private let urlKey: String = "url"
enum OxfordIIIT: Series {
	case pet
	static var domain: String {
		return String(describing: self)
	}
	var family: String {
		return String(describing: self)
	}
}
extension Container {
	func cache(oxfordIIIT: OxfordIIIT) throws -> URL {
		let baseURL: URL = cache.appendingPathComponent(oxfordIIIT.domain, isDirectory: true)
		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
		return baseURL.appendingPathComponent(oxfordIIIT.family).appendingPathExtension("tgz")
	}
}
private extension Container {
	@objc private func OxfordIIITPet(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(oxfordIIIT: .pet))
//		try rebuild(oxford: .pet)
	}
	private func selector(oxfordIIIT: OxfordIIIT) -> String {
		switch oxfordIIIT {
		case .pet:
			return #selector(OxfordIIITPet(url:)).description
		}
	}
}
extension Container {
	func build(oxfordIIIT: OxfordIIIT) throws {
		let fileManager: FileManager = .default
		let cacheURL: URL = try cache(oxfordIIIT: oxfordIIIT)
		guard
			let urlstring: String = try plist(series: oxfordIIIT)[urlKey]as?String,
			let url: URL = URL(string: urlstring) else {
				throw ErrorCases.dictionary
		}
		if fileManager.fileExists(atPath: cacheURL.path) {
			
		} else if !isDownloading(url: url) {
			let downloadTask: URLSessionDownloadTask = download(url: url)
			downloadTask.taskDescription = selector(oxfordIIIT: oxfordIIIT)
			downloadTask.resume()
		}
	}
	/*
	public func build(cifar10: CIFAR10) throws {
		let fileManager: FileManager = .default
		let cacheURL: URL = try cache(cifar10: ())
		guard
			let urlstring = try plist(series: cifar10)[urlKey]as?String,
			let url: URL = URL(string: urlstring) else {
				throw ErrorCases.dictionary
		}
		/*
		if fileManager.fileExists(atPath: cacheURL.path) {
			try rebuild(cifar10: ())
		} else if !isDownloading(url: url) {
			let downloadTask: URLSessionDownloadTask = download(url: url)
			downloadTask.taskDescription = selector(cifar10: ())
			downloadTask.resume()
		}
		*/
	}
	*/
}
