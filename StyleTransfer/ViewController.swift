//
//  ViewController.swift
//  StyleTransfer
//
//  Created by YEN HUNG CHENG on 2023/9/30.
//

import UIKit
import Vision
//import VideoToolbox

class ViewController: UIViewController {
    
    // 最後記得要去開啟權限 camera library
    
    var model: VNCoreMLModel!
    // 保存最原始的圖片
    var originalImage: UIImage?
    // 從相簿抓取到的圖片
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    enum StyleModel {
        case starryNight
        case cuphead
        case mosaic
    }
    
    // 選擇使用的模型
    func initializeModel(_ style: StyleModel) {
        let configuration = MLModelConfiguration()
        switch style {
        case .starryNight:
            model = try? VNCoreMLModel(for: starry_night_int8(configuration: configuration).model)
        case .cuphead:
            model = try? VNCoreMLModel(for: cuphead_int8(configuration: configuration).model)
        case .mosaic:
            model = try? VNCoreMLModel(for: mosaic_int8(configuration: configuration).model)
        }
    }
    
    // 將風格轉換後的圖片變回原本的尺寸
    func resizeImage(uiImage: UIImage, newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, true, uiImage.scale)
        uiImage.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    
    // 開啟相簿
    @IBAction func openLibrary(_ sender: UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    // 將照片進行保存
    @IBAction func shareImage(_ sender: UIBarButtonItem) {
        // 如果 imageView 上沒有圖像，則無法分享或儲存
        guard let imageToShare = imageView.image else {return}
        
        // 產生一個唯一的檔名，以便保存圖像
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "shared_image_\(timestamp).png"
        
        // 取得檔案的本機 URL 路徑
        guard let fileURL = saveImageToDocumentsDirectory(image: imageToShare, fileName: fileName) else {return}

        // 建立一個帶有圖像和文件 URL 的活動項目
        let itemsToShare: [Any] = [fileURL]
        
        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }
    
    // 儲存圖片到應用程式的文件目錄並傳回檔案的本機 URL
    func saveImageToDocumentsDirectory(image: UIImage, fileName: String) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        // 建置檔案的本機 URL，將檔案名稱新增至文件目錄路徑中
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // 將圖片轉換為 PNG 數據
        if let imageData = image.pngData() {
            do {
                try imageData.write(to: fileURL)
                return fileURL
            } catch {
                print("Error occurred during saving the image：\(error.localizedDescription)")
                return nil
            }
        }
        return nil
    }
    
    
    
    // 風格轉換
    @IBAction func cupheadTransfer(_ sender: UIButton) {
        // 選擇使用的模型
        initializeModel(.cuphead)
        // 使用 originalImage 確保圖片不被重複覆蓋特效
        guard let image = originalImage else {return}
        // 進行風格轉換
        if let styledImage = styleTransfer(image: image, model: model) {
            imageView.image = styledImage
        }
    }
    
    @IBAction func mosaicTransfer(_ sender: UIButton) {
        // 選擇使用的模型
        initializeModel(.mosaic)
        // 使用 originalImage 確保圖片不被重複覆蓋特效
        guard let image = originalImage else {return}
        // 進行風格轉換
        if let styledImage = styleTransfer(image: image, model: model) {
            imageView.image = styledImage
        }
        
    }
    
    @IBAction func starry_nightTransfer(_ sender: UIButton) {
        // 選擇使用的模型
        initializeModel(.starryNight)
        // 使用 originalImage 確保圖片不被重複覆蓋特效
        guard let image = originalImage else {return}
        // 進行風格轉換
        if let styledImage = styleTransfer(image: image, model: model) {
            imageView.image = styledImage
        }
        
    }
    
    // 風格轉換
    func styleTransfer(image: UIImage, model: VNCoreMLModel) -> UIImage? {
        // 將圖片轉成模型輸入的尺寸
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 640, height: 960), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: 640, height: 960))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // 將處理後的圖片轉換為像素緩衝區，以供模型輸入使用
        guard let pixelBuffer = newImage.toPixelBuffer(pixelFormatType: kCVPixelFormatType_32ARGB, width: 640, height: 960) else {
            return nil
        }
        
        let request = VNCoreMLRequest(model: model)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
            guard let result = request.results?.first as? VNPixelBufferObservation else {
                return nil
            }
            let styledImage = UIImage(ciImage: CIImage(cvPixelBuffer: result.pixelBuffer))
            
            // 將經過風格轉換後的照片尺寸，變回原本相片尺寸
            return resizeImage(uiImage: styledImage, newSize: image.size)
        } catch {
            print("Error occurred during style transfer: \(error)")
            return nil
        }
    }

    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            imageView.image = image
            // 保留一份原始相片
            originalImage = image
        }
        picker.dismiss(animated: true, completion: nil)
    }
}

extension UIImage {
    // 將UIImage轉換為CVPixelBuffer
    func toPixelBuffer(pixelFormatType: OSType, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: NSNumber] = [
            kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(booleanLiteral: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(booleanLiteral: true)
        ]
        
        // 創建CVPixelBuffer
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormatType, attrs as CFDictionary, &pixelBuffer)
        
        guard status == kCVReturnSuccess else {
            return nil
        }
        
        // 鎖定CVPixelBuffer 的基地址
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        // 創建CGContext
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        // 調整座標系
        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1.0, y: -1.0)
        
        // 繪製圖像
        UIGraphicsPushContext(context!)
        draw(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        UIGraphicsPopContext()
        
        // 解鎖基地址並返回CVPixelBuffer
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
