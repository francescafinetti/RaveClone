const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

console.log("🎬 Server Rave-Clone con Stanze e Chat avviato");

wss.on('connection', function connection(ws) {
  // Variabile per ricordare in che stanza è questo utente
  ws.room = "";

  ws.on('message', function incoming(message) {
    try {
      const data = JSON.parse(message);

      // 1. SE È UN MESSAGGIO DI INGRESSO (JOIN)
      if (data.type === 'join') {
        ws.room = data.room;
        console.log(`Utente entrato nella stanza: ${ws.room}`);
      } 
      
      // 2. SE È VIDEO O CHAT -> INOLTRA SOLO ALLA STESSA STANZA
      else if (ws.room) {
        wss.clients.forEach(function each(client) {
          // Manda solo se è un altro utente E se è nella stessa stanza
          if (client !== ws && client.readyState === WebSocket.OPEN && client.room === ws.room) {
            client.send(message);
          }
        });
      }
    } catch (e) {
      console.error("Errore parsing messaggio", e);
    }
  });
});
