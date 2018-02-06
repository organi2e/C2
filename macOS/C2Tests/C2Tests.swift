//
//  C2Tests.swift
//  C2Tests
//
//  Created by Kota Nakano on 2/5/18.
//

import XCTest
@testable import C2

class C2Tests: XCTestCase {
	let trainExp: XCTestExpectation = XCTestExpectation(description: "train")
	//override func setUp() {
	func testEX() {
		//		super.setUp()
		do {
			let container: Container = try Container(delegate: self)
			//			guard try 60000 > container.viewContext.count(of: Image.self, domain: Container.MNIST.domain, family: Container.MNIST.train.family) else {
			try container.build(series: Container.MNIST.train)
			wait(for: [trainExp], timeout: 600)
			//				return
			//			}
		} catch {
			XCTFail(String(describing: error))
		}
	}
	/*
	func testContainer() {
	do {
	let container: Container = try Container(delegate: self)
	let images: [Image] = try container.viewContext.fetch(domain: Container.MNIST.domain, family: Container.MNIST.train.family)
	guard let image: Image = images.first else {
	throw NSError(domain: #file, code: #line, userInfo: nil)
	}
	try CIContext().writePNGRepresentation(of: image.ciImage,
	to: URL(fileURLWithPath: "/tmp/\(image.series)-0.png"),
	format: kCIFormatR8,
	colorSpace: CGColorSpaceCreateDeviceGray(),
	options: [:])
	} catch {
	XCTFail(String(describing: error))
	}
	}*/
}
extension C2Tests: C2.Delegate {
	func success(build: Any) {
		print(build)
		switch build {
		case C2.Container.MNIST.train:
			trainExp.fulfill()
		default:
			break
		}
		
	}
	func failure(error: Error) {
		print("failure", error)
	}
}

