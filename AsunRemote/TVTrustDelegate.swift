import Foundation
import Security

// LG TVs use self-signed certificates. Trust on first pairing is limited to the
// exact user-selected private IP and port. The certificate is saved only after
// the TV approves pairing. Subsequent connections require an exact match.
final class TVTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let endpoint: TVEndpoint
    private let expected: Data?
    private let initialPairing: Bool
    private let lock = NSLock()
    private var observed: Data?
    private var failure: String?

    init(endpoint: TVEndpoint, credential: PairingCredential?) {
        self.endpoint = endpoint
        expected = credential?.certificate
        initialPairing = credential == nil
    }

    var certificate: Data? { lock.lock(); defer { lock.unlock() }; return observed }
    var issue: String? { lock.lock(); defer { lock.unlock() }; return failure }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard endpoint.mode == .secure,
              challenge.protectionSpace.host == endpoint.host,
              challenge.protectionSpace.port == endpoint.mode.port,
              challenge.previousFailureCount == 0,
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let certificate = SecCertificateCopyData(leaf) as Data
        lock.lock()
        let alreadyObserved = observed
        let valid = (expected.map { $0 == certificate } ?? initialPairing)
            && (alreadyObserved == nil || alreadyObserved == certificate)
        if valid { observed = certificate }
        else {
            failure = "The TV’s identity has changed. Check that the IP address still belongs to your LG TV. If the TV was reset or updated, forget its pairing and pair again."
        }
        lock.unlock()
        completionHandler(valid ? .useCredential : .cancelAuthenticationChallenge,
                          valid ? URLCredential(trust: trust) : nil)
    }
}
