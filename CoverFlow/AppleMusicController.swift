//
//  AppleMusicController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 11/14/20.
//

import Foundation
import StoreKit
import MediaPlayer
import Keys

class AppleMusicController {
    
    // MARK: Variables and constructor
    
    let keys = CoverFlowKeys()
    var apiKey: String!
    var countryCode: String!
    let player = MPMusicPlayerController.systemMusicPlayer
    
    init() {
        getCountryCode()
        setApiKey()
    }
    
    func getCountryCode() {
        countryCode = "us"
        
        DispatchQueue.global(qos: .background).async {
            SKCloudServiceController().requestStorefrontCountryCode { countryCode, error in
                if countryCode != nil && error == nil {
                    self.countryCode = countryCode
                }
            }
        }
    }
    
    func setApiKey() {
        getApiKey { (apiKey) in
            self.apiKey = apiKey
        }
    }
    
    func getApiKey(completion: @escaping (String?) -> ()) {
        let url = URL(string: "\(keys.apiBaseUrl)/api/apple_music/key")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            guard error == nil else {
                return completion(nil)
            }
            guard let data = data else {
                return completion(nil)
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if let key = json["key"] as? String {
                        return completion(key)
                    } else {
                        return completion(nil)
                    }
                }
            } catch {
                return completion(nil)
            }
        })
        task.resume()
    }
    
    // MARK: Functions
    
    func getCurrentAlbumName() -> String {
        let nowPlaying: MPMediaItem? = player.nowPlayingItem
        let albumName = nowPlaying?.albumTitle
        if nowPlaying == nil || albumName == nil {
            return "nil"
        } else {
            return albumName!
        }
    }
    
    func getCurrentArtistName() -> String {
        let nowPlaying: MPMediaItem? = player.nowPlayingItem
        let artistName = (nowPlaying?.albumArtist != nil) ? nowPlaying?.albumArtist : nowPlaying?.artist
        if nowPlaying == nil || artistName == nil {
            return "nil"
        } else {
            return artistName!
        }
    }
    
    func getCoverFromAPI(albumName: String, artistName: String, completion: @escaping (String?)->()) {
        let searchTerm  = albumName.replacingOccurrences(of: " ", with: "+")
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.music.apple.com"
        components.path = "/v1/catalog/\(countryCode!)/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: searchTerm),
            URLQueryItem(name: "limit", value: "15"),
            URLQueryItem(name: "types", value: "albums"),
        ]
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey ?? "nil")", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            guard error == nil else {
                return completion(nil)
            }
            guard let data = data else {
                return completion(nil)
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if let results = json["results"] as? [String: Any] {
                        if let albums = results["albums"] as? [String: Any] {
                            if let data = albums["data"] as? NSArray {
                                for album in data {
                                    guard let albumJson = album as? [String: Any] else {
                                        continue
                                    }
                                    guard let attributes = albumJson["attributes"] as? [String: Any] else {
                                        continue
                                    }
                                    
                                    if (attributes["name"] as! String == albumName) && (attributes["artistName"] as! String == artistName) {
                                        guard let artwork = attributes["artwork"] as? [String: Any] else {
                                            continue
                                        }
                                        
                                        if var url = artwork["url"] as? String {
                                            url = url.replacingOccurrences(of: "{w}", with: "200")
                                            url = url.replacingOccurrences(of: "{h}", with: "200")
                                            return completion(url)
                                        } else {
                                            continue
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                if data.count > 0 {
                    return completion(nil)
                } else {
                    self.getApiKey { (apiKey) in
                        if apiKey == nil {
                            return completion(nil)
                        } else {
                            self.apiKey = apiKey
                            
                            self.getCoverFromAPI(albumName: albumName, artistName: artistName) { (url) in
                                return completion(url)
                            }
                        }
                    }
                }
            }
        })
        task.resume()
    }
}
