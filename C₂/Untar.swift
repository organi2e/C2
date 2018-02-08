//
//  Untar.swift
//  C2
//
//  Created by Kota Nakano on 2/8/18.
//
internal struct Untar {
	let supplier: Supplier
	init(supplier ref: Supplier) {
		supplier = ref
	}
}
extension Untar {
	func scan(handle: (String, Data) throws -> Void) throws {
		while let data: Data = try?supplier.readData(count: 512), data.count == 512 {
			let name: String = data.toString()
			switch data[156] {
			case 48:
				let char: [CChar] = data[124..<136].toArray()
				let byte: String = String(cString: char)
				guard let size: Int = Int(byte, radix: 8), 0 < size else {
					continue
				}
				let rounded: Int = 512 * ( ( size + 511 ) / 512 )
				try handle(name, supplier.readData(count: rounded)[0..<size])
			default:
				break
			}
		}
	}
}
