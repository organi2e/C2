//
//  Container+CIFAR10.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Accelerate
import CoreData
import Foundation
private let rowsKey: String = "rows"
private let colsKey: String = "cols"
private let metaKey: String = "meta"
public extension Container {
	struct CIFAR10: OptionSet {
		public let rawValue: UInt8
		public init(rawValue arg: UInt8) {
			rawValue = arg
		}
		static let batch1: CIFAR10 = CIFAR10(rawValue: 0b0000001)
		static let batch2: CIFAR10 = CIFAR10(rawValue: 0b0000010)
		static let batch3: CIFAR10 = CIFAR10(rawValue: 0b0000100)
		static let batch4: CIFAR10 = CIFAR10(rawValue: 0b0001000)
		static let batch5: CIFAR10 = CIFAR10(rawValue: 0b0010000)
		static let batch6: CIFAR10 = CIFAR10(rawValue: 0b0100000)
		static let test:   CIFAR10 = CIFAR10(rawValue: 0b1000000)
		static let all:    CIFAR10 = CIFAR10(rawValue: 0b1111111)
	}
}
public extension Container {
	/*public func build(cifar10: CIFAR10) throws {
		
	}*/
}
