import UIKit
import WebKit
import Network

final class WebViewController: UIViewController {

    // MARK: - Views
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var offlineView: UIView?

    // MARK: - State
    private let monitor = NWPathMonitor()
    private var isConnected = true

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        setupWebView()
        setupProgressBar()
        startNetworkMonitor()
        loadApp()
        showAIDisclosureIfNeeded()
    }

    /// App Store Guideline 5.1.2(i) — обязательное раскрытие AI/третьих сторон
    /// перед началом обработки персональных данных. Показывается один раз.
    private func showAIDisclosureIfNeeded() {
        let key = "dn_ios_ai_disclosure_v1"
        if UserDefaults.standard.bool(forKey: key) { return }
        let isRu = (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ru")
        let title = isRu ? "AI и данные" : "AI & Your Data"
        let body = isRu
            ? "CashMind содержит AI‑советника на базе OpenAI GPT‑4o. Чтобы давать персональные ответы, AI получает доступ к вашим финансовым данным в приложении (счета, транзакции, бюджеты, цели, долги) и отправляет их в OpenAI API (США) при каждом сообщении.\n\nОтветы AI генерируются автоматически и могут быть неточными — не используйте их как замену консультации финансиста."
            : "CashMind includes an AI advisor powered by OpenAI GPT‑4o. To provide personal advice, the AI accesses your in‑app financial data (accounts, transactions, budgets, goals, debts) and sends it to the OpenAI API (USA) with each message you send.\n\nAI responses are generated automatically and may be inaccurate — do not use them as a substitute for professional financial advice."
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: isRu ? "Понятно" : "I Understand", style: .default) { _ in
            UserDefaults.standard.set(true, forKey: key)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.present(alert, animated: true)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - WebView Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()
        config.limitsNavigationsToAppBoundDomains = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Set platform cookie so PWA knows it's in the iOS wrapper
        setPlatformCookie()

        // Custom user agent with PWAShell marker
        let device = UIDevice.current.model
        let osVer = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        webView.customUserAgent = "Mozilla/5.0 (\(device); CPU \(device) OS \(osVer) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(UIDevice.current.systemVersion) Mobile/15E148 Safari/604.1 PWAShell"

        if pullToRefresh {
            let refresh = UIRefreshControl()
            refresh.tintColor = .white
            refresh.addTarget(self, action: #selector(pullRefreshAction), for: .valueChanged)
            webView.scrollView.refreshControl = refresh
        }

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress),
                            options: .new, context: nil)
    }

    private func setPlatformCookie() {
        guard let host = rootUrl.host else { return }
        let cookie = HTTPCookie(properties: [
            .domain: host,
            .path: "/",
            .name: platformCookie.name,
            .value: platformCookie.value,
            .secure: "FALSE",
            .expires: Date(timeIntervalSinceNow: 31556926)
        ])
        if let cookie = cookie {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }

    private func setupProgressBar() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1)
        progressView.trackTintColor = .clear
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isConnected ?? true)
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied && wasOffline {
                    self?.hideOffline()
                    self?.loadApp()
                }
            }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    // MARK: - Loading

    private func loadApp() {
        webView.load(URLRequest(url: rootUrl))
    }

    @objc private func pullRefreshAction() {
        if isConnected {
            webView.reload()
        } else {
            showOffline()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.webView.scrollView.refreshControl?.endRefreshing()
        }
    }

    // MARK: - Offline Screen

    private func showOffline() {
        guard offlineView == nil else { return }

        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .appBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UILabel()
        icon.text = "📡"
        icon.font = .systemFont(ofSize: 48)

        let title = UILabel()
        title.text = L10n.offlineTitle
        title.textColor = .white
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitle = UILabel()
        subtitle.text = L10n.offlineSubtitle
        subtitle.textColor = .gray
        subtitle.font = .systemFont(ofSize: 15)

        let btn = UIButton(type: .system)
        btn.setTitle(L10n.offlineRetry, for: .normal)
        btn.tintColor = UIColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        btn.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        [icon, title, subtitle, btn].forEach { stack.addArrangedSubview($0) }
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])

        view.addSubview(overlay)
        offlineView = overlay
    }

    private func hideOffline() {
        offlineView?.removeFromSuperview()
        offlineView = nil
    }

    @objc private func retryTapped() {
        if isConnected {
            hideOffline()
            loadApp()
        }
    }

    // MARK: - KVO Progress

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            let progress = Float(webView.estimatedProgress)
            progressView.setProgress(progress, animated: true)
            progressView.isHidden = progress >= 1.0
        }
    }

    deinit {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        monitor.cancel()
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if allowedOrigins.contains(url.host ?? "") || url.scheme == "about" || url.scheme == "blob" {
            decisionHandler(.allow)
        } else if url.scheme == "mailto" || url.scheme == "tel" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if !isConnected { showOffline() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if !isConnected { showOffline() }
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}

// MARK: - Localization

enum L10n {
    private static var isRu: Bool {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ru")
    }
    static var offlineTitle: String {
        isRu ? "Нет подключения" : "No connection"
    }
    static var offlineSubtitle: String {
        isRu ? "Проверьте интернет-соединение" : "Check your internet connection"
    }
    static var offlineRetry: String {
        isRu ? "Повторить" : "Retry"
    }
}

// MARK: - Colors

extension UIColor {
    static let appBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 23/255, green: 23/255, blue: 23/255, alpha: 1)
            : UIColor.white
    }
}
