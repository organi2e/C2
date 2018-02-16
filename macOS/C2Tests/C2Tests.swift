//
//  C2Tests.swift
//  C2Tests
//
//  Created by Kota Nakano on 2/5/18.
//

import XCTest
@testable import C2
extension Series {
	var key: String {
		return "\(domain).\(family)"
	}
}
extension NSManagedObjectContext {
	func test(series: Series, count: Int) throws {
		let baseURL: URL = FileManager.default.temporaryDirectory
		
		let labels: [String] = try Array(label(series: series))
		XCTAssert(labels.count == count)
		
		guard let label: String = labels[safe: Int(arc4random_uniform(UInt32(labels.count)))]else{throw"label"}
		let indices: [Index] = try index(series: series, labels: [label])
		XCTAssert(indices.count == 1)
		
		guard let index: Index = indices.first else{throw"index"}
		XCTAssertFalse(index.contents.isEmpty)
		
		let images: [Image] = index.contents.flatMap { $0 as? Image }
		XCTAssert(images.count == index.contents.count)
		
		guard let image: Image = images[safe: Int(arc4random_uniform(UInt32(images.count)))]else{throw"image"}
		
		let ciContext: CIContext = CIContext()
		try ciContext.writeTIFFRepresentation(of: image.ciImage,
											  to: baseURL.appendingPathComponent("\(series.domain)-\(series.family)-\(label)").appendingPathExtension("tiff"),
											  format: ciContext.workingFormat,
											  colorSpace: ciContext.workingColorSpace!,
											  options: [:])
		
	}
}
class C2Tests: XCTestCase {
	var builds: [String: XCTestExpectation] = [:]
	var container: Container!
	override func setUp() {
		super.setUp()
		do {
			container = try Container(delegate: self)
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	func dispatch(series: Series, count: Int) {
		let context: NSManagedObjectContext = container.viewContext
		do {
			if try context.index(series: series).isEmpty {
				let cond: XCTestExpectation = XCTestExpectation(description: series.key)
				builds.updateValue(cond, forKey: series.key)
				try container.build(series: series)
				wait(for: [cond], timeout: 60 * 30)
				context.reset()
			}
			try context.test(series: series, count: count)
		} catch {
			XCTFail(String(describing: error))
		}
	}
	func testMNIST() {
		dispatch(series: MNIST.train, count: 10)
	}
	func testFashionMNIST() {
		dispatch(series: FashionMNIST.train, count: 10)
	}
	func testCIFAR10() {
		dispatch(series: CIFAR10.batch1, count: 10)
	}
	func testOxfordIIIT() {
		dispatch(series: OxfordIIIT.pet, count: 0)
	}
}
extension C2Tests: C2.Delegate {
	func success(build: Series) {
		builds[build.key]?.fulfill()
	}
	func failure(error: Error) {
		print("failure", error)
	}
}

