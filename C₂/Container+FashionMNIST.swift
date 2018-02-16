//
//  FashionMNIST.swift
//  C2
//
//  Created by Kota Nakano on 2/16/18.
//
import CoreData
import CoreImage
private let imageKey: String = "image"
private let labelKey: String = "label"
private let labelsKey: String = "labels"
extension Container {
	public enum FashionMNIST: Series {
		case train
		case t10k
		public static var domain: String {
			return String(describing: self)
		}
		public var family: String {
			return String(describing: self)
		}
	}
}
private extension Container {
	private func cache(fashionMNIST: FashionMNIST) throws -> (image: URL, label: URL) {
		let baseURL: URL = cache.appendingPathComponent(type(of: fashionMNIST).domain, isDirectory: true).appendingPathComponent(fashionMNIST.family, isDirectory: true)
		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
		return(image: baseURL.appendingPathComponent(imageKey), label: baseURL.appendingPathComponent(labelKey))
	}
}
private extension NSManagedObjectContext {
	func rebuild(fashionMNIST: Container.FashionMNIST, labels: [String], labelHandle: Supplier, imageHandle: Supplier) throws {
		let labelheader: [UInt32] = try labelHandle.readArray(count: 2)
		let imageheader: [UInt32] = try imageHandle.readArray(count: 4)
		let labelheads: [Int] = labelheader.map { Int(UInt32(bigEndian: $0)) }
		let imageheads: [Int] = imageheader.map { Int(UInt32(bigEndian: $0)) }
		guard
			let labelcount: Int = labelheads[safe: 1],
			let imagecount: Int = imageheads[safe: 1],
			let rows: Int = imageheads[safe: 2],
			let cols: Int = imageheads[safe: 3], labelcount == imagecount else {
				throw "error"
		}
		try index(series: fashionMNIST).forEach(delete)
		let count: Int = min(labelcount, imagecount)
		let bytes: Int = rows * cols
		let images: [UInt8: Set<Image>] = try [Void](repeating: (), count: count).reduce([UInt8: Set<Image>]()) {
			let _: Void = $1//gabage
			let label: UInt8 = try labelHandle.readValue()
			let pixel: Data = try imageHandle.readData(count: bytes)
			let image: Image = Image(in: self)
			image.width = UInt16(cols)
			image.height = UInt16(rows)
			image.rowBytes = UInt32(cols)
			image.format = kCIFormatA8
			image.data = pixel
			return $0.merging([label: Set<Image>(arrayLiteral: image)]) {
				$0.union($1)
			}
		}
		images.forEach {
			let index: Index = Index(in: self)
			index.domain = type(of: fashionMNIST).domain
			index.family = fashionMNIST.family
			index.option = [:]
			index.label = labels[safe: Int($0)] ?? ""
			index.contents = $1
		}
	}
}
private extension Container {
	private func rebuild(fashionMNIST: FashionMNIST, context: NSManagedObjectContext) throws {
		guard let labels: [String] = try plist(series: fashionMNIST)[labelsKey]as?[String] else {
			throw "dictionary"
		}
		let (image, label): (URL, URL) = try cache(fashionMNIST: fashionMNIST)
		try context.rebuild(fashionMNIST: fashionMNIST,
							labels: labels,
							labelHandle: Gunzip(url: label, maximum: 784),
							imageHandle: Gunzip(url: image, maximum: 784))
		try context.save()
		notification?.success(build: fashionMNIST)
	}
	private func rebuild(fashionMNIST: FashionMNIST) throws {
		func dispatch(context: NSManagedObjectContext) {
			do {
				try rebuild(fashionMNIST: fashionMNIST, context: context)
			} catch {
				failure(error: error)
			}
		}
		func dispatch() {
			do {
				let (image, label): (URL, URL) = try cache(fashionMNIST: fashionMNIST)
				let fileManager: FileManager = .default
				guard fileManager.fileExists(atPath: image.path), fileManager.fileExists(atPath: label.path) else {
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
	@objc private func FashionMNISTTrainImage(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(fashionMNIST: .train).image)
		try rebuild(fashionMNIST: .train)
	}
	@objc private func FashionMNISTTrainLabel(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(fashionMNIST: .train).label)
		try rebuild(fashionMNIST: .train)
	}
	@objc private func FashionMNISTT10kImage(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(fashionMNIST: .t10k).image)
		try rebuild(fashionMNIST: .t10k)
	}
	@objc private func FashionMNISTT10kLabel(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(fashionMNIST: .t10k).label)
		try rebuild(fashionMNIST: .t10k)
	}
	private func selector(fashionMNIST: FashionMNIST, key: String) throws -> String {
		switch(fashionMNIST, key) {
		case (.train, imageKey):
			return #selector(FashionMNISTTrainImage(url:)).description
		case (.train, labelKey):
			return #selector(FashionMNISTTrainLabel(url:)).description
		case (.t10k, imageKey):
			return #selector(FashionMNISTT10kImage(url:)).description
		case (.t10k, labelKey):
			return #selector(FashionMNISTT10kLabel(url:)).description
		default:
			throw ErrorCases.selector
		}
	}
}
extension Container {
	public func build(fashionMNIST: FashionMNIST) throws {
		let fileManager: FileManager = .default
		let (imageURL, labelURL): (URL, URL) = try cache(fashionMNIST: fashionMNIST)
		guard let dictionary: [String: String] = try plist(series: fashionMNIST)[fashionMNIST.family]as?[String: String] else {
			throw ErrorCases.dictionary
		}
		let stable: Bool = try [(imageURL, imageKey), (labelURL, labelKey)].reduce(true) {
			guard !fileManager.fileExists(atPath: $1.0.path) else {
				return $0
			}
			guard
				let string: String = dictionary[$1.1],
				let url: URL = URL(string: string) else {
					throw ErrorCases.url
			}
			if !isDownloading(url: url) {
				let downloadTask: URLSessionDownloadTask = download(url: url)
				downloadTask.taskDescription = try selector(fashionMNIST: fashionMNIST, key: $1.1)
				downloadTask.resume()
			}
			return false
		}
		if stable {
			try rebuild(fashionMNIST: fashionMNIST)
		}
	}
}

