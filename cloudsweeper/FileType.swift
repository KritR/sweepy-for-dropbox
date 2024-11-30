//
//  FileType.swift
//  cloudsweeper
//
//  Created by Krithik Rao on 9/17/24.
//

import Foundation

enum FileType {
    case photo
    case video
    case unknown
}

func fileType(forFilename filename: String) -> FileType {
    // Extract the file extension and convert it to lowercase
    let fileExtension = (filename as NSString).pathExtension.lowercased()
    
    // List of common photo and video extensions
    let photoExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif", "raw", "svg"]
    let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv", "webm", "m4v", "3gp", "mpeg", "mpg"]
    
    // Check if the extension matches any in the lists
    if photoExtensions.contains(fileExtension) {
        return .photo
    } else if videoExtensions.contains(fileExtension) {
        return .video
    } else {
        return .unknown
    }
}
