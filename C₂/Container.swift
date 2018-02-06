//
//  Container.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import CoreData
import os.log
public protocol Delegate {
	func failure(error: Error)
	func success(build: Any)
}
public protocol Series {
	static var domain: String { get }
	var family: String { get }
}
public class Container: NSPersistentContainer {
	enum ErrorTypes: Error {
		case model
		case identifier
		case description
		case selector
		case dictionary
		case url
		case cache
	}
	let facility: OSLog
	let defaults: UserDefaults
	let bundle: Bundle
	let global: [String: [String: [String: URL]]]
	let cache: URL
	let tmp: URL
	let notification: Delegate?
	var urlsession: URLSession
	init(directory: URL = Container.defaultDirectoryURL(), delegate: Delegate? = nil) throws {
		let fileManager: FileManager = .default
		let myClass: AnyClass = type(of: self)
		facility = OSLog(subsystem: Bundle.main.infoDictionary?[kCFBundleNameKey as String]as?String ?? ProcessInfo.processInfo.processName, category: String(describing: myClass))
		defaults = UserDefaults()
		bundle = Bundle(for: myClass)
		guard let model: NSManagedObjectModel = .mergedModel(from: [bundle]) else {
			throw ErrorTypes.model
		}
		guard let identifier: String = bundle.bundleIdentifier else {
			throw ErrorTypes.identifier
		}
		guard let property: URL = bundle.url(forResource: "Property", withExtension: "plist") else {
			throw ErrorTypes.url
		}
		guard let dictionary: [String: [String: [String: String]]] = try PropertyListSerialization.propertyList(from: Data(contentsOf: property), options: [], format: nil)as?[String: [String: [String: String]]] else {
			throw ErrorTypes.dictionary
		}
		global = try dictionary.mapValues {
			try $0.mapValues {
				try $0.mapValues {
					guard let url: URL = URL(string: $0) else {
						throw ErrorTypes.url
					}
					return url
				}
			}
		}
		cache = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(identifier, isDirectory: true)
		tmp = fileManager.temporaryDirectory
		try fileManager.createDirectory(at: cache, withIntermediateDirectories: true, attributes: nil)
		notification = delegate
		urlsession = .shared
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
internal extension Container {
	func success(with: Any, function: String = #function) {
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
