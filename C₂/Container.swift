//
//  Container.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import CoreData
import os.log
public protocol Series {
	static var domain: String { get }
	var family: String { get }
}
extension Series {
	var domain: String {
		return type(of: self).domain
	}
}
public protocol Delegate {
	func failure(error: Error)
	func success(build: Series)
}
public class Container: NSPersistentContainer {
	enum ErrorCases: Error {
		case model
		case identifier
		case description
		case selector
		case dictionary
		case url
		case cache
		case implementation
		case entity
	}
	let facility: OSLog
	let bundle: Bundle
	let cache: URL
	let notification: Delegate?
	private let state: UserDefaults
	private var urlsession: URLSession
	init(directory: URL = Container.defaultDirectoryURL(), delegate: Delegate? = nil) throws {
		let fileManager: FileManager = .default
		let myClass: AnyClass = type(of: self)
		facility = OSLog(subsystem: Bundle.main.name ?? ProcessInfo.processInfo.processName, category: String(describing: myClass))
		bundle = Bundle(for: myClass)
		guard let model: NSManagedObjectModel = .mergedModel(from: [bundle]) else {
			throw ErrorCases.model
		}
		guard let identifier: String = bundle.bundleIdentifier else {
			throw ErrorCases.identifier
		}
		cache = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(identifier, isDirectory: true)
		try fileManager.createDirectory(at: cache, withIntermediateDirectories: true, attributes: nil)
		notification = delegate
		urlsession = .shared
		state = UserDefaults()
		super.init(name: identifier, managedObjectModel: model)
		var error: Error?
		loadPersistentStores {
			error = $1
		}
		if let error: Error = error {
			throw error
		}
		urlsession = URLSession(configuration: .background(withIdentifier: identifier), delegate: self, delegateQueue: nil)
	}
}
extension Container {
	public func download(url: URL) -> URLSessionDownloadTask {
		defer {
			state.set(true, forKey: url.absoluteString)
		}
		return urlsession.downloadTask(with: url)
	}
	public func isDownloading(url: URL) -> Bool {
		return state.bool(forKey: url.absoluteString)
	}
}
extension Container: URLSessionDelegate {
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		do {
			guard let url: URL = task.originalRequest?.url else {
				throw ErrorCases.url
			}
			defer {
				state.set(false, forKey: url.absoluteString)
			}
			if let error: Error = error {
				throw error
			}
		} catch {
			failure(error: error)
		}
	}
}
extension Container {
	func plist(series: Series) throws -> [String: Any] {
		guard let url: URL = bundle.url(forResource: type(of: series).domain, withExtension: "plist") else {
			throw ErrorCases.url
		}
		guard let dictionary: [String: Any] = try PropertyListSerialization.propertyList(from: Data(contentsOf: url, options: .mappedIfSafe), options: [], format: nil)as?[String: Any] else {
			throw ErrorCases.dictionary
		}
		return dictionary
	}
}
public extension Container {
	public func build(series: Series) throws {
		switch series {
		case let mnist as MNIST:
			try build(mnist: mnist)
		case let fashionMNIST as FashionMNIST:
			try build(fashionMNIST: fashionMNIST)
		case let cifar10 as CIFAR10:
			try build(cifar10: cifar10)
		case let oxfordIIIT as OxfordIIIT:
			try build(oxfordIIIT: oxfordIIIT)
		default:
			throw ErrorCases.implementation
		}
	}
}
internal extension Container {
	func success(with: Series, function: String = #function) {
		if let notification: Delegate = notification {
			notification.success(build: with)
		} else {
			os_log("success %{public}@, %{public}@", log: facility, type: .debug, String(describing: with), function)
		}
	}
	func failure(error: Error, function: String = #function) {
		if let notification: Delegate = notification {
			notification.failure(error: error)
		} else {
			os_log("failure %{public}@, %{public}@", log: facility, type: .debug, String(describing: error), function)
		}
	}
}
private extension Bundle {
	var name: String? {
		return infoDictionary?[kCFBundleNameKey as String]as?String
	}
}
