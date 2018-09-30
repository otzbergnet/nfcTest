//
//  ViewController.swift
//  nfcTest
//
//  Created by Claus Wolf on 25.09.18.
//  Copyright © 2018 Claus Wolf. All rights reserved.
//

import UIKit
import CoreNFC
import SafariServices
import MessageUI

class ViewController: UIViewController, NFCNDEFReaderSessionDelegate, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBOutlet weak var button: UIButton!
    
    var nfcSession: NFCNDEFReaderSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        button.layer.cornerRadius = 10
        messageLabel.layer.borderWidth = 2
        messageLabel.layer.cornerRadius = 10
        messageLabel.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    @IBAction func scannPressed(_ sender: Any) {
        self.messageLabel.backgroundColor = UIColor.clear
        self.messageLabel.text = ""
        nfcSession = NFCNDEFReaderSession.init(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        nfcSession?.alertMessage = "Halten Sie die Karte in die Nähe der Kamera an Ihrem Telefon"
        nfcSession?.begin()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a success read
            // during a single tag read mode, or user canceled a multi-tag read mode session
            // from the UI or programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(
                    title: "Session Ungültig",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        
        // A new session instance is required to read new tags.
        self.nfcSession = nil
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Parse the card's information
        
        var result = ""
        for payload in messages[0].records {
            result += String.init(data: payload.payload.advanced(by: 1), encoding: .utf8)! // 1
        }
        
        
        DispatchQueue.main.async {
            self.messageLabel.text = result
            if let endOfPrefix = result.firstIndex(of: ":"){
                self.messageLabel.backgroundColor = UIColor.green
                let myProtocol = result[...endOfPrefix]
                if(myProtocol == "https:" || myProtocol == "http:"){
                    let url = URL(string: result.trimmingCharacters(in: .whitespacesAndNewlines))
                    let vc = SFSafariViewController(url: url!)
                    self.present(vc, animated: true, completion: nil)
                }
            }
            else if result.contains("@"){
                self.messageLabel.backgroundColor = UIColor.blue
                if MFMailComposeViewController.canSendMail() {
                    let email = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    let mail = MFMailComposeViewController()
                    mail.mailComposeDelegate = self
                    mail.setToRecipients([email])
                    mail.setSubject("Die wichtigste E-Mail, die Sie jemals schreiben werden")
                    mail.setMessageBody("<p></p><b>NDEF ScanTest App</b>", isHTML: true)
                    self.present(mail, animated: true, completion: nil)
                } else {
                    let alertController = UIAlertController(
                        title: "Funkion nicht verfügbar",
                        message: "Die E-Mail Funktion steht leider nicht zur Verfügung",
                        preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    DispatchQueue.main.async {
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            else{
                self.messageLabel.backgroundColor = UIColor.orange
            }
            
        }
        
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        switch result.rawValue {
        case MFMailComposeResult.cancelled.rawValue:
            print("Cancelled")
        case MFMailComposeResult.saved.rawValue:
            print("Saved")
        case MFMailComposeResult.sent.rawValue:
            print("Sent")
        case MFMailComposeResult.failed.rawValue:
            print("Error: \(String(describing: error?.localizedDescription))")
        default:
            break
        }
        controller.dismiss(animated: true, completion: nil)
    }
    
}

