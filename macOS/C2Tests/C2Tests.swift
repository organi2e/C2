//
//  C2Tests.swift
//  C2Tests
//
//  Created by Kota Nakano on 2/5/18.
//

import XCTest
@testable import C2

class C2Tests: XCTestCase {
	let build: XCTestExpectation = XCTestExpectation(description: "build")
	var container: Container!
	override func setUp() {
		super.setUp()
		do {
			container = try Container(delegate: self)
//			try container.build(series: Container.CIFAR10.batch1)
//			wait(for: [build], timeout: 60 * 30)
		} catch {
			XCTFail(String(describing: error))
		}
	}
	func testMNIST() {
		
	}
	func testCIFAR10() {
		let context: NSManagedObjectContext = container.viewContext
		do {
			let labels: [String] = try Array(context.label(series: Container.CIFAR10.batch1))
			XCTAssert(labels.count == 10)
			
			let laboffset: Int = Int(arc4random_uniform(UInt32(labels.count)))
			
			let indices: [Index] = try context.index(series: Container.CIFAR10.batch1, labels: ["dog"])
			XCTAssert(indices.count == 1)
			
			guard let index: Index = indices.first else { throw "x" }
			XCTAssertFalse(index.contents.isEmpty)
			
			let images: [Image] = index.contents.flatMap { $0 as? Image }
			XCTAssert(index.contents.count == images.count)
			
			let imgoffset: Int = Int(arc4random_uniform(UInt32(images.count)))
			let image: Image = images[imgoffset]
			
			let ciContext: CIContext = CIContext()
			try ciContext.writeTIFFRepresentation(of: image.ciImage,
												  to: URL(fileURLWithPath: "/tmp/\(index.label).tiff"),
												  format: kCIFormatBGRA8,
												  colorSpace: ciContext.workingColorSpace!,
												  options: [:])
			
		} catch {
			XCTFail(String(describing: error))
		}
	}
	/*
	func testContainer() {
	do {
	let images: [Image] = try container.viewContext.fetch(series: Container.MNIST.train)
	guard let image: Image = images.last else {
	throw NSError(domain: #file, code: #line, userInfo: nil)
	}
	try CIContext().writePNGRepresentation(of: image.ciImage,
	to: URL(fileURLWithPath: "/tmp/\(image.handle)-0.png"),
	format: kCIFormatRGBA8,
	colorSpace: CGColorSpaceCreateDeviceRGB(),
	options: [:])
	} catch {
	XCTFail(String(describing: error))
	}
	}
	*/
}
extension C2Tests: C2.Delegate {
	func success(build x: Series) {
		switch x {
		case is Container.MNIST:
			build.fulfill()
		case is Container.CIFAR10:
			build.fulfill()
		default:
			break
		}
		
	}
	func failure(error: Error) {
		print("failure", error)
	}
}

