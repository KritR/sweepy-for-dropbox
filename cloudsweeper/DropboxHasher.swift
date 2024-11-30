//
//  DropboxHasher.swift
//  cloudsweeper
//
//  Created by Krithik Rao on 11/9/22.
//

import Foundation
import CryptoKit

extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

struct DropboxContentHasher: HashFunction {
    typealias Digest = SHA256Digest

    public static var blockByteCount: Int = 4 * 1024 * 1024
        
    var overallHasher: SHA256
    var blockHasher: SHA256
    var blockPos: Int
    
    init() {
        overallHasher = SHA256.init();
        blockHasher = SHA256.init();
        blockPos = 0;
    }
    
    public func finalize() -> SHA256Digest {
        var newFinal = overallHasher
        if blockPos > 0 {
            blockHasher.finalize().withUnsafeBytes { data in
                newFinal.update(bufferPointer: data)
            }
            // newFinal.update(data: blockHasher.finalize().data)
        }
        let _ = overallHasher.finalize()
        return newFinal.finalize()
    }
    
    public mutating func update(bufferPointer: UnsafeRawBufferPointer)
    {
        var newDataPos: Int = 0;
        while newDataPos < bufferPointer.count {
            if self.blockPos == DropboxContentHasher.blockByteCount {
                blockHasher.finalize().withUnsafeBytes { data in
                    overallHasher.update(bufferPointer: data)
                }
                // overallHasher.update(data: blockHasher.finalize().data)
                blockHasher = SHA256()
                blockPos = 0
            }
            
            let spaceInBlock = DropboxContentHasher.blockByteCount - blockPos
            let dataInBuffer = bufferPointer.count - newDataPos
            let newDataEndPos = newDataPos + min(spaceInBlock, dataInBuffer)
            
            let part = bufferPointer[newDataPos..<newDataEndPos]
            part.withUnsafeBytes { data in
                blockHasher.update(bufferPointer: data)
            }

            blockPos += part.count
            newDataPos += part.count
        }
    }
}
