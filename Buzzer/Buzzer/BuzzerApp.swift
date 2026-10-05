//
//  BuzzerApp.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

private let magicLinkVerifyURL = "https://busmate-admin.vercel.app/api/admin-signin-link/verify"

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Set delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        return true
    }

    // Pass APNs token to FCM
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // Called when FCM refreshes the token — save it to Firestore
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NotificationCenter.default.post(
            name: .fcmTokenRefreshed,
            object: nil,
            userInfo: ["token": token]
        )
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension Notification.Name {
    static let fcmTokenRefreshed = Notification.Name("fcmTokenRefreshed")
}

@main
struct BuzzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authManager: AuthManager? = nil
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let authManager {
                    if showSplash {
                        SplashScreenView {
                            showSplash = false
                        }
                    } else {
                        RootView()
                            .environment(authManager)
                    }
                }
            }
            .task {
                if authManager == nil {
                    authManager = AuthManager()
                }
            }
            .onOpenURL { url in
                // Intercept Universal Links from the admin magic-link email.
                // Expected URL: https://busmate-admin.vercel.app/auth-callback?token=...&email=...
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    components.path == "/auth-callback",
                    let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                    let email = components.queryItems?.first(where: { $0.name == "email" })?.value,
                    let mgr = authManager
                else { return }

                Task {
                    await mgr.signInWithMagicLink(token: token, email: email)
                }
            }
        }
    }
}
