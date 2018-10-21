//
//  BarCodeViewController.swift
//  nfcTest
//
//  Created by Claus Wolf on 29.09.18.
//  Copyright © 2018 Claus Wolf. All rights reserved.
//

import UIKit
import AVFoundation
import Contacts
import ContactsUI
import MessageUI
import EventKitUI
import SafariServices

class BarCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, CNContactViewControllerDelegate, MFMessageComposeViewControllerDelegate, EKEventViewDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var scanAgainButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var addContactButton: UIButton!
    @IBOutlet weak var callButton: UIButton!
    
    var eventStore : EKEventStore!
    var myEvent = MyEvent()
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var qrCodeFrameView = UIView()
    var contact = CNContact()
    var newContact = CNMutableContact()
    var isCall = false
    var isEvent = false
    var number = String()
    var message = String()
    
    var myBook : [BookData] = []
        
    override func viewDidLoad() {
        super.viewDidLoad()

        scanButton.layer.cornerRadius = 10
        scanAgainButton.layer.cornerRadius = 10
        addContactButton.layer.cornerRadius = 10
        callButton.layer.cornerRadius = 10
        
        messageLabel.layer.borderWidth = 2
        messageLabel.layer.cornerRadius = 10
        messageLabel.layer.borderColor = UIColor.lightGray.cgColor
        
        scanButton.isHidden = true
        scanAgainButton.isHidden = true
        addContactButton.isHidden = true
        callButton.isHidden = true
        
        // Do any additional setup after loading the view.
        
        checkCameraAuthorization()
        
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        messageLabel.text = ""
        if (captureSession?.isRunning == false) {
            checkCameraAuthorization()
        }
        scanButton.isHidden = true
        scanAgainButton.isHidden = true
        addContactButton.isHidden = true
        callButton.isHidden = true
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
        scanButton.isHidden = true
        scanAgainButton.isHidden = true
        addContactButton.isHidden = true
        callButton.isHidden = true
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
    }
    
    func found(code: String, object: AVMetadataMachineReadableCodeObject) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75){
            self.qrCodeFrameView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            self.qrCodeFrameView.removeFromSuperview()
            self.previewLayer.removeFromSuperlayer()
            
            self.scanAgainButton.isHidden = false
            self.messageLabel.text = code
            self.activityIndicator.isHidden = true
            
            if object.type.rawValue == "org.gs1.EAN-13"{
                //found EAN
                self.getISBNMetadata(isbn: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("VCARD"){
                self.handleVCard(vcard: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("MECARD"){
                self.handleMeCard(mecard: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("WIFI"){
                self.handleWiFi(wifi: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("tel:"){
                self.handleCall(number: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("smsto:"){
                self.handleSMS(code: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("BEGIN:VEVENT"){
                self.handleVEvent(code: code)
            }
            else if object.type.rawValue == "org.iso.QRCode" && code.contains("http"){
                self.handleURL(code: code)
            }
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
    
    func handleVCard(vcard: String){
        if let data = vcard.data(using: .utf8) {
            do{
                let contacts = try CNContactVCardSerialization.contacts(with: data)
                if let myContact = contacts.first {
                    self.contact = myContact
                    self.addContactButton.isHidden = false
                    self.activityIndicator.stopAnimating()
                    self.activityIndicator.isHidden = true
                    messageLabel.text = "VCARD für \(self.contact.givenName) \(self.contact.familyName) gefunden"
                    addContactButton.setTitle("Kontakt hinzufügen", for: .normal)
                }
                
            }
            catch{
                // Error Handling
                print(error.localizedDescription)
            }
        }
    }
    
    func handleMeCard(mecard: String){
        let myMeCard = mecard.replacingOccurrences(of: "MECARD:", with: "")
        let components = myMeCard.split(separator: ";", omittingEmptySubsequences: false)
        var labelText = "MeCard for "
        for c in components {
            if c.contains("N:"){
                let fullName = c.replacingOccurrences(of: "N:", with: "")
                let nameComponents = fullName.split(separator: " ")
                if nameComponents.count == 2 {
                    self.newContact.givenName = "\(nameComponents[0])"
                    self.newContact.familyName = "\(nameComponents[1])"
                }
                else if nameComponents.count == 3 {
                    self.newContact.givenName = "\(nameComponents[0])"
                    self.newContact.middleName = "\(nameComponents[1])"
                    self.newContact.familyName = "\(nameComponents[2])"
                }
                else {
                    self.newContact.givenName = "\(nameComponents)"
                }
                labelText += "\(fullName) found"
            }
            else if c.contains("TEL:"){
                let contactPhone = CNLabeledValue(label: CNLabelHome, value: CNPhoneNumber(stringValue: c.replacingOccurrences(of: "TEL:", with: "")))
                self.newContact.phoneNumbers = [contactPhone]
            }
            else if c.contains("EMAIL:"){
                let eMailString = c.replacingOccurrences(of: "EMAIL:", with: "")
                let contactEMail = CNLabeledValue(label: CNLabelHome, value: eMailString as NSString)
                self.newContact.emailAddresses = [contactEMail]
                
            }
            else if c.contains("BDAY:"){
                let birthdayString = c.replacingOccurrences(of: "BDAY:", with: "")
                if birthdayString.count == 8 {
                    let birthdayComponents = getDateComponents(dateString : birthdayString)
                    let userCalendar = Calendar.current
                    let someDateTime = userCalendar.dateComponents([Calendar.Component.year, Calendar.Component.month, Calendar.Component.day], from: birthdayComponents)
                    self.newContact.birthday = someDateTime
                }
            }
            else if c.contains("ADR:"){
                let address = c.replacingOccurrences(of: "ADR:", with: "")
                let addressResults = getAddress(from: address)
                if addressResults.count == 1 {
                    //self.newContact.postalAddresses
                    let contactAddress = CNMutablePostalAddress()
                    var home = CNLabeledValue<CNPostalAddress>()
                    for address in addressResults {
                        for (key, value) in address{
                            if key.rawValue == "ZIP"{
                                contactAddress.postalCode = value
                            }
                            else if key.rawValue == "Street"{
                                contactAddress.street = value
                            }
                            else if key.rawValue == "City"{
                                contactAddress.city = value
                            }
                            else if key.rawValue == "Country"{
                                contactAddress.country = value
                            }
                            else if key.rawValue == "State"{
                                contactAddress.state = value
                            }
                            else{
                                print("unknown")
                            }
                        home = CNLabeledValue<CNPostalAddress>(label:CNLabelHome, value:contactAddress)
                        }
                    }
                    self.newContact.postalAddresses = [home]
                }
                else{
                    
                }
            }
            else if c.contains("URL:"){
                let url = c.replacingOccurrences(of: "URL:", with: "")
                let contactUrl = CNLabeledValue(label: CNLabelHome, value: url as NSString)
                self.newContact.urlAddresses = [contactUrl]
            }
            else{
                print("other: \(c)\n")
            }
        }
        self.contact = self.newContact as CNContact
        self.addContactButton.setTitle("Kontakt hinzufügen", for: .normal)
        self.addContactButton.isHidden = false
        messageLabel.text = labelText
    }
    
    func handleWiFi(wifi: String){
        let wiFiCode = wifi.replacingOccurrences(of: "WIFI:", with: "")
        let components = wiFiCode.split(separator: ";", omittingEmptySubsequences: false)
        var text = "Wir haben ein WLAN für Dich gefunden!\n\n";
        for c in components{
            if c.contains("S:"){
                // that is our SSID
                text += "SSID: \(c.replacingOccurrences(of: "S:", with: ""))\n"
            }
            else if c.contains("T:"){
                //that is our encryption protocol
                text += "Protokoll: \(c.replacingOccurrences(of: "T:", with: ""))\n"
            }
            else if c.contains("P:"){
                //that is our password
                text += "Passwort:\n\(c.replacingOccurrences(of: "P:", with: ""))\n\n"
                UIPasteboard.general.string = c.replacingOccurrences(of: "P:", with: "")
            }
        }
        text += "Das Passwort haben wir schon für Dich kopiert und in die Zwischenablage gelegt"
        messageLabel.text = text
    }
    
    
    override func prepare(for segue: UIStoryboardSegue?, sender: Any?) {
        if (segue?.identifier == "bookDetailSegue") {
            let book = sender as! [BookData]
            let detailBookView = segue?.destination as! DetailedBookViewController
            detailBookView.book = book
        }
    }
  
    @IBAction func addContactTapped(_ sender: Any) {
        addContactForm(contact: self.contact)
    }
    
    
    func addContactForm(contact: CNContact) {
        self.navigationController?.isNavigationBarHidden = false
        let vc = CNContactViewController(forNewContact: contact)
        vc.delegate = self as CNContactViewControllerDelegate
        _ = self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        if contact == nil{
            _ = self.navigationController?.popViewController(animated: true)
        }
    }
    
    func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool {
        return true
    }
    
    func getDateComponents(dateString : String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyyMMdd"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        else {
            let date = Date()
            return date
        }
    }
    
    func getAddress(from dataString: String) -> [[NSTextCheckingKey: String]] {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
        let matches = detector.matches(in: dataString, options: [], range: NSRange(location: 0, length: dataString.utf16.count))
        
        var resultsArray =  [[NSTextCheckingKey: String]]()
        // put matches into array of Strings
        for match in matches {
            if match.resultType == .address,
                let components = match.addressComponents {
                resultsArray.append(components)
            } else {
                print("no components found")
            }
        }
        return resultsArray
    }
    
    func handleCall(number: String){
        self.number = number.replacingOccurrences(of: "tel:", with: "")
        self.message = ""
    
        self.messageLabel.text = "\(self.number)"
        
        self.isCall = true
        self.callButton.isHidden = false
        self.callButton.setTitle("Nummer anrufen", for: .normal)
    }
    
    func handleSMS(code: String){
        let data = code.replacingOccurrences(of: "smsto:", with: "")
        let components = data.split(separator: ":", omittingEmptySubsequences: false)
        
        self.number = "\(components[0])"
        self.message = "\(components[1])"
        
        self.messageLabel.text = "SMS an \(self.number) mit folgender Nachricht \n\n \(self.message) \n\n schreiben"
        
        self.isCall = false
        self.callButton.isHidden = false
        self.callButton.setTitle("SMS senden", for: .normal)
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func displayMessageInterface(number: String, message: String) {
        let composeVC = MFMessageComposeViewController()
        composeVC.messageComposeDelegate = self
        
        // Configure the fields of the interface.
        composeVC.recipients = [number]
        composeVC.body = message
        
        // Present the view controller modally.
        if MFMessageComposeViewController.canSendText() {
            self.present(composeVC, animated: true, completion: nil)
        } else {
            messageLabel.text = "Nachricht kann nicht geschickt werden"
        }
    }
    
    func handleVEvent(code: String){
        self.isEvent = true
       
        let data = code.replacingOccurrences(of: "BEGIN:VEVENT\n", with: "")
        let components = data.split(separator: "\n", omittingEmptySubsequences: false)
        
        for c in components {
            if c.contains("SUMMARY:"){
                // title of event
                myEvent.title = c.replacingOccurrences(of: "SUMMARY:", with: "")
            }
            else if c.contains("DESCRIPTION:"){
                // detailed description
                myEvent.notes = c.replacingOccurrences(of: "DESCRIPTION:", with: "")
            }
            else if c.contains("LOCATION:"){
                // location (string)
                myEvent.location = c.replacingOccurrences(of: "LOCATION:", with: "")
            }
            else if c.contains("DTSTART:"){
                // Start Date & Time as YYYYMMDDTHHMMSSZ
                let dateString = c.replacingOccurrences(of: "DTSTART:", with: "")
                myEvent.startDate = createDate(dateString: dateString)
            }
            else if c.contains("DTEND:"){
                // End Date & Time as YYYYMMDDTHHMMSSZ
                let dateString = c.replacingOccurrences(of: "DTEND:", with: "")
                myEvent.endDate = createDate(dateString: dateString)
            }
            else if c.contains("GEO:"){
                // LAT & LON - skipping for now
            }
        }
        
        callButton.isHidden = false
        let prettyDate = DateFormatter()
        prettyDate.dateFormat = "dd. MMM yyyy' um 'hh:mm 'Uhr'"
        let myDateString = prettyDate.string(from: myEvent.startDate)
        
        messageLabel.text = "Möglicher Kalendereintrag gefunden\n\n\(myEvent.title)\n\n am \(myDateString)"
        callButton.setTitle("Event hinzufügen", for: .normal)
        
    }
    
    func createDate(dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        if let someDateTime = formatter.date(from: dateString){
            return someDateTime
        }
        else {
            let someDateTime = formatter.date(from: "20000101T000000Z")!
            return someDateTime
        }
    }
    
    func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
        dismiss(animated: true, completion: nil)
    }
    
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        print("I am done")
        controller.dismiss(animated: true, completion: nil)
    }
    
    func eventEditViewControllerDefaultCalendar(forNewEvents controller: EKEventEditViewController) -> EKCalendar {

        let calendar = self.eventStore.defaultCalendarForNewEvents
        controller.title = "Event für \(calendar!.title)"
        return calendar!

    }
    
    func calendarAuthorizationGranted(){
        let eventVC = EKEventViewController.init()
        eventStore = EKEventStore.init()
        let myNewEvent = EKEvent(eventStore: eventStore)
        myNewEvent.title = myEvent.title
        myNewEvent.notes = myEvent.notes
        myNewEvent.startDate = myEvent.startDate
        myNewEvent.endDate = myEvent.endDate
        myNewEvent.location = myEvent.location
        eventVC.event = myNewEvent
        eventVC.delegate = self

        eventStore.requestAccess(to: .event, completion: {
            (granted, error) in
            if granted {
                let navCon = UINavigationController(rootViewController: eventVC)
                self.present(navCon, animated: true, completion: nil)
            }
            else{
                print("\(String(describing: error?.localizedDescription))")
                self.messageLabel.text = "Ohne Zugriff auf den Kalender geht es leider nicht"
            }
        })
    }
    
    @IBAction func cameraAccessRequestTapped(_ sender: Any) {
        checkCameraAuthorization()
    }
    
    @IBAction func scanAgainTapped(_ sender: Any) {
        view.setNeedsDisplay()
    }
    
    @IBAction func callButtonTapped(_ sender: Any) {
    
        if isEvent{
            calendarAuthorizationGranted()
            self.isEvent = false
        }
        else if isCall{
            if let url = URL(string: "tel://\(self.number)"), UIApplication.shared.canOpenURL(url) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
            self.isCall = false
        }
        else{
            displayMessageInterface(number: self.number, message: self.message)
        }
    
    }
    
    func handleURL(code: String){
        if let endOfPrefix = code.firstIndex(of: ":"){
            self.messageLabel.backgroundColor = UIColor.green
            let myProtocol = code[...endOfPrefix]
            if(myProtocol == "https:" || myProtocol == "http:"){
                let url = URL(string: code.trimmingCharacters(in: .whitespacesAndNewlines))
                let vc = SFSafariViewController(url: url!)
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    
}

class MyEvent {
    var title = String()
    var notes = String()
    var location = String()
    var startDate = Date()
    var endDate = Date()
    
}
