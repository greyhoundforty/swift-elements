import SwiftUI

struct LoginView: View {
    @Environment(MatrixClient.self) private var matrixClient
    @State private var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("EmdashChat")
                    .font(.largeTitle.bold())

                Text("Sign in to your Matrix account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Fields
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Field(label: "Homeserver") {
                    TextField("https://matrix.org", text: $viewModel.homeserver)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }

                Field(label: "Username") {
                    TextField("@you:matrix.org", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }

                Field(label: "Password") {
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Sign In button
            Button {
                Task { await viewModel.login(using: matrixClient) }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: 380)
    }
}

// MARK: - Helpers

private struct Field<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}
