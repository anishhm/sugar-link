import SwiftUI

struct WatchLoginView: View {
    @Environment(GlucoseViewModel.self) private var model
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("LibreLinkUp")
                    .font(.system(.headline, design: .rounded))

                TextField("Email", text: $email)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.password)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(GlucoseRange.low.color)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await logIn() }
                } label: {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Text("Log In")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isLoggingIn)

                Text("Enter the follower account invited from your FreeStyle Libre app.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }

    private func logIn() async {
        isLoggingIn = true
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let error = await model.logIn(email: trimmedEmail, password: password)
        isLoggingIn = false
        if let error {
            errorMessage = error
        }
    }
}
