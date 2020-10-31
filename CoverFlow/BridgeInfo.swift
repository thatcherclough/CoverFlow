//
//  BridgeInfo.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/19/20.
//

import Foundation

struct BridgeInfo {
    let ipAddress:String
    let uniqueId:String
}

typealias BridgeInfoDiscoveryResult = BridgeInfo
extension BridgeInfoDiscoveryResult {
    init(withDiscoveryResult discoveryResult:PHSBridgeDiscoveryResult) {
        self.ipAddress = discoveryResult.ipAddress
        self.uniqueId = discoveryResult.uniqueId
    }
}
