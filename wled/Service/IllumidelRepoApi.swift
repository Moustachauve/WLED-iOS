import Foundation

class IllumidelRepoApi : GithubApi {
    init() {
        super.init(repoOwner: "Illumidel", repoName: "App-Releases")
    }
    
    
    override func getRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let key = Bundle.main.infoDictionary?["GITHUB_ILLUMIDEL_KEY"] as? String {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
