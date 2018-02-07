//
//  Gunzip.swift
//  C2
//
//  Created by Kota on 2/8/18.
//
import Foundation
import Compression
internal class Gunzip {
    enum ErrorCases: Error {
        case lessdata
    }
    let data: Data
    let streamref: Data
    var seek: Int
    var rest: Data
    init(url: URL, options: Data.ReadingOptions = .alwaysMapped) throws {
        data = try Data(contentsOf: url, options: options)
        streamref = Data(capacity: MemoryLayout<compression_stream>.size)
        rest = Data()
        seek = 0
    }
}
extension Gunzip {
    func feed(byte: Int) throws -> Data {
        return Data()
    }
}
