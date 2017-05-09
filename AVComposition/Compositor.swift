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
        
        let mixerComposition = AVMutableComposition()
        
        var exportWidth: CGFloat = 0
        var exportHeight: CGFloat = 0
        var videoInstructions: [AVVideoCompositionLayerInstruction] = []
        var audioParameters: [AVAudioMixInputParameters] = []
        
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
            exportWidth = max(assetVideoTrack.naturalSize.width, exportWidth)
            exportHeight = max(assetVideoTrack.naturalSize.height, exportHeight)
            
            try! videoTrack.insertTimeRange(
                CMTimeRangeMake(kCMTimeZero, asset.duration),
                of: assetVideoTrack,
                at: timeRange.start
            )
            
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            // 動画トラックのorientationを正規化
            instruction.setTransform(assetVideoTrack.preferredTransform, at: kCMTimeZero)
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
        mainComposition.frameDuration = CMTime(value: 1, timescale: 30)
        mainComposition.renderSize = CGSize(width: exportWidth, height: exportHeight)
    
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
