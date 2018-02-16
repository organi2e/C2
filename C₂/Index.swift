//
//  Index.swift
//  C2
//
//  Created by Kota Nakano on 2/12/18.
//
import CoreData
internal class Index: NSManagedObject {
	
}
extension Index {
	@NSManaged var domain: String
	@NSManaged var family: String
	@NSManaged var option: [String: Any]
	@NSManaged var label: String
}
extension Index {
	@NSManaged var contents: Set<Content>
}
extension NSManagedObjectContext {
	func label(series: Series) throws -> Set<String> {
		let request: NSFetchRequest<Index> = NSFetchRequest<Index>(entityName: Index.entityName)
		request.predicate = NSPredicate(format: "domain = %@ and family = %@", type(of: series).domain, series.family)
		return try Set<String>(fetch(request).map{$0.label})
	}
	func index(series: Series, labels: [String] = []) throws -> [Index] {
		let request: NSFetchRequest<Index> = NSFetchRequest<Index>(entityName: Index.entityName)
		let format: String = "domain = %@ and family = %@" + ( labels.isEmpty ? "" : "and (\([String](repeating: "label = %@", count: labels.count).joined(separator: " or ")))" )
		let values: [Any] = [type(of: series).domain, series.family] + labels
		request.predicate = NSPredicate(format: format, argumentArray: values)
		return try fetch(request)
	}
}
extension NSManagedObjectContext {
	
}
