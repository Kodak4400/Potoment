// loadした時
window.addEventListener('load', () => {
  let msgbox = document.getElementById('msg');
  let form = document.getElementById('form');
  let sendMsg = document.getElementById('send-msg');
  let ws = new WebSocket('ws://' + window.location.host + '/websocket');

  // 接続開始メソッド ()なので引数なし
  ws.onopen = () => console.log('connection opened');
  // 接続終了メソッド ()なので引数なし
  ws.onclose = () => console.log('connection closed');
  // サーバーからsendされた時に実行される関数 m=sendが引数
  ws.onmessage = m => {
    let li = document.createElement('li');
    li.textContent = m.data;
    msgbox.insertBefore(li, msgbox.firstChild);
  }

  // テキストボックスをクリックされた時
  sendMsg.addEventListener('click', () => sendMsg.value = '');
 
  //formでsubmitされたとき
  form.addEventListener('submit', e => {
    ws.send(sendMsg.value);
    // 送信後、テキストボックスをクリア
    sendMsg.value = '';
    // デフォルトアクションを抑止する
    e.preventDefault();
  });
});


