//
//  Container+MNIST.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import CoreData
import CoreImage
private let imageKey: String = "image"
private let labelKey: String = "label"
private let labelsKey: String = "labels"
public enum MNIST: Series {
	case train
	case t10k
	public static var domain: String {
		return String(describing: self)
	}
	public var family: String {
		return String(describing: self)
	}
}
extension Container {
	public enum MNISTError: Error {
		case format
	}
}
private extension Container {
	private func cache(mnist: MNIST) throws -> (image: URL, label: URL) {
		let baseURL: URL = cache.appendingPathComponent(MNIST.domain, isDirectory: true).appendingPathComponent(mnist.family, isDirectory: true)
		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
		return(image: baseURL.appendingPathComponent(imageKey), label: baseURL.appendingPathComponent(labelKey))
	}
}
private extension NSManagedObjectContext {
	func rebuild(mnist: MNIST, labels: [String], labelHandle: Supplier, imageHandle: Supplier) throws {
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
		try index(series: mnist).forEach(delete)
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
			index.domain = type(of: mnist).domain
			index.family = mnist.family
			index.option = [:]
			index.label = labels[safe: Int($0)] ?? ""
			index.contents = $1
		}
	}
}
private extension Container {
	private func rebuild(mnist: MNIST, context: NSManagedObjectContext) throws {
		guard let labels: [String] = try plist(series: mnist)[labelsKey]as?[String]else{
			throw "dictionary"
		}
		let (image, label): (URL, URL) = try cache(mnist: mnist)
		try context.rebuild(mnist: mnist,
							labels: labels,
							labelHandle: Gunzip(url: label, maximum: 784),
							imageHandle: Gunzip(url: image, maximum: 784))
		try context.save()
		notification?.success(build: mnist)
	}
	private func rebuild(mnist: MNIST) throws {
		let (image, label): (URL, URL) = try cache(mnist: mnist)
		func dispatch(context: NSManagedObjectContext) {
			do {
				try rebuild(mnist: mnist, context: context)
			} catch {
				failure(error: error)
			}
		}
		func dispatch() {
			let fileManager: FileManager = .default
			guard fileManager.fileExists(atPath: image.path), fileManager.fileExists(atPath: label.path) else {
				return
			}
			performBackgroundTask(dispatch)
		}
		viewContext.perform(dispatch)//execlusive execution
	}
}
private extension Container {
	@objc private func MNISTTrainImage(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(mnist: .train).image)
		try rebuild(mnist: .train)
	}
	@objc private func MNISTTrainLabel(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(mnist: .train).label)
		try rebuild(mnist: .train)
	}
	@objc private func MNISTT10kImage(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(mnist: .t10k).image)
		try rebuild(mnist: .t10k)
	}
	@objc private func MNISTT10kLabel(url: URL) throws {
		try FileManager.default.moveItem(at: url, to: cache(mnist: .t10k).label)
		try rebuild(mnist: .t10k)
	}
	private func selector(mnist: MNIST, key: String) throws -> String {
		switch(mnist, key) {
		case (.train, imageKey):
			return #selector(MNISTTrainImage(url:)).description
		case (.train, labelKey):
			return #selector(MNISTTrainLabel(url:)).description
		case (.t10k, imageKey):
			return #selector(MNISTT10kImage(url:)).description
		case (.t10k, labelKey):
			return #selector(MNISTT10kLabel(url:)).description
		default:
			throw ErrorCases.selector
		}
	}
}
extension Container {
	public func build(mnist: MNIST) throws {
		let fileManager: FileManager = .default
		let (imageURL, labelURL): (URL, URL) = try cache(mnist: mnist)
		guard let dictionary: [String: String] = try plist(series: mnist)[mnist.family]as?[String: String] else {
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
				downloadTask.taskDescription = try selector(mnist: mnist, key: $1.1)
				downloadTask.resume()
			}
			return false
		}
		if stable {
			try rebuild(mnist: mnist)
		}
	}
}
