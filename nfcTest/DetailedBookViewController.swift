//
//  DetailedBookViewController.swift
//  nfcTest
//
//  Created by Claus Wolf on 30.09.18.
//  Copyright © 2018 Claus Wolf. All rights reserved.
//

import UIKit
import SafariServices

class DetailedBookViewController: UIViewController {

    var book : [BookData] = []
    
    @IBOutlet weak var bookTitle: UILabel!
    @IBOutlet weak var bookAuthor: UILabel!
    @IBOutlet weak var bookPublisher: UILabel!
    @IBOutlet weak var bookPages: UILabel!
    @IBOutlet weak var bookPrice: UILabel!
    @IBOutlet weak var buyButton: UIButton!
    @IBOutlet weak var bookCover: UIImageView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        bookTitle.text = book[0].title
        bookAuthor.text = book[0].author
        bookPublisher.text = book[0].publisher
        if (book[0].pages != "") {
          bookPages.text = "\(book[0].pages) pages"
        }
        else{
            bookPages.text = ""
        }
        
        bookPrice.text = book[0].price
        if(book[0].imageUrl != ""){
            guard let url = URL(string: book[0].imageUrl) else {return}
            DispatchQueue.global().async {
                guard let data = try? Data(contentsOf: url) else {return}
                DispatchQueue.main.async {
                    self.bookCover.image = UIImage(data: data)
                }
            }
        }
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func buyButtonTapped(_ sender: Any) {
        let url = URL(string: book[0].url)
        let vc = SFSafariViewController(url: url!)
        self.present(vc, animated: true, completion: nil)
    }
    
    
}
