//
//  Image.swift
//  C2
//
//  Created by Kota Nakano on 2/5/18.
//
import Accelerate
import CoreData
import CoreImage
public class Image: Content {
	
}
extension Image {
	@NSManaged var width: UInt16
	@NSManaged var height: UInt16
	@NSManaged var rowBytes: UInt32
	@NSManaged var format: CIFormat
	@NSManaged var data: Data
}
public extension Image {
	var size: NSSize {
		return NSMakeSize(CGFloat(width), CGFloat(height))
	}
	var vImage: vImage_Buffer {
		return data.withUnsafeMutableBytes {
			vImage_Buffer(data: $0, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: Int(rowBytes))
		}
	}
	var ciImage: CIImage {
		return CIImage(bitmapData: data, bytesPerRow: Int(rowBytes), size: size, format: format, colorSpace: nil)
	}
}
