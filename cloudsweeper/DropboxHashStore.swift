//
//  DropboxHashStore.swift
//  cloudsweeper
//
//  Created by Krithik Rao on 11/28/22.
//

import Foundation

class DropboxHashStore: ObservableObject {
    @Published var hashes: [String] = []
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false)
            .appendingPathComponent("dropboxhash.data")
    }
    
    static func load(completion: @escaping (Result<[String], Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURL = try fileURL()
                guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                    DispatchQueue.main.async {
                        completion(.success([]))
                    }
                    return
                }
                let savedHashes = try JSONDecoder().decode([String].self, from: file.availableData)
                DispatchQueue.main.async {
                    completion(.success(savedHashes))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    static func save(hashList: [String], completion: @escaping (Result<Int, Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(hashList)
                let outfile = try fileURL()
                try data.write(to: outfile)
                DispatchQueue.main.async {
                    completion(.success(hashList.count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

