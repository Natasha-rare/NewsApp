//
//  NewsGets.swift
//  Equalife
//
//  Created by Kostya Bunsberry on 20.07.2021.
//

import Foundation
import Alamofire
import SwiftyJSON
import SwiftSoup

class APIService {

    func getImagesArray(imgJson: JSON)->[String]{
        var imagesURL: [String] = []
        for (k, v) in imgJson{
            if k.contains("url"){
                imagesURL.append("https://meduza.io/\(v)")
            }
        }
        return imagesURL
    }
    
//    func getImagesDtf(text:String) -> [String]{
//        var imagesUrl:[String] = []
//        var src:String = ""
//
//        return imagesUrl
//    }

    func getContent(url:String, completion: @escaping (Article)->()) {
        var article: Article? = nil
        AF.request("https://meduza.io/api/v3/\(url)").responseJSON { responseJSON in
            switch responseJSON.result{
            case .success(let value):
                let json = JSON(value)["root"]
//                let url = json["url"].stringValue
                let images = self.getImagesArray(imgJson: json["image"])
                var text:String = ""
                do{
                  text = try SwiftSoup.parse(json["content"]["body"].stringValue).text()
                }
                catch let error {
                    print("Error: \(error)")
                }
                var dateFormat = DateFormatter()
                dateFormat.dateFormat = "yyyy-MM-dd"
                var date = dateFormat.date(from: json["pub_date"].stringValue)
                dateFormat.dateFormat = "dd-MM-yyyy"
                //print(images)
                article = Article(title: json["title"].stringValue,
                                         contents: text,
                                         imagesURL: images,
                                         author: "",
                                         date: dateFormat.string(from: date!),
                                         isSaved: false)
                if let articleRes = article {
                    completion(articleRes)
                }
            case let .failure(error):
                print(error)
            }
        }
    }
    
    func getWorldNews(page: Int, completion: @escaping(_ art: [Article])->()){
        var articles:[Article] = []
        AF.request("https://newsapi.org/v2/top-headlines?language=ru&pageSize=14&page=\(page+1)&apiKey=209637fc7d0549bdb08f9f490015c8c4").responseJSON { responseJSON in
            switch responseJSON.result {
            case .success(let value):
                let jsonAll = JSON(value)["articles"]
                for i in 0..<jsonAll.count{
                    let json = jsonAll[i]
                    var articleTxt = json["description"].stringValue
                    var imgs: [String] = []
                    // finding full text
                    do {
                        let myTextHtml = try String(contentsOf: URL(string: json["url"].stringValue)!, encoding: .utf8)
                        let doc: Document = try SwiftSoup.parse(myTextHtml)
                        let articleText = try doc.select("*[itemprop*='articleBody']")
                        articleTxt = try articleText.text()
                        if (articleTxt == ""){
                            articleTxt = try doc.select("div[class*='article__text']").text()
                            if (articleTxt == "")
                            { continue}
                        }
//                         get not all images + wrong imgs
                        let srcs: Elements = try articleText.select("img[class*='g-image']")
                        let srcsStringArray: [String] = srcs.array().map { try! $0.attr("src").description }
                        imgs = srcsStringArray
                        print("arrr", srcsStringArray)
                    } catch let error {
                        print("Error: \(error)")
                    }
                  
                    if (!(json["urlToImage"].stringValue == "")){
                        imgs.append(json["urlToImage"].stringValue)}
                    //print("imggs", imgs)
                    let dateFormat = DateFormatter()
                    dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    let date = dateFormat.date(from: json["publishedAt"].stringValue)
                    dateFormat.dateFormat = "dd-MM-yyyy"
                    
                    articles.append(Article(title: json["title"].stringValue,
                                            contents: articleTxt,
                                            imagesURL: imgs,
                                            author: json["author"].stringValue,
                                            date: dateFormat.string(from: date!), isSaved: false))
                }
                completion(articles)
            case let .failure(error):
                print(error)
                
            }
        }
    }

    func getContentDtf(type:String, page: Int = 0, site:String = "dtf", completion: @escaping(_ art: [Article])->()){
        var articles :[Article] = []
        AF.request("https://api.\(site).ru/v1.9/timeline/\(type)?count=8&offset=\(page*8)").responseJSON{
            responseJSON in
            switch responseJSON.result{
            case .success(let value):
                
                let jsonAll = JSON(value)["result"]
                for i  in 0..<jsonAll.count {
                    let json = jsonAll[i]
                    let _ = json["url"].stringValue
                    var imgs: [String] = []
                    do{
                        let doc: Document = try SwiftSoup.parse(json["entryContent"]["html"].stringValue)
                        let srcs: Elements = try doc.select("div[data-image-src]")
                        let srcsStringArray: [String] = srcs.array().map { try! $0.attr("data-image-src").description }
                        imgs = srcsStringArray
                        print("imgsss", imgs)
                    }
                    catch let error{
                        print("Error \(error)")
                    }
                    imgs.append(json["cover"]["url"].stringValue)
                    let text = json["entryContent"]["html"].stringValue.html2String
                    var content: [String] = text.components(separatedBy: " \n")
                    
                    if content.count > 4 {
                        content.removeSubrange(0..<4)
                        if content[0].contains("Listen") { content.removeFirst() }
                    }
                    var dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd-MM-yyyy"
                    var date = NSDate(timeIntervalSince1970: TimeInterval(TimeInterval(json["date"].doubleValue)))
                    let a = Article(title: json["title"].stringValue,
                                   contents: content.joined(separator: ""),
                                   imagesURL: imgs,
                                   author: json["author"]["name"].stringValue,
                                   date: dateFormatter.string(from: date as Date),
                                   isSaved: false)
                    articles.append(a) // output works
                    if articles.count == jsonAll.count {
                        completion(articles)
                    }
                }
            case let .failure(error):
                print(error)
            }
        }
    }

    // Здесь будут все GET запросы
    func GetNews(id :Int, page: Int, completion: @escaping ([Article])->()){
        AF.cancelAllRequests()
        var articles: [Article] = []
        switch id{
        case -1: //global
            getWorldNews(page: page, completion: { allArticles in
                articles = allArticles
                DispatchQueue.main.async {
                    completion(articles)
                }
            })
        case 0: //Meduza_news
                AF.request("https://meduza.io/api/v3/search?chrono=news&locale=ru&page=\(page)&per_page=24").responseJSON { responseJSON in
                    switch responseJSON.result {
                    case .success(let value):
                        let json = JSON(value)
                        
                        for (key, _) in json["documents"] {
                            self.getContent(url: key){ articleRes in
                                articles.append(articleRes)
                                
                                if articles.count == 24 {
                                    DispatchQueue.main.async {
                                        completion(articles)
                                    }
                                }
                            }
                        }
                    case let .failure(error):
                        print(error)
                    }
                }
        case 1: //Meduza_stories
            AF.request("https://meduza.io/api/v3/search?chrono=articles&locale=ru&page=\(page)&per_page=24").responseJSON
            {responseJSON in
            switch responseJSON.result {
            case .success(let value):
                let json = JSON(value)
                for (key, _) in json["documents"] {
                    self.getContent(url: key){ articleRes in
                        articles.append(articleRes)
                        
                        if articles.count == 24 {
                            DispatchQueue.main.async {
                                completion(articles)
                            }
                        }
                    }
                }
            case let .failure(error):
                print(error)
            }
        }
        case 5://DTF_games
            getContentDtf(type: "games/recent", page: page) { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 6: //DTF_gameindustry
            getContentDtf(type: "gameindustry/recent", page: page) { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 7: //DTF_gamedev
            getContentDtf(type: "gamedev/recent", page: page) { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 8: //DTF_cinema
            getContentDtf(type: "cinema/recent", page: page) { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 9: //DTF_all
            getContentDtf(type: "default/recent", page: page) { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 10: //Tjournal_news
            getContentDtf(type: "news/recent", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 11: //Tjournal_stories
            getContentDtf(type: "stories/recent", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 12: //Tjournal_tech
            getContentDtf(type: "tech/recent", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 13: //Tjournal_dev
            getContentDtf(type: "dev/recent", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 14: //Tjournal_all
            getContentDtf(type: "default/recent", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 15: //Vc_all
            getContentDtf(type: "default/recent", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 16: //Vc_design
            getContentDtf(type: "design/recent", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 17: //Vc_tech
            getContentDtf(type: "tech/recent", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 18: //Vc_dev
            getContentDtf(type: "dev/recent", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 19: //Vc_finance
            getContentDtf(type: "finance", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 20: //Vc_media
            getContentDtf(type: "media", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 21: //Vc_education
            getContentDtf(type: "education", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 22: //Vc_yandex.zen
            getContentDtf(type: "yandex.zen", page: page, site: "vc") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 23: //Tjournal_yandex.zen
            getContentDtf(type: "yandex.zen", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 24: //Tjournal_games
            getContentDtf(type: "games", page: page, site: "tjournal") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 25: //DTF_news
            getContentDtf(type: "news", page: page, site: "dtf") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        case 26: //DTF_design
            getContentDtf(type: "design", page: page, site: "dtf") { article in
                articles = article
                DispatchQueue.main.async {
                    completion(articles)
                }
            }
        default:
            print("Error")
        }
    }
        
}

extension Data {
    var html2AttributedString: NSAttributedString? {
        do {
            return try NSAttributedString(data: self, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch {
            print("error:", error)
            return  nil
        }
    }
    var html2String: String { html2AttributedString?.string ?? "" }
}

extension StringProtocol {
    var html2AttributedString: NSAttributedString? {
        Data(utf8).html2AttributedString
    }
    var html2String: String {
        html2AttributedString?.string ?? ""
    }
}

//extension String {
//    func condenseWhitespace() -> String {
//        return self.components(separatedBy: .whitespacesAndNewlines)
//            .filter { !$0.isEmpty }
//            .joined(separator: " ")
//    }
//
//}
