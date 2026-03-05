import Foundation
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var homeserver = "https://matrix.org"
    var username   = ""
    var password   = ""
    var isLoading  = false
    var errorMessage: String?

    func login(using client: MatrixClient) async {
        guard !username.isEmpty else {
            errorMessage = "Enter your username"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Enter your password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await client.login(
                homeserver: homeserver,
                username: username,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
