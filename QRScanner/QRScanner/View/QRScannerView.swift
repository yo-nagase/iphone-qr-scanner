//
//  QRScannerView.swift
//  QRCodeReader
//
//  Created by KM, Abhilash a on 08/03/19.
//  Copyright © 2019 KM, Abhilash. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

/// Delegate callback for the QRScannerView.
protocol QRScannerViewDelegate: class {
    func qrScanningDidFail()
    func qrScanningSucceededWithCode(_ str: String?)
    func qrScanningDidStop()
}

class QRScannerView: UIView {
    var readBarcodeView:[UIView] = [UIView.init(frame: CGRect(x: 0, y:0, width: 10, height: 10)),
                                    UIView.init(frame: CGRect(x: 0, y:0, width: 10, height: 10)),
                                    UIView.init(frame: CGRect(x: 0, y:0, width: 10, height: 10)),
                                    UIView.init(frame: CGRect(x: 0, y:0, width: 10, height: 10))]
    var readBarcodeViewDescriptionLabel = [UILabel.init(frame: CGRect(x: 0, y:0, width: 10, height: 10)),
                                           UILabel.init(frame: CGRect(x: 0, y:0, width: 10, height: 10)),
                                           UILabel.init(frame: CGRect(x: 0, y:0, width: 10, height: 10)),
                                           UILabel.init(frame: CGRect(x: 0, y:0, width: 10, height: 10))]
    //振動
    let feedbackGenerator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var dataList: [AnyHashable] = []
    
    weak var delegate: QRScannerViewDelegate?
    
    /// capture settion which allows us to start and stop scanning.
    var captureSession: AVCaptureSession?
    
    // Init methods..
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        doInitialSetup()
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        doInitialSetup()
    }
    
    //MARK: overriding the layerClass to return `AVCaptureVideoPreviewLayer`.
    override class var layerClass: AnyClass  {
        return AVCaptureVideoPreviewLayer.self
    }
    override var layer: AVCaptureVideoPreviewLayer {
        return super.layer as! AVCaptureVideoPreviewLayer
    }
}
extension QRScannerView {
    
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    func startScanning() {
       captureSession?.startRunning()
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
        delegate?.qrScanningDidStop()
    }
    
    /// Does the initial setup for captureSession
    private func doInitialSetup() {
        feedbackGenerator.prepare()
        clipsToBounds = true
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch let error {
            print(error)
            return
        }
        
        if (captureSession?.canAddInput(videoInput) ?? false) {
            captureSession?.addInput(videoInput)
        } else {
            scanningDidFail()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession?.canAddOutput(metadataOutput) ?? false) {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
            //metadataOutput.metadataObjectTypes = [.qr]
        } else {
            scanningDidFail()
            return
        }
        
        
        for i in 0 ..< readBarcodeView.count{
             readBarcodeView[i].backgroundColor = .green
             readBarcodeView[i].layer.zPosition = .greatestFiniteMagnitude
             self.addSubview(readBarcodeView[i])
        }
      
        
        self.layer.session = captureSession
        self.layer.videoGravity = .resizeAspectFill
        
        captureSession?.startRunning()
    }
    
    func scanningDidFail() {
        delegate?.qrScanningDidFail()
        captureSession = nil
    }
    
    func found(code: String) {
        //print("QRコードが見つかりました。" + code)
        //delegate?.qrScanningSucceededWithCode(code)
    }
    
    func trunLightOn(flg: Bool){

        let avDevice = AVCaptureDevice.default(for: AVMediaType.video)!
        
        if avDevice.hasTorch {
            do {
                // torch device lock on
                try avDevice.lockForConfiguration()
                
                if (flg){
                    // flash LED ON
                    avDevice.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    // flash LED OFF
                    avDevice.torchMode = AVCaptureDevice.TorchMode.on
                }
            
                // torch device unlock
                avDevice.unlockForConfiguration()
                
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    
    }
    
    
}


//バーコードが見つかると呼ばれる。
extension QRScannerView: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection ) {
   
        //stopScanning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            //震える
           // AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
           
            feedbackGenerator.impactOccurred()
          
            print("バーコードがみつかりました。" + stringValue,
                  metadataObjects.count)
            
            //trunLightOn()
            found(code: stringValue)
        }
        
        for i in 0 ..< metadataObjects.count{
            if let metadataObject = metadataObjects[i] as? AVMetadataMachineReadableCodeObject{
                
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                print("✩"+stringValue)
                let fullSize = self.layer.bounds

                self.readBarcodeView[i].frame.origin.x = fullSize.width - metadataObject.bounds.maxY * fullSize.width
                self.readBarcodeView[i].frame.origin.y = metadataObject.bounds.minX * fullSize.height
                self.readBarcodeView[i].frame.size.width = metadataObject.bounds.width * fullSize.width * 2
                self.readBarcodeView[i].frame.size.height = metadataObject.bounds.height * fullSize.height / 2

                self.readBarcodeViewDescriptionLabel[i].frame.origin.x = fullSize.width - metadataObject.bounds.maxY * fullSize.width
                self.readBarcodeViewDescriptionLabel[i].frame.origin.y = metadataObject.bounds.minX * fullSize.height - 20
                self.readBarcodeViewDescriptionLabel[i].frame.size.width = 100
                self.readBarcodeViewDescriptionLabel[i].frame.size.height = 20
               // self.readBarcodeViewDescriptionLabel[i].text = textData[i]
                dataList.append(stringValue)
            }
        }
        //データ重複を取り除く
        dataList = Array(Set(dataList))
        print(dataList.count)
//        let a = dataList.count
//         for i in 0 ..< textData.count{
//             dataList.append(textData[i])
//         }
//         dataList = Array(Set(dataList))
    }
    
}
