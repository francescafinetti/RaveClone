const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

console.log("🎬 Server Rave-Clone avviato sulla porta 8080");

wss.on('connection', function connection(ws) {
  console.log('Nuovo utente connesso!');
  ws.on('message', function incoming(message) {
    console.log('Ricevuto: %s', message);
    // Invia il messaggio a tutti gli altri tranne chi l'ha mandato
    wss.clients.forEach(function each(client) {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  });
});