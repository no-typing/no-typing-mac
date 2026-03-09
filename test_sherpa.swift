import Foundation

// Find sherpa-onnx
let fm = FileManager.default
let buildPath = "/Users/user/Documents/Freelancers/Giddy/Dial8/dial8-open-source/build/Build/Products/Debug/no typing.app/Contents/Resources/sherpa-onnx-offline"
var sherpaURL: URL?
if fm.fileExists(atPath: buildPath) {
    sherpaURL = URL(fileURLWithPath: buildPath)
} else {
    // try to find it
    let dir = "/Users/user/Documents/Freelancers/Giddy/Dial8/dial8-open-source"
    let enumerator = fm.enumerator(atPath: dir)
    while let file = enumerator?.nextObject() as? String {
        if file.hasSuffix("sherpa-onnx-offline") {
            sherpaURL = URL(fileURLWithPath: dir + "/" + file)
            break
        }
    }
}

guard let sherpa = sherpaURL else {
    print("Could not find sherpa-onnx")
    exit(1)
}

print("Found sherpa at \(sherpa.path)")

let modelDir = "/Users/user/Library/Application Support/Whisper/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"

let process = Process()
process.executableURL = sherpa
process.arguments = [
    "--encoder=\(modelDir)/encoder.int8.onnx",
    "--decoder=\(modelDir)/decoder.int8.onnx",
    "--joiner=\(modelDir)/joiner.int8.onnx",
    "--tokens=\(modelDir)/tokens.txt",
    "--num-threads=4",
    "--feat-dim=128",
    "--sample-rate=16000",
    "--decoding-method=greedy_search",
    "/tmp/parakeet_test_out.wav"
]

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe

do {
    try process.run()
    process.waitUntilExit()
    
    let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""
    
    print("Status: \(process.terminationStatus)")
    print("Output:\n\(output)")
} catch {
    print("Error: \(error)")
}

