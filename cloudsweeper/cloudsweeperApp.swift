//
//  cloudsweeperApp.swift
//  cloudsweeper
//
//  Created by Krithik Rao on 11/2/22.
//

import SwiftUI
import SwiftyDropbox

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        DropboxClientsManager.setupWithAppKey("8vy9siqxwyukxwb")
        return true
    }
}

@main
struct cloudsweeperApp: App {
    
    @StateObject private var store = DropboxHashStore()
    @State private var authorized = false
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView(dropboxHashes: $store.hashes, isDropboxAuthorized: $authorized) {
                DropboxHashStore.save(hashList: store.hashes) { result in
                    if case .failure(let error) = result {
                        fatalError(error.localizedDescription)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onOpenURL { url in
                let oauthCompletion: DropboxOAuthCompletion = {
                  if let authResult = $0 {
                      switch authResult {
                      case .success:
                          authorized = true
                      case .cancel:
                          print("Authorization flow was manually canceled by user!")
                      case .error(_, let description):
                          print("Error: \(String(describing: description))")
                      }
                  }
                }
                DropboxClientsManager.handleRedirectURL(url, includeBackgroundClient: false, completion: oauthCompletion)
            }
            .onAppear {
                DropboxHashStore.load { result in
                    switch result {
                    case .failure(let error):
                        fatalError(error.localizedDescription)
                    case .success(let hashes):
                        store.hashes = hashes
                    }
                }
                authorized = DropboxClientsManager.authorizedClient != nil
            }
        }
    }
}
