//
//  Container+Contents.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import CoreData
import os.log
private extension NSManagedObjectContext {
	private func make(series: Series) -> NSPredicate {
		let attributes: [(String, Any)] = [("domain", type(of: series).domain), ("family", series.family)]
		let format: String = attributes.map { "\($0.0) = %@" }.joined(separator: " and ")
		let arguments: [Any] = attributes.map { $1 }
		return NSPredicate(format: format, argumentArray: arguments)
	}
}
public extension NSManagedObjectContext {
	func count(series: Series) throws -> Int {
		guard let entityName: String = Content.entity().name else {
			throw ErrorCases.lessdata
		}
		let request: NSFetchRequest<Content> = NSFetchRequest(entityName: entityName)
		request.predicate = make(series: series)
		return try count(for: request)
	}
}
public extension NSManagedObjectContext {
	func fetch<T: Content>(series: Series) throws -> [T] {
		guard let entityName: String = T.entity().name else {
			throw ErrorCases.lessdata
		}
		let request: NSFetchRequest<T> = NSFetchRequest(entityName: entityName)
		request.predicate = make(series: series)
		return try fetch(request)
	}
}
