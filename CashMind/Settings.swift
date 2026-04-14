import WebKit

// ═══ App Configuration ═══

// Main URL
let rootUrl = URL(string: "https://rynpro.ru/fin/")!

// Allowed origins (must match WKAppBoundDomains in Info.plist)
let allowedOrigins: [String] = ["rynpro.ru"]

// Auth origins (open in modal with toolbar)
let authOrigins: [String] = []

// Platform cookie — lets PWA detect iOS wrapper
struct Cookie {
    var name: String
    var value: String
}
let platformCookie = Cookie(name: "app-platform", value: "iOS App Store")

// UI options
let displayMode = "standalone"  // standalone / fullscreen
let pullToRefresh = true
let adaptiveUIStyle = true      // iOS 15+ dark/light from web theme
let overrideStatusBar = false
let statusBarTheme = "dark"
