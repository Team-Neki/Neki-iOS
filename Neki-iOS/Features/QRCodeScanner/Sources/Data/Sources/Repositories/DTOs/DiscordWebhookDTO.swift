//
//  DiscordWebhookDTO.swift
//  Neki-iOS
//
//  Created by SwainYun on 3/24/26.
//

import Foundation

public enum DiscordWebhookDTO {
    public struct Request: Encodable {
        struct Embed: Encodable {
            let title: String
            let description: String
            let color: Int
            let fields: [Field]
        }
        
        struct Field: Encodable {
            let name: String
            let value: String
            let inline: Bool
        }
        
        let embeds: [Embed]
        
        init(unsupportedURL: URL, user: User) {
            let host = unsupportedURL.host() ?? "Unknown Host"
            let embed = Embed(
                title: "🚨 미지원 QR 코드 스캔 감지",
                description: "새로운 포토부스 브랜드이거나 파싱에 실패한 URL입니다.",
                color: 16711680, // 빨강색 (Hex: FF0000)
                fields: [
                    Field(name: "🍎 Platform", value: "iOS", inline: true),
                    Field(name: "👤 User", value: "\(user.nickname) (ID: \(user.id))", inline: true),
                    Field(name: "🌐 Host", value: host, inline: true),
                    Field(name: "🔗 Full URL", value: unsupportedURL.absoluteString, inline: false),
                ]
            )
            
            self.embeds = [embed]
        }
    }
}
