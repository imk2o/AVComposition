//
//  Compositor.swift
//  AVComposition
//
//  Created by k2o on 2017/05/09.
//  Copyright © 2017年 imk2o. All rights reserved.
//

import AVFoundation

class Compositor {
    fileprivate(set) var assets: [AVAsset] = []
    fileprivate let transitionDuration: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600)
    
    init() {
    }
    
    func add(asset: AVAsset) {
        self.assets.append(asset)
    }
    
    func export(completion handler: @escaping (AVAssetExportSession) -> Void) {
        // Live photoのsizeに対し、transformのtx,tyが正しくないのを補正する
        // sizeが(1308, 980)に対し、tx, tyには1440, 1080といった値が入ってくる
//        func fixedTransform(_ transform: CGAffineTransform, size: CGSize) -> CGAffineTransform {
//            var transform = transform
//            print("t_in = \(transform)")
//            if transform.isPortrait {
//                // portrait
//                if transform.tx > 0 {
//                    transform.tx = size.height
//                }
//                if transform.ty > 0 {
//                    transform.ty = size.width
//                }
//            } else {
//                // landscape
//                if transform.tx > 0 {
//                    transform.tx = size.width
//                }
//                if transform.ty > 0 {
//                    transform.ty = size.height
//                }
//            }
//            print("t_out = \(transform)")
//            
//            return transform
//        }
        
        let mixerComposition = AVMutableComposition()
        
        var exportWidth: CGFloat = 1440
        var exportHeight: CGFloat = 1080
        var videoInstructions: [AVVideoCompositionLayerInstruction] = []
        var audioParameters: [AVAudioMixInputParameters] = []
        
        var isLandscape = true
        var timeRange: CMTimeRange!
        for asset in self.assets {
            if timeRange == nil {
                timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
            } else {
                let startTime = CMTimeSubtract(timeRange.end, self.transitionDuration)
                timeRange = CMTimeRange(start: startTime, duration: asset.duration)
            }
            
            // Video Track
            let videoTrack = mixerComposition.addMutableTrack(
                withMediaType: AVMediaTypeVideo,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            guard let assetVideoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first else {
                fatalError()
            }
            print("track size: \(assetVideoTrack.naturalSize)")
            print("transform: \(assetVideoTrack.preferredTransform)")
            
            // deprecate: 出力サイズはソースに依らない
            exportWidth = max(assetVideoTrack.naturalSize.width, exportWidth)
            exportHeight = max(assetVideoTrack.naturalSize.height, exportHeight)
            
            try! videoTrack.insertTimeRange(
                CMTimeRangeMake(kCMTimeZero, asset.duration),
                of: assetVideoTrack,
                at: timeRange.start
            )

            if assetVideoTrack.preferredTransform.isPortrait {
                isLandscape = false
            }
            
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
//            // 動画トラックのorientationを正規化
//            instruction.setTransform(assetVideoTrack.preferredTransform, at: kCMTimeZero)
//            var transform = fixedTransform(
//                assetVideoTrack.preferredTransform,
//                size: assetVideoTrack.naturalSize
//            )
            // 出力解像度に合わせてスケーリング
            let s = exportWidth / assetVideoTrack.naturalSize.width
            let transform = assetVideoTrack.preferredTransform.scaledBy(x: s, y: s)
            instruction.setTransform(transform, at: kCMTimeZero)
            // 動画トラックをクロスフェードで切替
            let fadeoutStartTime = CMTimeSubtract(timeRange.end, self.transitionDuration)
            instruction.setOpacityRamp(
                fromStartOpacity: 1,
                toEndOpacity: 0,
                timeRange: CMTimeRange(start: fadeoutStartTime, duration: self.transitionDuration)
            )

            videoInstructions.append(instruction)
            
            // Audio Track
            let audioTrack = mixerComposition.addMutableTrack(
                withMediaType: AVMediaTypeAudio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            guard let assetAudioTrack = asset.tracks(withMediaType: AVMediaTypeAudio).first else {
                fatalError()
            }
            
            try! audioTrack.insertTimeRange(
                CMTimeRangeMake(kCMTimeZero, asset.duration),
                of: assetAudioTrack,
                at: timeRange.start
            )
            
            let parameters = AVMutableAudioMixInputParameters(track: assetAudioTrack)
            // 音声トラックをクロスフェードで切替
            parameters.setVolumeRamp(
                fromStartVolume: 1,
                toEndVolume: 0,
                timeRange: CMTimeRange(start: fadeoutStartTime, duration: self.transitionDuration)
            )
            
            audioParameters.append(parameters)
        }
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: kCMTimeZero, end: timeRange.end)
        mainInstruction.layerInstructions = videoInstructions
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTime(value: 1, timescale: 30)	// 30fps
        mainComposition.renderSize = isLandscape ?
            CGSize(width: exportWidth, height: exportHeight) :
            CGSize(width: exportHeight, height: exportWidth)
    
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioParameters
    
        guard
            let documentURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else
        {
            fatalError()
        }

        let exportURL = documentURL
            .appendingPathComponent("\(Date().timeIntervalSince1970)")
            .appendingPathExtension("mov")

        guard let exporter = AVAssetExportSession(
            asset: mixerComposition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            fatalError()
        }
        exporter.outputURL = exportURL
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        exporter.videoComposition = mainComposition
        exporter.audioMix = audioMix
        exporter.shouldOptimizeForNetworkUse = true
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                handler(exporter)
            }
        }
    }
}

private extension CGAffineTransform {
    var isPortrait: Bool {
        return self.a == 0.0 && self.d == 0.0 &&
            (self.b == 1.0 || self.b == -1.0) &&
            (self.c == 1.0 || self.c == -1.0)
    }
}
