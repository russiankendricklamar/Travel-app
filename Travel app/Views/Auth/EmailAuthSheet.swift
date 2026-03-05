import SwiftUI

struct EmailAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSuccess: () -> Void

    private let authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Mode toggle
                    Picker("", selection: $isSignUp) {
                        Text("Вход").tag(false)
                        Text("Регистрация").tag(true)
                    }
                    .pickerStyle(.segmented)

                    // Fields
                    VStack(spacing: 14) {
                        if isSignUp {
                            GlassFormField(label: "Имя", color: AppTheme.sakuraPink) {
                                TextField("Ваше имя", text: $name)
                                    .textContentType(.name)
                                    .autocorrectionDisabled()
                            }
                        }

                        GlassFormField(label: "Email", color: AppTheme.sakuraPink) {
                            TextField("email@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        }

                        GlassFormField(label: "Пароль", color: AppTheme.sakuraPink) {
                            SecureField("Минимум 6 символов", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                        }

                        if isSignUp {
                            GlassFormField(label: "Подтвердите пароль", color: AppTheme.sakuraPink) {
                                SecureField("Повторите пароль", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.toriiRed)
                            .multilineTextAlignment(.center)
                    }

                    // Submit
                    Button {
                        submit()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isSignUp ? "Создать аккаунт" : "Войти")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.sakuraPink)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }
                    .disabled(!isFormValid || isLoading)
                    .opacity(isFormValid ? 1 : 0.5)
                }
                .padding(AppTheme.spacingL)
            }
            .sakuraGradientBackground()
            .navigationTitle(isSignUp ? "Регистрация" : "Вход по Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSignUp)
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword && !name.isEmpty
        }
        return emailValid && passwordValid
    }

    private func submit() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                if isSignUp {
                    try await authManager.signUpWithEmail(
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password,
                        name: name.trimmingCharacters(in: .whitespaces)
                    )
                } else {
                    try await authManager.signInWithEmail(
                        email: email.trimmingCharacters(in: .whitespaces),
                        password: password
                    )
                }
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
