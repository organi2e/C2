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
	@NSManaged var data: Data
	@NSManaged var name: String
}
extension Content {
	@NSManaged var index: Index
}
