//
//  Untitled.swift
//  RaveClone
//
//  Created by Francesca Finetti on 15/02/26.
//

import Foundation
import Combine

class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    @Published var receivedEvent: VideoEvent?
    
    // 👇 ECCO IL TUO IP AGGIORNATO
    private let urlString = "ws://192.168.1.16:8080"
    
    func connect() {
        guard let url = URL(string: urlString) else {
            print("❌ Indirizzo URL non valido")
            return
        }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        print("🔗 Tentativo di connessione a \(urlString)...")
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    func send(event: VideoEvent) {
        do {
            let data = try JSONEncoder().encode(event)
            if let string = String(data: data, encoding: .utf8) {
                let message = URLSessionWebSocketTask.Message.string(string)
                webSocketTask?.send(message) { error in
                    if let error = error { print("❌ Errore invio: \(error)") }
                }
            }
        } catch {
            print("❌ Errore encoding JSON")
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("❌ Errore ricezione socket: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleReceivedText(text)
                case .data(let data):
                    self?.handleReceivedText(String(data: data, encoding: .utf8) ?? "")
                @unknown default:
                    break
                }
                self?.receiveMessage() // Continua ad ascoltare il prossimo messaggio
            }
        }
    }
    
    private func handleReceivedText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if let event = try? JSONDecoder().decode(VideoEvent.self, from: data) {
            DispatchQueue.main.async {
                self.receivedEvent = event
                print("📩 Ricevuto comando remoto: \(event.action) al sec: \(event.timestamp)")
            }
        }
    }
}
