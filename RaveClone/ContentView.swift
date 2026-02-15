//
//  ContentView.swift
//  RaveClone
//
//  Created by Francesca Finetti on 15/02/26.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject var wsManager = WebSocketManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Netflix Party")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
                if wsManager.receivedEvent != nil {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.black)
            
            // WebView
            NetflixWebView(wsManager: wsManager)
        }
        .onAppear {
            wsManager.connect()
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

// MARK: - WKWebView Wrapper
struct NetflixWebView: UIViewRepresentable {
    @ObservedObject var wsManager: WebSocketManager
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // JAVASCRIPT: Inietta il codice per spiare i click su Play/Pausa
        let source = """
        function notifySwift(action, time) {
            window.webkit.messageHandlers.partyBridge.postMessage({
                "action": action,
                "timestamp": time
            });
        }

        var checkVideo = setInterval(function() {
            var video = document.querySelector('video');
            if (video) {
                console.log("✅ Video Trovato!");
                clearInterval(checkVideo);
                
                window.isRemote = false;

                video.onplay = function() {
                    if(!window.isRemote) notifySwift("play", video.currentTime);
                    window.isRemote = false;
                };
                
                video.onpause = function() {
                    if(!window.isRemote) notifySwift("pause", video.currentTime);
                    window.isRemote = false;
                };
                
                video.onseeked = function() {
                    if(!window.isRemote) notifySwift("seek", video.currentTime);
                    window.isRemote = false;
                };
            }
        }, 1000);
        """
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "partyBridge")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // User Agent Desktop per iPad
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
        
        if let url = URL(string: "https://www.netflix.com/login") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Questa funzione scatta quando arriva un messaggio dal Socket
        guard let event = wsManager.receivedEvent else { return }
        
        // Evita di eseguire lo stesso comando due volte
        if context.coordinator.lastEventId == event.timestamp { return }
        context.coordinator.lastEventId = event.timestamp
        
        let jsCommand: String
        
        // Logica per non far scattare il listener inverso
        switch event.action {
        case .play:
            jsCommand = """
            var v = document.querySelector('video');
            window.isRemote = true;
            if(Math.abs(v.currentTime - \(event.timestamp)) > 1) v.currentTime = \(event.timestamp);
            v.play();
            """
        case .pause:
            jsCommand = """
            var v = document.querySelector('video');
            window.isRemote = true;
            v.pause();
            v.currentTime = \(event.timestamp);
            """
        case .seek:
            jsCommand = """
            var v = document.querySelector('video');
            window.isRemote = true;
            v.currentTime = \(event.timestamp);
            """
        }
        
        webView.evaluateJavaScript(jsCommand) { _, error in
            if let error = error { print("⚠️ Errore JS remoto: \(error)") }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: NetflixWebView
        var lastEventId: Double = -1.0
        
        init(parent: NetflixWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let actionString = dict["action"] as? String,
                  let time = dict["timestamp"] as? Double,
                  let action = ActionType(rawValue: actionString) else { return }
            
            print("👉 Azione locale rilevata: \(action)")
            
            let event = VideoEvent(action: action, timestamp: time)
            parent.wsManager.send(event: event)
        }
    }
}
