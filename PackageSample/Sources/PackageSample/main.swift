import Foundation
import OctoKit

let token = ProcessInfo().environment["GITHUB_TOKEN"]
let api = Octokit(TokenConfiguration(token))

let owner = "417-72KI"
let repoName = "SSGH"

let me = try await api.me()
print(me.name ?? "")
print(me.company ?? "")

do {
    let prNumber = 53
    let reviews = try await api.reviews(owner: owner, repository: repoName, pullRequestNumber: prNumber)
    if let review = reviews.first(where: { $0.user.id == me.id && $0.state == .pending }) {
        print(review)
        try await api.deletePendingReview(owner: owner, repository: repoName, pullRequestNumber: prNumber, reviewId: review.id)
        // try await api.submitReview(owner: owner, repository: repoName, pullRequestNumber: prNumber, reviewId: review.id, event: .approve)
    } else {
        let review = try await api.postReview(owner: owner, repository: repoName, pullRequestNumber: prNumber, event: .approve)
        print(review)
        let submitted = try await api.submitReview(owner: owner, repository: repoName, pullRequestNumber: prNumber, reviewId: review.id, event: .approve)
        print(submitted)
    }
} catch {
    print(error)
}
