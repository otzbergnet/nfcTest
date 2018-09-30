//
//  BookData.swift
//  nfcTest
//
//  Created by Claus Wolf on 30.09.18.
//  Copyright © 2018 Claus Wolf. All rights reserved.
//

import Foundation

struct BookAPI : Decodable {
    let results : String
    let data : [BookData]
}

struct BookData : Decodable {
    let url : String
    let author : String
    let title : String
    let publisher : String
    let pages : String
    let itemType : String
    let imageUrl : String
    let price : String
}
