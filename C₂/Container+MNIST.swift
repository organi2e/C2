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
extension Container {
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
private extension Container {
	private func update(mnist: MNIST, context: NSManagedObjectContext) throws {
		try context.fetch(series: mnist).forEach {
			context.delete($0)
			try context.save()
		}
		let fileManager: FileManager = .default
		let (imageCache, labelCache): (URL, URL) = try cache(mnist: mnist)
		let label: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let image: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		guard fileManager.createFile(atPath: label.path, contents: nil, attributes: nil) else { throw ErrorCases.cache }; defer { try?fileManager.removeItem(at: label) }
		guard fileManager.createFile(atPath: image.path, contents: nil, attributes: nil) else { throw ErrorCases.cache }; defer { try?fileManager.removeItem(at: image) }
		let labelHandle: FileHandle = try FileHandle(forUpdating: label); defer { labelHandle.closeFile() }
		let imageHandle: FileHandle = try FileHandle(forUpdating: image); defer { imageHandle.closeFile() }
		try Data(contentsOf: labelCache, options: .mappedIfSafe).gunzip(to: labelHandle); labelHandle.seek(toFileOffset: 0)
		try Data(contentsOf: imageCache, options: .mappedIfSafe).gunzip(to: imageHandle); imageHandle.seek(toFileOffset: 0)
		let labelheader: [UInt32] = try labelHandle.readArray(count: 2)
		let imageheader: [UInt32] = try imageHandle.readArray(count: 4)
		let labelheads: [Int] = labelheader.map { Int(UInt32(bigEndian: $0)) }
		let imageheads: [Int] = imageheader.map { Int(UInt32(bigEndian: $0)) }
		guard
			let labelcount: Int = labelheads[safe: 1],
			let imagecount: Int = imageheads[safe: 1],
			let rows: Int = imageheads[safe: 2],
			let cols: Int = imageheads[safe: 3], labelcount == imagecount else {
				throw MNISTError.format
		}
		
		let count: Int = min(labelcount, imagecount)
		let bytes: Int = rows * cols
		try Array(repeating: (), count: count).forEach {
			let label: UInt8 = try labelHandle.readElement()
			let pixel: Data = try imageHandle.readData(count: bytes)
			let image: Image = Image(in: context)
			image.domain = MNIST.domain
			image.family = mnist.family
			image.handle = Int(label)
			image.option = [:]
			
			image.height = UInt16(rows)
			image.width = UInt16(cols)
			image.rowBytes = UInt32(cols)
			image.format = kCIFormatA8
			image.data = pixel
		}
		try context.save()
		notification?.success(build: mnist)
	}
	private func update(mnist: MNIST) throws {
		func dispatch(context: NSManagedObjectContext) {
			do {
				try update(mnist: mnist, context: context)
			} catch {
				failure(error: error)
			}
		}
		func dispatch() {
			do {
				let (image, label): (URL, URL) = try cache(mnist: mnist)
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
	@objc private func mnistrain(image mnist: URL) throws {
		try FileManager.default.moveItem(at: mnist, to: cache(mnist: .train).image)
		try update(mnist: .train)
	}
	@objc private func mnistrain(label mnist: URL) throws {
		try FileManager.default.moveItem(at: mnist, to: cache(mnist: .train).label)
		try update(mnist: .train)
	}
	@objc private func mnist10k(image mnist: URL) throws {
		try FileManager.default.moveItem(at: mnist, to: cache(mnist: .t10k).image)
		try update(mnist: .t10k)
	}
	@objc private func mnist10k(label mnist: URL) throws {
		try FileManager.default.moveItem(at: mnist, to: cache(mnist: .t10k).label)
		try update(mnist: .t10k)
	}
	private func selector(mnist: MNIST, key: String) throws -> String {
		switch(mnist, key) {
		case (.train, imageKey):
			return #selector(mnistrain(image:)).description
		case (.train, labelKey):
			return #selector(mnistrain(label:)).description
		case (.t10k, imageKey):
			return #selector(mnist10k(image:)).description
		case (.t10k, labelKey):
			return #selector(mnist10k(label:)).description
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
			try update(mnist: mnist)
		}
	}
}
