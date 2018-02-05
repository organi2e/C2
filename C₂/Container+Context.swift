//
//  Container+Contents.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import CoreData
import os.log
private extension NSManagedObjectContext {
	private func make(domain: String, family: String) -> NSPredicate {
		let attributes: [(String, Any)] = [("domain", domain), ("family", family)]
		let format: String = attributes.map { "\($0.0) = %@" }.joined(separator: " and ")
		let arguments: [Any] = attributes.map { $1 }
		return NSPredicate(format: format, argumentArray: arguments)
	}
}
public extension NSManagedObjectContext {
	func count<T: Content>(of: T.Type, domain: String, family: String) throws -> Int {
		let request: NSFetchRequest<T> = NSFetchRequest(entityName: String(describing: T.self))
		request.predicate = make(domain: domain, family: family)
		return try count(for: request)
	}
}
public extension NSManagedObjectContext {
	func fetch<T: Content>(domain: String, family: String) throws -> [T] {
		let request: NSFetchRequest<T> = NSFetchRequest(entityName: String(describing: T.self))
		request.predicate = make(domain: domain, family: family)
		return try fetch(request)
	}
}
