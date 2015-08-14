  function onMessage(evt)
{
    if (evt.data.match(/gold/)){
        writeToScreen('<span style="color: blue;">RESPONSE: ' + evt.data+'</span>');
    }
  }

  function doSend(message)
  {
    websocket.send(message);
  }

function genPrefix(existingPrefix) {

}

function hack() {
    for (var i = 0; i < 65536; i++) {
        var firstByte = String.fromCharCode(i % 256);
        var secondByte = String.fromCharCode(Math.floor(i / 256));
        doSend(firstByte + secondByte);
    }
}
