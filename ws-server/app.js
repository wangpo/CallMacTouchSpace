const http = require('http')
const WebSocketServer = require('websocket').server

const httpServer = http.createServer((request, response) => {
    console.log('[' + new Date + '] Received request for ' + request.url)
    response.writeHead(404)
    response.end()
})

const wsServer = new WebSocketServer({
    httpServer,
    autoAcceptConnections: true
})

wsServer.on('connect', connection => {
    //每隔10秒发送‘space’信令
    setInterval(function() {
   connection.sendUTF('space')
}, 0.1 * 60 * 1000);
    
   
})

httpServer.listen(8080, () => {
    console.log('[' + new Date() + '] Serveris listening on port 8080')
})
