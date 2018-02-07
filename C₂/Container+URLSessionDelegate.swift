//
//  Container+URLSessionDelegate.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Foundation
import os.log
extension Container: URLSessionDownloadDelegate {
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		do {
			guard let description: String = downloadTask.taskDescription else {
				throw ErrorCases.description
			}
			let selector: Selector = Selector(stringLiteral: description)
			guard responds(to: selector) else {
				throw ErrorCases.selector
			}
			try autoreleasepool {
				let error: NSErrorPointer = NSErrorPointer(nilLiteral: ())
				let result: Unmanaged<AnyObject> = perform(selector, with: location, with: error)
				defer {
					result.release()
				}
				if let error: Error = error?.pointee {
					throw error
				}
			}
		} catch {
			failure(error: error)
		}
	}
}

