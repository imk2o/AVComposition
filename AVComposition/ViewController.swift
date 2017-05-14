//
//  ViewController.swift
//  AVComposition
//
//  Created by k2o on 2017/05/09.
//  Copyright © 2017年 imk2o. All rights reserved.
//

import UIKit
import AssetsLibrary
import Photos

class ViewController: UIViewController {
    var compositor: Compositor!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.compositor = Compositor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadAssetsButtonDidTap() {
        self.requestPickImageFromPhotoLibrary()
    }

    @IBAction func exportButtonDidTap() {
        self.compositor.export { (exporter) in
            guard
                exporter.status == .completed,
                let exportURL = exporter.outputURL
            else {
                print("error: \(exporter.error)")
                return
            }

            var placeHolder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({ 
                let changeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: exportURL)
                if let changeRequest = changeRequest {
                    // maybe set date, location & favouriteness here?
                    placeHolder = changeRequest.placeholderForCreatedAsset
                }
            }) { (success, error) in
                //placeHolder?.localIdentifier    // should identify asset from now on?
                print("finished: \(error)")
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
import AVFoundation
import Photos
import MobileCoreServices
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {

        if
            let nsMediaURL = info[UIImagePickerControllerMediaURL] as? NSURL,
            let mediaURL = nsMediaURL.absoluteURL
        {
            let asset = AVAsset(url: mediaURL)
            self.compositor.add(asset: asset)
        } else if
            let livePhoto = info[UIImagePickerControllerLivePhoto] as? PHLivePhoto,
            let asset = livePhoto.value(forKey: "videoAsset") as? AVURLAsset
        {
            self.compositor.add(asset: asset)
        }

        self.dismiss(animated: true) {
            if self.compositor.assets.count < 2 {
                self.requestPickImageFromPhotoLibrary()
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: -
    
    // カメラで撮影
    func requestPickImageFromCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return
        }
        
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { [weak self] (result) in
            if result {
                DispatchQueue.main.async {
                    self?.pickImage(from: .camera)
                }
            }
        }
    }
    
    // 写真ライブラリから選択
    func requestPickImageFromPhotoLibrary() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            return
        }
        
        PHPhotoLibrary.requestAuthorization { [weak self] (status) in
            if status == .authorized {
                DispatchQueue.main.async {
                    self?.pickImage(from: .photoLibrary)
                }
            }
        }
    }
    
    private func pickImage(from sourceType: UIImagePickerControllerSourceType) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = sourceType
        imagePickerController.mediaTypes = [
            kUTTypeMovie as String,
            kUTTypeImage as String,
            kUTTypeLivePhoto as String
        ]
//        imagePickerController.allowsEditing = true
        
        self.present(imagePickerController, animated: true, completion: nil)
    }
}
