//
//  ContentView.swift
//  cloudsweeper
//
//  Created by Krithik Rao on 11/2/22.
//

import SwiftUI
import SwiftyDropbox
import MediaCore
import Photos

struct ContentView: View {
    

    
    @State private var mediaPermission: PHAuthorizationStatus = .notDetermined
    
    @Binding var dropboxHashes: [String]
    @Binding var isDropboxAuthorized: Bool
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var pendingDeletion: [String] = []
    @State private var dropboxOperationInProgress = false
    @State private var photoOperationInProgress = false
    @State private var videoOperationInProgress = false
    
    @State private var dropboxPhotoCount: Int = 0
    @State private var dropboxVideoCount: Int = 0
    
    @State private var photoCount: Int = 0
    @State private var videoCount: Int = 0
    
    
    let saveAction: () -> Void
    
    let MAX_FOLDER_QUERY: UInt32 = 2000

    private var localOperationInProgress: Bool {
        photoOperationInProgress || videoOperationInProgress
    }
    
    private var operationInProgress: Bool {
        dropboxOperationInProgress || localOperationInProgress
    }
    
    var body: some View {

        VStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sweepy for Dropbox")
                    .padding()
                    .background(.black)
                    .foregroundColor(.white)
                    .monospaced()
                    .textCase(.lowercase)
                
                
                Button(!isDropboxAuthorized ? "Login with Dropbox" : "Logout of Dropbox", action: toggleSignIn)
                    .buttonStyle(BoxyButtonStyle())
                    .sensoryFeedback(.success, trigger: isDropboxAuthorized)
                
                Button("Find saved photos", action: findSavedPhotos).buttonStyle(BoxyButtonStyle()).disabled(!isDropboxAuthorized || operationInProgress)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Dropbox").textCase(.uppercase).fontWeight(.bold)
                        if (dropboxOperationInProgress) { ProgressView() }
                    }.padding(.bottom, 4)
                    Text("Photos: \(dropboxPhotoCount)").textCase(.lowercase).font(.system(size: 16))
                    Text("Videos: \(dropboxVideoCount)").textCase(.lowercase).font(.system(size: 16))
                    
                    
                    
                    HStack {
                        Text("Local").monospaced().textCase(.uppercase).fontWeight(.bold)
                        if (localOperationInProgress) { ProgressView() }
                    }.padding(.top, 30).padding(.bottom, 4)
                    Text("Photos: \(photoCount)").textCase(.lowercase).font(.system(size: 16))
                    Text("Videos: \(videoCount)").textCase(.lowercase).font(.system(size: 16))
                    
                    Text("\(pendingDeletion.count) Duplicates Found").padding(.top, 20)
                    
                }.padding(40).monospaced().opacity(photoCount == 0 ? 0.3 : 1)

            }.frame(maxHeight: .infinity, alignment: .top)
            VStack(alignment: .leading, spacing: 20) {
                Button("Cleanup photos", action: deleteDuplicatePhotos)
                    .buttonStyle(BoxyButtonStyle()).disabled(pendingDeletion.count == 0)
            }.padding(.bottom, 30)
        }.padding(30)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .inactive { saveAction() }
                if newPhase == .active {
                    mediaPermission = Media.currentPermission
                }
            }
    }
    
    func toggleSignIn() -> Void {
        if (!isDropboxAuthorized) {
            let scopeRequest = ScopeRequest(scopeType: .user, scopes: ["account_info.read","files.metadata.read"], includeGrantedScopes: false)
            DropboxClientsManager.authorizeFromControllerV2(
                UIApplication.shared,
                controller: nil,
                loadingStatusDelegate: nil,
                openURL: { (url: URL) -> Void in UIApplication.shared.open(url, options: [:], completionHandler: nil) },
                scopeRequest: scopeRequest
            )
        } else {
            DropboxClientsManager.resetClients()
            isDropboxAuthorized = false
        }
    }
    
    func listDropboxFolder(client: DropboxClient) async throws -> Files.ListFolderResult {
        return try await withCheckedThrowingContinuation { continuation in
            client.files.listFolder(path: "/Camera Uploads", limit: MAX_FOLDER_QUERY)
                .response { (response: Files.ListFolderResult?, error) in
                    if let response = response {
                        continuation.resume(with: .success(response))
                    }
                    else {
                        continuation.resume(throwing: error!)
                    }
                }
        }
    }
    
    func listDropboxFolder(client: DropboxClient, cursor: String) async throws -> Files.ListFolderResult
    {
        return try await withCheckedThrowingContinuation { continuation in
            client.files.listFolderContinue(cursor: cursor)
                .response { (response: Files.ListFolderResult?, error) in
                    if let response = response {
                        continuation.resume(with: .success(response))
                    }
                    else {
                        continuation.resume(throwing: error!)
                    }
                }
        }
    }
    
    func findSavedPhotos() -> Void {
        
        
        print("hello")
        Task {
            DispatchQueue.main.sync {
                pendingDeletion = []
            }
            do {
                if (mediaPermission != .authorized) {
                    try await requestMediaPermissions()
                }
                async let hashesCall = try getDropboxHashes()
                async let photoHashesCall = scanPhotos()
                async let videoHashesCall = scanVideos()
                
                let (hashes, photoHashes, videoHashes) = try await (hashesCall, photoHashesCall, videoHashesCall)
                DispatchQueue.main.async {
                    dropboxHashes = hashes
                    saveAction()
                }
                
                for hash in dropboxHashes {
                    if let id = photoHashes[hash] {
                        DispatchQueue.main.sync {
                            pendingDeletion.append(id)
                        }
                    } else if let id = videoHashes[hash] {
                        DispatchQueue.main.sync {
                            pendingDeletion.append(id)
                        }
                    }
                }
                
            } catch {
                print("Failed to find photos: \(error)")
            }
        }
    }
    
    func getDropboxHashes() async throws -> [String] {
        var hashes: [String] = [];
        DispatchQueue.main.sync {
            self.dropboxPhotoCount = 0
            self.dropboxVideoCount = 0
            dropboxOperationInProgress = true
        }
        
        defer {
            DispatchQueue.main.sync {
                dropboxOperationInProgress = false
            }
        }
        
        if let client = DropboxClientsManager.authorizedClient {
            var response = try await listDropboxFolder(client: client)
            
            while true {
                for entry in response.entries {
                    if let metaData = (entry as? Files.FileMetadata), let hash = metaData.contentHash {
                        hashes.append(hash)

                        switch fileType(forFilename: metaData.name) {
                        case .photo:
                            DispatchQueue.main.sync {
                                self.dropboxPhotoCount += 1
                            }
                        case .video:
                            DispatchQueue.main.sync {
                                self.dropboxVideoCount += 1
                            }
                        case .unknown:
                            print("Unknown file type. \(metaData.name)")
                        }
                    }
                }
                if response.hasMore {
                    response = try await listDropboxFolder(client: client, cursor: response.cursor)
                }
                else {
                    break
                }
            }
        }
        
        return hashes
    }

    
    func scanPhotos() async -> Dictionary<String, String> {
        DispatchQueue.main.sync {
            self.photoCount = 0
            self.photoOperationInProgress = true
        }
        defer {
            DispatchQueue.main.sync {
                self.photoOperationInProgress = false
            }
        }
        return await withTaskGroup(of: (String, String)?.self, returning: Dictionary<String,String>.self) { taskGroup in
            if let photos = Media.LazyPhotos.all {
                for i in 0..<photos.count  {
                    if let p = photos[i] {
                        guard p.metadata?.sourceType != .typeCloudShared else {
                            continue
                        }
                        taskGroup.addTask() {
                            return await withCheckedContinuation { continuation in
                                p.data { result in
                                    if case .success(let data) = result,  let id = p.identifier?.localIdentifier {
                                        continuation.resume(returning:  (id, DropboxContentHasher.hash(data: data).hexStr))
                                        DispatchQueue.main.async {
                                            self.photoCount += 1
                                        }
                                        return
                                    }
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                    }
                }
            }
            var imageHashes = Dictionary<String, String>()
            for await result in taskGroup {
                if let (id, phex) = result {
                    imageHashes[phex] = id
                }
            }
            return imageHashes
        }
    }
    
    func scanVideos() async -> Dictionary<String, String> {
        DispatchQueue.main.sync {
            self.videoCount = 0
            self.videoOperationInProgress = true
        }
        defer {
            DispatchQueue.main.sync {
                self.videoOperationInProgress = false
            }
        }
        return await withTaskGroup(of: (String, String)?.self, returning: Dictionary<String,String>.self) { taskGroup in
            if let videos = LazyVideos.all {
                // Todo something parallel
                for i in 0..<videos.count {
                    if let v = videos[i] {
                        guard v.metadata?.sourceType != .typeCloudShared else {
                            continue
                        }
                        taskGroup.addTask() {
                            return await withCheckedContinuation { continuation in
                                v.avAsset() { result in
                                    if case .success(let asset) = result {
                                        if let url = (asset as? AVURLAsset), let hash = dropboxHash(url: url.url),  let id = v.identifier?.localIdentifier {
                                            continuation.resume(returning: (id, hash))
                                            DispatchQueue.main.async {
                                                self.videoCount += 1
                                            }
                                            return
                                        }
                                    }
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                    }
                }
            }
            var videoHashes = Dictionary<String, String>()
            for await result in taskGroup {
                if let (id, phex) = result {
                    videoHashes[phex] = id
                }
            }
            return videoHashes
        }
    }
    
    func deleteDuplicatePhotos() -> Void {
        Task { @MainActor in
            do {
                try await requestPhotoDeletion(identifiers: pendingDeletion)
                pendingDeletion.removeAll()
            } catch {
                print("Failed to delete photos \(error)")
            }
        }
    }
    
    func requestPhotoDeletion(identifiers: [String]) async  throws -> Void {
        return try await withCheckedThrowingContinuation { continuation in
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }) { success, error in
                if (error != nil) {
                    continuation.resume(throwing: error!)
                    return
                }
                continuation.resume()
            }
        }
    }
    
    func requestMediaPermissions() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Media.requestPermission { result in
                continuation.resume(with: result)
            }
        }
    }
}

func dropboxHash(url: URL) -> String? {
    let bufferSize = 16*1024
    
    do {
        // Open file for reading:
        let file = try FileHandle(forReadingFrom: url)
        defer {
            file.closeFile()
        }
        
        // Create and initialize MD5 context:
        var hasher = DropboxContentHasher()
        
        // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                hasher.update(data: data)
                return true // Continue
            } else {
                return false // End of file
            }
        }) { }
        
        // Return the digest
        return hasher.finalize().hexStr
    } catch {
        print(error)
        
        return nil
    }
}


#Preview {
    struct Preview: View {
        @State var hashes: [String] = []
        @State var authorized = false
        var body: some View {
            ContentView(dropboxHashes: $hashes, isDropboxAuthorized: $authorized, saveAction: { })
        }
    }
    
    return Preview()
}
