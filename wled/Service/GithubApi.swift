import Foundation
import CoreData

class GithubApi {
    static var urlSession: URLSession?
    
    static func getUrlSession() -> URLSession {
        if (urlSession != nil) {
            return urlSession!
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 8
        sessionConfig.timeoutIntervalForResource = 18
        sessionConfig.waitsForConnectivity = false
        urlSession = URLSession(configuration: sessionConfig)
        return urlSession!
    }
    
    let githubBaseUrl = "https://api.github.com"
    let repoOwner: String
    let repoName: String
    
    init(repoOwner: String, repoName: String) {
        self.repoOwner = repoOwner
        self.repoName = repoName
    }
    
    private func getApiUrl(path: String) -> URL? {
        let urlString = "\(githubBaseUrl)/\(path)"
        print(urlString)
        return URL(string: urlString)
    }
    
    func getAllReleases() async -> [Release] {
        print("retrieving all releases")
        let url = getApiUrl(path: "repos/\(repoOwner)/\(repoName)/releases")
        guard let url else {
            print("Can't retrieve releases, url nil")
            return []
        }
        do {
            let (data, response) = try await GithubApi.getUrlSession().data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid httpResponse in update")
                return []
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Error with the response in update, unexpected status code: \(httpResponse)")
                return []
            }
            
            let releases = try JSONDecoder().decode([Release].self, from: data)
            return releases
        } catch {
            print("Error with fetching device: \(error)")
            return []
        }
    }
}
