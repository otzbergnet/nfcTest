//
//  BarCodeViewController.swift
//  nfcTest
//
//  Created by Claus Wolf on 29.09.18.
//  Copyright © 2018 Claus Wolf. All rights reserved.
//

import UIKit
import AVFoundation

class BarCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var scanAgainButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var qrCodeFrameView = UIView()
    
    var myBook : [BookData] = []
        
    override func viewDidLoad() {
        super.viewDidLoad()

        scanButton.layer.cornerRadius = 10
        scanAgainButton.layer.cornerRadius = 10
        messageLabel.layer.borderWidth = 2
        messageLabel.layer.cornerRadius = 10
        messageLabel.layer.borderColor = UIColor.lightGray.cgColor
        
        scanButton.isHidden = true
        scanAgainButton.isHidden = true
        
        // Do any additional setup after loading the view.
        
        checkCameraAuthorization()
        
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        messageLabel.text = ""
        if (captureSession?.isRunning == false) {
            checkCameraAuthorization()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
        previewLayer = nil
    }

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func checkCameraAuthorization(){
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            initializeCaptureSession()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    self.initializeCaptureSession()
                } else {
                    //access denied
                    self.scanButton.isHidden = false
                }
            })
        }
    }
    
    func initializeCaptureSession(){
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean13, .upce]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Initialize QR Code Frame to highlight the QR code
        
        
        qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
        qrCodeFrameView.layer.borderWidth = 4
        view.addSubview(qrCodeFrameView)
        view.bringSubviewToFront(qrCodeFrameView)
        
        captureSession.startRunning()
    }
    
    func failed() {
        let ac = UIAlertController(title: "Hat Dein Gerät eine Kamera?", message: "Leider konnten wir auf die Kamea nicht zugreifen. Sofern Dein Gerät keine Kamera hat, können wir diese Funktion leider nicht anbieten.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            let barCodeObject = previewLayer?.transformedMetadataObject(for: metadataObject)
            let bounds = barCodeObject?.bounds
            
            if bounds != nil {
                qrCodeFrameView.frame = bounds!
            }
            
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            AudioServicesPlaySystemSound(1108)
            self.found(code: stringValue, object: readableObject)
            
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75){
            self.qrCodeFrameView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            self.qrCodeFrameView.removeFromSuperview()
            self.previewLayer.removeFromSuperlayer()
            self.scanAgainButton.isHidden = false
        }
        
        
    }
    
    func found(code: String, object: AVMetadataMachineReadableCodeObject) {
        messageLabel.text = code
        if object.type.rawValue == "org.gs1.EAN-13"{
            //found EAN
            getISBNMetadata(isbn: code)
        }
    }

    func getISBNMetadata(isbn: String){
        if(isbn.count == 13 && validISBN13(isbn: isbn)){
            // valid ISBN 13
            askAmazon(query: isbn)
        }
        else if(!validISBN13(isbn: isbn)){
            // invalid ISBN 13
        }
        else{
            // likely not an ISBN to start with
        }
    }
    
    func validISBN13(isbn: String) -> Bool{
        
        let weight = [1, 3]
        var checksum = 0
        
        for i in 0..<12 {
            if let intCharacter = Int(String(isbn[isbn.index(isbn.startIndex, offsetBy: i)])) {
                checksum += weight[i % 2] * intCharacter
            }
        }
        
        if let checkDigit = Int(String(isbn[isbn.index(isbn.startIndex, offsetBy: 12)])) {
            return (checkDigit - ((10 - (checksum % 10)) % 10) == 0)
        }
        
        return false
        
    }
    
    func askAmazon(query: String) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        let jsonUrlString = "https://www.otzberg.net/amazon/index.php?searchIndex=All&q=\(query)&format=json"
        
        guard let url = URL(string: jsonUrlString) else {
            return
        }
        URLSession.shared.dataTask(with: url){ (data, response, err) in
            
            guard let data = data else {
                return
            }
            
            do{
                let amazonData = try JSONDecoder().decode(BookAPI.self, from: data)
                
                DispatchQueue.main.async {
                    if Int(amazonData.results) == 1{
                        for book in amazonData.data{
                            self.messageLabel.text = "\(book.author) \n \(book.title) \n ISBN: \(query) \n Amazon: \(book.price)"
                            self.myBook.append(book)
                            self.performSegue(withIdentifier: "bookDetailSegue", sender: self.myBook)
                        }
                    }
                    
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.activityIndicator.stopAnimating()
                    self.activityIndicator.isHidden = true
                    //all done
                }
            }
            catch let jsonError{
                print(jsonError)
                return
            }
            }.resume()
    }
    
    override func prepare(for segue: UIStoryboardSegue?, sender: Any?) {
        if (segue?.identifier == "bookDetailSegue") {
            let book = sender as! [BookData]
            let detailBookView = segue?.destination as! DetailedBookViewController
            detailBookView.book = book
        }
    }
    
    
    @IBAction func cameraAccessRequestTapped(_ sender: Any) {
        checkCameraAuthorization()
    }
    
    @IBAction func scanAgainTapped(_ sender: Any) {
        view.setNeedsDisplay()
    }
}
