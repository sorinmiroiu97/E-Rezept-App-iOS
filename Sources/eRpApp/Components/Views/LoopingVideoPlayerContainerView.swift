//
//  Copyright (c) 2021 gematik GmbH
//  
//  Licensed under the EUPL, Version 1.2 or – as soon they will be approved by
//  the European Commission - subsequent versions of the EUPL (the Licence);
//  You may not use this work except in compliance with the Licence.
//  You may obtain a copy of the Licence at:
//  
//      https://joinup.ec.europa.eu/software/page/eupl
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the Licence is distributed on an "AS IS" basis,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the Licence for the specific language governing permissions and
//  limitations under the Licence.
//  
//

import AVKit
import SwiftUI

final class LoopingVideoPlayerContainerView: UIViewRepresentable {
    typealias UIViewType = PlayerView

    let url: URL
    var player: PlayerView?

    init(withURL url: URL) {
        self.url = url
    }

    func makeUIView(context _: Context) -> PlayerView {
        let newPlayer = PlayerView(withURL: url)
        player = newPlayer
        return newPlayer
    }

    func updateUIView(_ playerView: PlayerView, context _: Context) {
        player = playerView
    }

    class PlayerView: UIView {
        var player: AVPlayer? {
            get {
                playerLayer?.player
            }
            set {
                playerLayer?.player = newValue
            }
        }

        init(withURL url: URL) {
            super.init(frame: .zero)

            player = AVPlayer(playerItem: AVPlayerItem(url: url))
            if player?.currentItem?.currentTime() == player?.currentItem?.duration {
                player?.currentItem?.seek(to: .zero, completionHandler: nil)
            }
            player?.play()

            playerLayer?.contentsGravity = .resizeAspectFill
            playerLayer?.videoGravity = .resizeAspectFill

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(playerItemDidReachEnd(notification:)),
                                                   name: .AVPlayerItemDidPlayToEndTime,
                                                   object: player?.currentItem)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        var playerLayer: AVPlayerLayer? {
            layer as? AVPlayerLayer
        }

        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        @objc
        func playerItemDidReachEnd(notification _: Notification) {
            player?.currentItem?.seek(to: .zero, completionHandler: nil)
            player?.play()
        }
    }
}
