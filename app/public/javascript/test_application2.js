// loadした時
window.addEventListener('load', () => {
  let msgbox = document.getElementById('file');
  let form = document.getElementById('form');
  let sendFile = document.getElementById('send-file');
  let ws = new WebSocket('ws://' + window.location.host + '/websocket2');

  // 接続開始メソッド ()なので引数なし
  ws.onopen = () => console.log('connection opened');
  // 接続終了メソッド ()なので引数なし
  ws.onclose = () => console.log('connection closed');
  // サーバーからsendされた時に実行される関数 m=sendが引数
  ws.onmessage = m => {
    let objimg = document.createElement('img');
    // objimg.src = m.data;
    console.log('aaa'); 
    objimg.src = "./public/images/CHOYA_SINGLE.JPG";
    let objBody = document.getElementsByTagName("body").item(0);
    objBody.appendChild(objimg);
  }

  // テキストボックスをクリックされた時
  //sendMsg.addEventListener('click', () => sendMsg.value = '');
 
  //formでsubmitされたとき
  form.addEventListener('submit', e => {
    var file = sendFile.files[0];
    var reader = new FileReader();

    reader.onload = function() {
      var ar = new Uint8Array(reader.result);
      ws.send(file.name);
      ws.send(ar.buffer);
      //ws.close();
    }
    
    reader.readAsArrayBuffer(file);

    /*
    for(var i = 0; i < files.length; i ++){
      var f = files[i];

      var reader = new FileReader();
      reader.onload = function(){
        var binary = new Uint8Array(reader.result);
        ws.send(f.name)
        ws.send(binary.buffer);
        ws.close();
      };
      reader.readAsArrayBuffer(f);
    };
    */
    //ws.send(sendFile.data);
    // 送信後、テキストボックスをクリア
    //sendMsg.value = '';
    // デフォルトアクションを抑止する
    e.preventDefault();
  });
});


