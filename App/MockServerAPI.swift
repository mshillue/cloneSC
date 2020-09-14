import Foundation


class MockURLProtocol: URLProtocol {
    
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == "mock"
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        var data: Data
        var response: URLResponse
        
        let requestURL = self.request.url!
        if requestURL.pathExtension == "jpg" {
            let fileURL = Bundle.main.url(forResource: requestURL.lastPathComponent, withExtension: "", subdirectory: "TestData")!
            let fileData = try? Data(contentsOf: fileURL)
            if fileData != nil {
                data = fileData!
                response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: "1.1", headerFields: nil)!
            } else {
                data = Data()
                response = HTTPURLResponse(url: requestURL, statusCode: 404, httpVersion: "1.1", headerFields: nil)!
            }
        } else {
            var json: Any
            switch requestURL.path {
            case "/posts" where request.httpMethod == "GET":
                json = getPosts()
            default:
                if let objectIDs = matchRoute(pattern: "/users/:user_id/posts", path: requestURL.path) {
                    json = getPostsOfUser(userIdentifier: objectIDs["user_id"]!)
                } else {
                    json = []
                }
            }
            data = try! JSONSerialization.data(withJSONObject: json, options: [])
            response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: "1.1", headerFields: nil)!
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    
    override func stopLoading() {
    }
    
    // MARK: -
    
    private func matchRoute(pattern: String, path: String) -> [String: Int]? {
        // Parse routes in format "/users/:user_id/posts/:post_id"
        // and construct a regular expression like "/users/([0-9]+)/posts/([0-9]+)",
        // storing identifier placeholders in an array like ["user_id", "post_id"].
        guard pattern.starts(with: "/") else {
            fatalError("The pattern must start with '/'")
        }
        
        var regexPattern = "^"
        var placeholders = [String]()
        for component in pattern.components(separatedBy: "/") {
            if component == "" {
                // An empty component comes before the leading '/'
                continue
            }
            regexPattern.append("/")
            if component.starts(with: ":") {
                regexPattern.append("([0-9]+)")
                let placeholder = String(component[component.index(component.startIndex, offsetBy: 1)...])
                placeholders.append(placeholder)
            } else {
                regexPattern.append(contentsOf: component)
            }
        }
        regexPattern.append("$")
        
        let regex = try! NSRegularExpression(pattern: regexPattern)
        let result = regex.firstMatch(in: path, options: [], range: NSRange(location: 0, length: path.count))
        // The range at index 0 corresponds to the whole regex, the rest are capture groups
        if result!.numberOfRanges > 1 {
            var identifierTable = [String: Int]()
            for rangeIndex in 1..<result!.numberOfRanges {
                identifierTable[placeholders[rangeIndex - 1]] = Int((path as NSString).substring(with: result!.range(at: rangeIndex)))
            }
            return identifierTable
        }
        return nil
    }
    
    private func getPosts() -> Any {
        var result = [[String: Any]]()
        for (postID, userID) in userIDByPostID {
            var user = users[userID]!
            user["id"] = userID
            var post = posts[postID]!
            post["user"] = user
            post["id"] = postID
            result.append(post)
        }
        result.sort { (a, b) -> Bool in
            (a["date"] as! String) > (b["date"] as! String)
        }
        return result
    }
    
    private func getPostsOfUser(userIdentifier: Int) -> Any {
        var result = [[String: Any]]()
        for (postID, userID) in userIDByPostID where userID == userIdentifier {
            var user = users[userID]!
            user["id"] = userID
            var post = posts[postID]!
            post["user"] = user
            post["id"] = postID
            result.append(post)
        }
        result.sort { (a, b) -> Bool in
            (a["date"] as! String) > (b["date"] as! String)
        }
        return result
    }
    
    // MARK: -
    
    private let userIDByPostID = [1: 1, 2: 2, 3: 2, 4: 3, 5: 4, 6: 2, 7: 5, 8: 6, 9: 4, 10: 7, 11: 8, 12: 9, 13: 2, 14: 10, 15: 3, 16: 2, 17: 5, 18: 3, 19: 2, 20: 7]
    private let posts = [
        1: ["date": "2020-09-01T12:30:07Z",
            "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "images": [["url": "mock://sc.com/pic.1.jpg"]]],
        2: ["date": "2020-08-25T22:57:07Z",
            "text": "Megapolis, here I come! 🤲😻❤️",
            "images": [["url": "mock://sc.com/pic.2.jpg"]]],
        3: ["date": "2020-08-20T20:20:07Z",
            "text": "Such a beautiful night on a beach with friends, wine and dogs!",
            "images": [["url": "mock://sc.com/pic.3.jpg"]]],
        4: ["date": "2020-08-15T12:40:07Z",
            "text": "I made a cool wallpaper. Gonna sell it for a billion bucks at Sotheby's. OK, just donate something please.",
            "images": [["url": "mock://sc.com/pic.4.jpg"]]],
        5: ["date": "2020-08-10T15:50:07Z",
            "text": "I went skiing on a hot summer night hoping to see a Big Foot or a Small Paw. Shot this instead.",
            "images": [["url": "mock://sc.com/pic.5.jpg"]]],
        6: ["date": "2020-08-05T23:54:07Z",
            "text": "Happy New Year everyone!",
            "images": [["url": "mock://sc.com/pic.6.jpg"]]],
        7: ["date": "2020-07-31T12:46:07Z",
            "text": "I bought myself an island on Craigslist after getting rich on r/WallstreetBets.",
            "images": [["url": "mock://sc.com/pic.7.jpg"]]],
        8: ["date": "2020-07-26T13:12:07Z",
            "text": "This was the best picnic this week, BBQ FTW!",
            "images": [["url": "mock://sc.com/pic.8.jpg"]]],
        9: ["date": "2020-07-21T09:24:07Z",
            "text": "Walking my dog in the park in the morning",
            "images": [["url": "mock://sc.com/pic.9.jpg"]]],
        10: ["date": "2020-07-11T13:31:07Z",
             "text": "I was hunting with my grandfather for my 19th birthday about a year ago and we both watched a deer slam its head into a rock shatter its head. We saved a bunch of them bullets.",
             "images": [["url": "mock://sc.com/pic.10.jpg"]]],
        11: ["date": "2020-07-06T15:10:07Z",
             "text": "Comrades, I got my PhD in Photoshop!",
             "images": [["url": "mock://sc.com/pic.11.jpg"]]],
        12: ["date": "2020-07-01T14:40:07Z",
             "text": "I love driving my van in the middle of nowhere until I run out of gas. Then I go looking for another van. Movin' is livin' ✊🏿",
             "images": [["url": "mock://sc.com/pic.12.jpg"]]],
        13: ["date": "2020-06-25T02:16:07Z",
             "text": "I stitched together 65535 images of the Milky Way to create the most detailed photograph of our galaxy I have ever created. Enjoy!",
             "images": [["url": "mock://sc.com/pic.13.jpg"]]],
        14: ["date": "2020-06-20T12:21:07Z",
             "text": "Help! I lost my way, somebody please extract geo tags from this photo and tell me where I am! PLEASE!!!",
             "images": [["url": "mock://sc.com/pic.14.jpg"]]],
        15: ["date": "2020-06-15T11:06:07Z",
             "text": "Alps are great! This is Alps, right?",
             "images": [["url": "mock://sc.com/pic.15.jpg"]]],
        16: ["date": "2020-06-10T14:37:07Z",
             "text": "Chilling in Bratislava…",
             "images": [["url": "mock://sc.com/pic.16.jpg"]]],
        17: ["date": "2020-06-09T16:49:07Z",
             "text": "This is my new office. The plaza is mine too. Actually, I got the whole city at a discount, that's why it looks a bit empty.",
             "images": [["url": "mock://sc.com/pic.17.jpg"]]],
        18: ["date": "2020-06-06T14:51:07Z",
             "text": "The best view of the Eye Fall tower you can get",
             "images": [["url": "mock://sc.com/pic.18.jpg"]]],
        19: ["date": "2020-06-02T10:20:07Z",
             "text": "What a view outside my hotel room! I ❤️ it!",
             "images": [["url": "mock://sc.com/pic.19.jpg"]]],
        20: ["date": "2020-06-01T16:26:07Z",
             "text": "Košice is incredibly beautiful in June!",
             "images": [["url": "mock://sc.com/pic.20.jpg"]]]
    ]
    private let users = [
        1: ["name": "Albert Johnson", "avatar": ["url": "mock://sc.com/avatar.1.jpg"]],
        2: ["name": "Beth Lee", "avatar": ["url": "mock://sc.com/avatar.2.jpg"]],
        3: ["name": "David Charter", "avatar": ["url": "mock://sc.com/avatar.3.jpg"]],
        4: ["name": "Mary Goldsmith", "avatar": ["url": "mock://sc.com/avatar.4.jpg"]],
        5: ["name": "Simon Rochester", "avatar": ["url": "mock://sc.com/avatar.5.jpg"]],
        6: ["name": "Chau Nguyen", "avatar": ["url": "mock://sc.com/avatar.6.jpg"]],
        7: ["name": "Peter Waters", "avatar": ["url": "mock://sc.com/avatar.7.jpg"]],
        8: ["name": "Tiffany MacDowell", "avatar": ["url": "mock://sc.com/avatar.8.jpg"]],
        9: ["name": "Robert Stoughton", "avatar": ["url": "mock://sc.com/avatar.9.jpg"]],
        10: ["name": "Kate Benedict", "avatar": ["url": "mock://sc.com/avatar.10.jpg"]]
    ]
}