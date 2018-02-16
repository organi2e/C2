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
	func index(series: Series) throws -> [Index] {
		let request: NSFetchRequest<Index> = NSFetchRequest<Index>(entityName: Index.entity().name ?? String(describing: Index.self))
		request.predicate = NSPredicate(format: "domain = %@ and family = %@", argumentArray: [type(of: series).domain, series.family])
		return try fetch(request)
	}
}
extension NSManagedObjectContext {
	
}
