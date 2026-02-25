import Foundation
import LinkPresentation

let url = URL(string: "https://www.instagram.com/p/DBh8fB-tmsS")!
let provider = LPMetadataProvider()
let dispatchGroup = DispatchGroup()
dispatchGroup.enter()

provider.startFetchingMetadata(for: url) { metadata, error in
    if let error = error {
        print("Error: \(error)")
    } else if let metadata = metadata {
        print("Title: \(metadata.title ?? "No title")")
    }
    dispatchGroup.leave()
}

_ = dispatchGroup.wait(timeout: .now() + 10)
print("Finished")
