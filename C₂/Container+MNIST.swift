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
		case entity
	}
}
private extension Container {
	private func cache(mnist: MNIST) throws -> (image: URL, label: URL) {
		let baseURL: URL = cache.appendingPathComponent(MNIST.domain, isDirectory: true).appendingPathComponent(mnist.family, isDirectory: true)
		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
		return(image: baseURL.appendingPathComponent(imageKey),
			   label: baseURL.appendingPathComponent(labelKey))
	}
}
private extension Container {
	private func update(mnist: MNIST, context: NSManagedObjectContext, image: URL, label: URL) throws {
		try context.fetch(series: mnist).forEach {
			context.delete($0)
			try context.save()
		}
		let labelHandle: FileHandle = try FileHandle(forReadingFrom: label)
		let imageHandle: FileHandle = try FileHandle(forReadingFrom: image)
		let labelheader: [UInt32] = try labelHandle.readArray(count: 2).map { UInt32(bigEndian: $0) }
		let imageheader: [UInt32] = try imageHandle.readArray(count: 4).map { UInt32(bigEndian: $0) }
		guard
			let labelcount: UInt32 = labelheader[safe: 1],
			let imagecount: UInt32 = imageheader[safe: 1],
			let rows: UInt32 = imageheader[safe: 2],
			let cols: UInt32 = imageheader[safe: 3], labelcount == imagecount else {
				throw MNISTError.format
		}
		let count: Int = Int(min(labelcount, imagecount))
		try Array(repeating: (), count: count).forEach {
			guard let image: Image = NSManagedObject(entity: Image.entity(), insertInto: context) as? Image else {
				throw MNISTError.entity
			}
			let pixel: Data = try imageHandle.readData(count: Int(rows * cols))
			let label: UInt8 = try labelHandle.readElement()
			
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
	private func update(mnist: MNIST, image: URL, label: URL) {
		func dispatch(context: NSManagedObjectContext) {
			do {
				let fileManager: FileManager = .default
				try update(mnist: mnist, context: context, image: image, label: label)
				try fileManager.removeItem(at: image)
				try fileManager.removeItem(at: label)
			} catch {
				notification?.failure(error: error)
			}
		}
		performBackgroundTask(dispatch)
	}
	private func update(mnist: MNIST) throws {
		func dispatch() {
			do {
				let (image, label): (URL, URL) = try cache(mnist: mnist)
				let fileManager: FileManager = .default
				guard fileManager.fileExists(atPath: image.path), fileManager.fileExists(atPath: label.path) else {
					return
				}
				let tmpImage: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
				let tmpLabel: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
				try fileManager.moveItem(at: image, to: tmpImage)
				try fileManager.moveItem(at: label, to: tmpLabel)
				update(mnist: mnist, image: tmpImage, label: tmpLabel)
			} catch {
				notification?.failure(error: error)
			}
		}
		viewContext.perform(dispatch)//execlusive execution
	}
}
private extension Container {
	@objc private func mnistrain(image mnist: URL) throws {
		try Data(contentsOf: mnist, options: .mappedIfSafe).gunzip(to: cache(mnist: .train).image)
		try update(mnist: .train)
	}
	@objc private func mnistrain(label mnist: URL) throws {
		try Data(contentsOf: mnist, options: .mappedIfSafe).gunzip(to: cache(mnist: .train).label)
		try update(mnist: .train)
	}
	@objc private func mnist10k(image mnist: URL) throws {
		try Data(contentsOf: mnist, options: .mappedIfSafe).gunzip(to: cache(mnist: .t10k).image)
		try update(mnist: .t10k)
	}
	@objc private func mnist10k(label mnist: URL) throws {
		try Data(contentsOf: mnist, options: .mappedIfSafe).gunzip(to: cache(mnist: .t10k).label)
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
			throw ErrorTypes.selector
		}
	}
}
extension Container {
	public func build(mnist: MNIST) throws {
		let fileManager: FileManager = .default
		let (imageURL, labelURL): (URL, URL) = try cache(mnist: mnist)
		guard let dictionary: [String: URL] = global[MNIST.domain]?[mnist.family] else {
			throw ErrorTypes.dictionary
		}
		let stable: Bool = try [(imageURL, imageKey), (labelURL, labelKey)].reduce(true) {
			guard !fileManager.fileExists(atPath: $1.0.path) else {
				return $0
			}
			guard let global: URL = dictionary[$1.1] else {
				throw ErrorTypes.url
			}
			let downloadTask: URLSessionDownloadTask = urlsession.downloadTask(with: global)
			downloadTask.taskDescription = try selector(mnist: mnist, key: $1.1)
			downloadTask.resume()
			return false
		}
		if stable {
			try update(mnist: mnist)
		}
	}
}
