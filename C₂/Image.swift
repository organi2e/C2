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
extension Image {
	public var la: la_object_t {
		return la_splat_from_float(1, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
	}
	public var array: [Float] {
		switch format {
		case kCIFormatAf, kCIFormatRf, kCIFormatRGBAf:
			return data.withUnsafeBytes {
				Array(UnsafeBufferPointer(start: $0, count: data.count / MemoryLayout<Float>.stride))
			}
		case kCIFormatA8, kCIFormatR8, kCIFormatARGB8, kCIFormatBGRA8:
			let result: [Float] = [Float](repeating: 0, count: data.count / MemoryLayout<UInt8>.stride)
			data.withUnsafeBytes {
				vDSP_vfltu8($0, 1, UnsafeMutablePointer(mutating: result), 1, vDSP_Length(result.count))
			}
			cblas_sscal(Int32(result.count), 1/256.0, UnsafeMutablePointer(mutating: result), 1)
			return result
		case kCIFormatA16, kCIFormatR16, kCIFormatRGBA16:
			let result: [Float] = [Float](repeating: 0, count: data.count / MemoryLayout<UInt16>.stride)
			data.withUnsafeBytes {
				vDSP_vfltu16($0, 1, UnsafeMutablePointer(mutating: result), 1, vDSP_Length(result.count))
			}
			cblas_sscal(Int32(result.count), 1/65536.0, UnsafeMutablePointer(mutating: result), 1)
			return result
		default:
			assertionFailure("CIImage format: \(format) has been not implemented")
			return Array<Float>()
		}
	}
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
