//
//  Container+URLSessionDelegate.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Foundation
import os.log
extension Container: URLSessionDownloadDelegate {
	public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		do {
			if let error: Error = error {
				throw error
			}
		} catch {
			failure(error: error)
		}
	}
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		do {
			guard let description: String = downloadTask.taskDescription else {
				throw ErrorCases.description
			}
			let selector: Selector = Selector(stringLiteral: description)
			guard responds(to: selector) else {
				throw ErrorCases.selector
			}
			let error: NSErrorPointer = NSErrorPointer(nilLiteral: ())
			perform(selector, with: location, with: error)
			if let error: Error = error?.pointee {
				throw error
			}
		} catch {
			print(error)
			failure(error: error)
		}
	}
}

