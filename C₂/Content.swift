//
//  Content.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import CoreData
public class Content: NSManagedObject {
	
}
extension Content {
	@NSManaged var domain: String
	@NSManaged var family: String
	@NSManaged var handle: Int
	@NSManaged var option: [String: Any]
}
