//
//  SpotifyController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 11/14/20.
//

import Foundation

class SpotifyController: UIResponder, SPTSessionManagerDelegate {
    
    // MARK: Constructor and variables
    
    private var clientID: String!
    private var clientSecret: String!
    private var redirectURI: URL!
    
    var accessToken: String!
    var refreshToken: String!
    var codeVerifier: String!
    
    var sessionManager: SPTSessionManager!
    
    init(clientID: String, clientSecret: String, redirectURI: URL) {
        super.init()
        
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        
        let refreshToken = UserDefaults.standard.string(forKey: "refreshToken")
        if refreshToken != nil {
            refreshAccessToken(refreshToken: refreshToken!)
        } else {
            initSessionManager()
        }
    }
    
    // MARK: Session Manager Related
    
    func initSessionManager() {
        let configuration = SPTConfiguration(clientID: self.clientID, redirectURL: self.redirectURI)
        configuration.playURI = ""
        
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
    }
    
    func connect() {
        if sessionManager == nil {
            initSessionManager()
        }
        
        if (self.refreshToken == nil || self.refreshToken == "N/A") && sessionManager != nil {
            let scope: SPTScope = [.userReadCurrentlyPlaying]
            sessionManager.initiateSession(with: scope, options: .clientOnly)
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
    
    var task: URLSessionDataTask!
    
    func resetAccessAndRefreshTokens() {
        self.accessToken = "N/A"
        self.refreshToken = "N/A"
        UserDefaults.standard.set(nil, forKey: "refreshToken")
    }
    
    func getAccessAndRefreshTokens(accessCode: String) {
        if clientID != nil && clientSecret != nil && redirectURI != nil && codeVerifier != nil {
            getAccessAndRefreshTokens(clientID: clientID, clientSecret: clientSecret, redirectURI: redirectURI, accessCode: accessCode, codeVerifier: codeVerifier) { (data, error) in
                if error != nil || data == nil {
                    self.resetAccessAndRefreshTokens()
                    return
                } else {
                    if let accessToken = data!["access_token"] as? String,
                       let refreshToken = data!["refresh_token"] as? String {
                        self.accessToken = accessToken
                        self.refreshToken = refreshToken
                        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
                        return
                    } else {
                        self.resetAccessAndRefreshTokens()
                        return
                    }
                }
            }
        } else {
            self.resetAccessAndRefreshTokens()
            return
        }
    }
    
    private func getAccessAndRefreshTokens(clientID: String, clientSecret: String, redirectURI: URL, accessCode: String, codeVerifier: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let spotifyAuthKey = "Basic \((clientID + ":" + clientSecret).data(using: .utf8)!.base64EncodedString())"
        request.allHTTPHeaderFields = ["Authorization": spotifyAuthKey, "Content-Type": "application/x-www-form-urlencoded"]
        var requestBodyComponents = URLComponents()
        
        requestBodyComponents.queryItems = [URLQueryItem(name: "client_id", value: clientID), URLQueryItem(name: "grant_type", value: "authorization_code"), URLQueryItem(name: "code", value: accessCode), URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString), URLQueryItem(name: "code_verifier", value: codeVerifier), URLQueryItem(name: "scope", value: "user-read-currently-playing"),]
        request.httpBody = requestBodyComponents.query?.data(using: .utf8)
        
        task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completion(nil, error)
            }
            guard let data = data else {
                return completion(nil, nil)
            }
            
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return completion(json, nil)
        }
        task.resume()
    }
    
    func refreshAccessToken(refreshToken: String) {
        self.refreshToken = refreshToken
        if clientID != nil && clientSecret != nil && redirectURI != nil {
            refreshAccessToken(clientID: clientID, clientSecret: clientSecret, redirectURI: redirectURI, refreshToken: refreshToken) { (data, error) in
                if error != nil || data == nil {
                    self.resetAccessAndRefreshTokens()
                    return
                } else {
                    if let accessToken = data!["access_token"] as? String,
                       let refreshToken = data!["refresh_token"] as? String {
                        self.accessToken = accessToken
                        self.refreshToken = refreshToken
                        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
                        return
                    } else {
                        self.resetAccessAndRefreshTokens()
                        return
                    }
                }
            }
        } else {
            self.resetAccessAndRefreshTokens()
            return
        }
    }
    
    private func refreshAccessToken (clientID: String, clientSecret: String, redirectURI: URL, refreshToken: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let spotifyAuthKey = "Basic \((clientID + ":" + clientSecret).data(using: .utf8)!.base64EncodedString())"
        request.allHTTPHeaderFields = ["Authorization": spotifyAuthKey, "Content-Type": "application/x-www-form-urlencoded"]
        var requestBodyComponents = URLComponents()
        
        requestBodyComponents.queryItems = [URLQueryItem(name: "client_id", value: clientID), URLQueryItem(name: "grant_type", value: "refresh_token"), URLQueryItem(name: "refresh_token", value: refreshToken),]
        request.httpBody = requestBodyComponents.query?.data(using: .utf8)
        
        task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completion(nil, error)
            }
            guard let data = data else {
                return completion(nil, nil)
            }
            
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return completion(json, nil)
        }
        task.resume()
    }
    
    public func getCurrentAlbum(completion: @escaping ([String: Any])->()) {
        if accessToken == nil {
            return completion(["retry":"Access token not set"])
        } else if accessToken == "N/A" {
            return completion(["error":"Invalid access token"])
        }
        
        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            guard error == nil else {
                return completion(["error":error?.localizedDescription ?? "An error occurred when fetching data from the Spotify API"])
            }
            guard let data = data else {
                return completion(["error":"The Spotify API did not return any data"])
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if let error = json["error"] as? [String: Any] {
                        if let message = error["message"] as? String {
                            if message == "Invalid access token" && self.refreshToken != nil {
                                self.refreshAccessToken(refreshToken: self.refreshToken)
                            } else {
                                return completion(["error":message])
                            }
                        }
                    } else {
                        if let item = json["item"] as? [String: Any] {
                            if let album = item["album"] as? [String: Any] {
                                return completion(album)
                            }
                        }
                    }
                }
                return completion(["error":"An error occurred when fetching data from the Spotify API"])
            } catch {
                return completion(["nothing_playing":"Nothing is playing on Spotify. Please play something"])
            }
        })
        task.resume()
    }
}

extension URL {
    public var queryParameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
    }
}
