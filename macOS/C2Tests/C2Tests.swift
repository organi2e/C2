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
			try container.build(series: Container.MNIST.train)
			wait(for: [build], timeout: 60 * 30)
		} catch {
			XCTFail(String(describing: error))
		}
	}
	func testMNIST() {
		
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
