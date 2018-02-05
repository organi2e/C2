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
	public enum MNIST {
		case train
		case t10k
		static var domain: String {
			return String(describing: self)
		}
		internal var family: String {
			return String(describing: self)
		}
	}
	public enum MNISTError: Error {
		case format
		case nomatch
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
	private func update(mnist: MNIST, context: NSManagedObjectContext, image: URL, label: URL) throws {
		try context.fetch(domain: MNIST.domain, family: mnist.family).forEach(context.delete)
		let (imagehead, imagebody): (Data, Data) = try FileHandle(forReadingFrom: image).gunzip().split(cursor: 4 * MemoryLayout<UInt32>.stride)
		let imageheader: [Int] = imagehead.toArray().map{Int(UInt32(bigEndian: $0))}
		guard let rows: Int = imageheader[safe: 2], let cols: Int = imageheader[safe: 3] else {
			throw MNISTError.format
		}
		let pixels: [Data] = imagebody.chunk(width: Int(rows*cols))
		let (labelhead, labelbody): (Data, Data) = try FileHandle(forReadingFrom: label).gunzip().split(cursor: 2 * MemoryLayout<UInt32>.stride)
		let labelheader: [Int] = labelhead.toArray().map{Int(UInt32(bigEndian: $0))}
		let labels: [UInt8] = labelbody.toArray()
		guard imageheader[1] == labelheader[1], labels.count == pixels.count else {
			throw MNISTError.nomatch
		}
		let entityName: String = String(describing: Image.self)
		try zip(labels, pixels).forEach {
			guard let image: Image = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)as?Image else {
				throw MNISTError.entity
			}
			image.domain = MNIST.domain
			image.family = mnist.family
			image.series = Int($0)
			image.option = [:]
			
			image.height = UInt16(rows)
			image.width = UInt16(cols)
			image.rowBytes = UInt32(cols)
			image.format = kCIFormatR8
			image.data = $1
		}
		try context.save()
		notification?.success(build: mnist)
	}
	private func update(mnist: MNIST, image: URL, label: URL) {
		func dispatch(context: NSManagedObjectContext) {
			do {
				try update(mnist: mnist, context: context, image: image, label: label)
				try FileManager.default.removeItem(at: image)
				try FileManager.default.removeItem(at: label)
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
private extension Data {
	func split(cursor: Int) -> (Data, Data) {
		return(subdata(in: startIndex..<startIndex.advanced(by: cursor)), subdata(in: startIndex.advanced(by: cursor)..<endIndex))
	}
	func chunk(width: Int) -> Array<Data> {
		return stride(from: 0, to: count, by: width).map {
			return subdata(in: index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: $0 + width))
		}
	}
	func toArray<T>() -> Array<T> {
		return withUnsafeBytes {
			Array<T>(UnsafeBufferPointer<T>(start: $0, count: count / MemoryLayout<T>.stride))
		}
	}
}
private extension Array {
	func chunk(width: Int) -> Array<SubSequence> {
		return stride(from: 0, to: count, by: width).map {
			return self[$0..<$0+width]
		}
	}
}
