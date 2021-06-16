//
//  SpotifyController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 11/14/20.
//

import Foundation

class SpotifyController: UIResponder, SPTSessionManagerDelegate {
    
    // MARK: Variables and constructor
    
    // TODO:
    // Storring the api location
    // Hosting api
    
    let apiBaseURL = "http://192.168.86.31:5000"
    
    var accessToken: String!
    var refreshToken: String!
    var codeVerifier: String!
    var sessionManager: SPTSessionManager!
    
    private var clientID: String!
    private var redirectURI: URL!
    
    init(clientID: String, clientSecret: String, redirectURI: URL) {
        super.init()
        
        self.clientID = clientID
        self.redirectURI = redirectURI
        
        if let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") {
            refreshAccessToken(refreshToken: refreshToken)
        } else {
            resetAccessAndRefreshTokens()
            initSessionManager()
        }
    }
    
    // MARK: Session Manager Related
    
    func initSessionManager() {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        configuration.playURI = ""
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
    }
    
    func connect() {
        if sessionManager == nil {
            initSessionManager()
        }
        
        if sessionManager != nil {
            sessionManager.initiateSession(with: [.userReadCurrentlyPlaying], options: .clientOnly)
        }
    }
    
    func getAccessCodeFromReturnedURL() -> String! {
        if SceneDelegate.returnedURL != nil {
            let url = SceneDelegate.returnedURL
            SceneDelegate.returnedURL = nil
            
            if url?.queryParameters != nil {
                if let accessCode = url!.queryParameters!["code"] {
                    let pkceProvider = sessionManager.value(forKey: "PKCEProvider")
                    codeVerifier = (pkceProvider as AnyObject).value(forKey: "codeVerifier") as? String
                    return accessCode
                }
            }
        }
        return nil
    }
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {}
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {}
    
    // MARK: Web-API Related
    
    func resetAccessAndRefreshTokens() {
        accessToken = "N/A"
        refreshToken = "N/A"
        UserDefaults.standard.set(nil, forKey: "refreshToken")
    }
    
    func getAccessAndRefreshTokens(accessCode: String) {
        if codeVerifier != nil {
            getAccessAndRefreshTokens(accessCode: accessCode, codeVerifier: codeVerifier) { data in
                if data == nil {
                    self.resetAccessAndRefreshTokens()
                    return
                } else {
                    if let accessToken = data!["access_token"] as? String,
                       let refreshToken = data!["refresh_token"] as? String {
                        self.setUserDefault(key: "refreshToken", value: refreshToken)
                        self.accessToken = accessToken
                        self.refreshToken = refreshToken
                        return
                    } else {
                        self.resetAccessAndRefreshTokens()
                        return
                    }
                }
            }
        } else {
            resetAccessAndRefreshTokens()
            return
        }
    }
    
    private func getAccessAndRefreshTokens(accessCode: String, codeVerifier: String, completion: @escaping ([String:Any]?) -> Void) {
        var urlComponents = URLComponents(string: "\(apiBaseURL)/api/spotify/swap")!
        urlComponents.queryItems = [
            URLQueryItem(name: "access_code", value: accessCode),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completion(nil)
            }
            guard let data = data else {
                return completion(nil)
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if json["error"] != nil {
                        return completion(nil)
                    } else {
                        return completion(json)
                    }
                } else {
                    return completion(nil)
                }
            } catch {
                return completion(nil)
            }
        }
        task.resume()
    }
    
    func refreshAccessToken(refreshToken: String) {
        self.refreshToken = refreshToken
        
        refreshAccessToken(refreshToken: refreshToken) { data in
            if data == nil {
                self.resetAccessAndRefreshTokens()
                return
            } else {
                if let accessToken = data!["access_token"] as? String,
                   let refreshToken = data!["refresh_token"] as? String {
                    self.setUserDefault(key: "refreshToken", value: refreshToken)
                    self.accessToken = accessToken
                    self.refreshToken = refreshToken
                    return
                } else {
                    self.resetAccessAndRefreshTokens()
                    return
                }
            }
        }
    }
    
    func setUserDefault(key: String, value: String) {
        setUserDefault(key: key, value: value) {
            if UserDefaults.standard.string(forKey: key) != value {
                self.setUserDefault(key: key, value: value)
            }
        }
    }

    func setUserDefault(key: String, value: String?, completion: ()->()) {
        UserDefaults.standard.setValue(value, forKey: key)
        return completion()
    }
    
    private func refreshAccessToken(refreshToken: String, completion: @escaping ([String: Any]?) -> Void) {
        var urlComponents = URLComponents(string: "\(apiBaseURL)/api/spotify/refresh")!
        urlComponents.queryItems = [
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completion(nil)
            }
            guard let data = data else {
                return completion(nil)
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if json["error"] != nil {
                        return completion(nil)
                    } else {
                        return completion(json)
                    }
                } else {
                    return completion(nil)
                }
            } catch {
                return completion(nil)
            }
        }
        task.resume()
    }
    
    public func getCurrentAlbum(completion: @escaping ([String: Any])->()) {
        if accessToken == nil {
            return completion(["retry": "Access token not set"])
        } else if accessToken == "N/A" {
            return completion(["error": "Invalid access token"])
        }
        
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "nil")", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            guard error == nil else {
                return completion(["error": error?.localizedDescription ?? "An error occurred when fetching data from the Spotify API"])
            }
            guard let data = data else {
                return completion(["error": "The Spotify API did not return any data"])
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if let error = json["error"] as? [String: Any] {
                        if let message = error["message"] as? String {
                            if message == "Invalid access token" && self.refreshToken != nil {
                                self.refreshAccessToken(refreshToken: self.refreshToken)
                            } else {
                                return completion(["error": message])
                            }
                        } else {
                            return completion(["error": "An error occurred when fetching data from the Spotify API"])
                        }
                    } else {
                        if let item = json["item"] as? [String: Any] {
                            if let album = item["album"] as? [String: Any] {
                                return completion(album)
                            }
                        }
                    }
                } else {
                    return completion(["error": "An error occurred when fetching data from the Spotify API"])
                }
            } catch {
                return completion(["nothing_playing": "Nothing is playing on Spotify. Start playing something"])
            }
        })
        task.resume()
    }
}

extension URL {
    public var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
    }
}
