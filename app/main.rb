require 'bundler/setup'
#Bundler.require
require 'sinatra'
require 'sinatra/base'
require 'sinatra/reloader' if development?
require 'sinatra-websocket'
require 'sinatra/config_file'

config_file 'config/cloudinary.yml'

require 'json'
require 'carrierwave'
require 'cloudinary'

require 'date'

require 'line/bot'

# デバック用
get '/test_page' do
  @t_cloud_img = Cloudinary::Utils.cloudinary_url("20180308010833.jpg")
  @t_cloud_img = Cloudinary::Utils.cloudinary_url("20180308010857.jpg")
  erb :test_page
end

# Potomentのトップページ
get '/potoment_page' do
  erb :potoment_page 
end

# clientの環境設定
def client
  # @clientがnull or falseの場合、代入する
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

# LINEからのリクエスト受信
post '/callback' do
  # リクエストメソッドのポストデータを取得 
  body = request.body.read

  # 署名の確認
  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  # イベント情報を取得
  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      # メッセージタイプがテキストの場合
      when Line::Bot::Event::MessageType::Text
        message = {
          type: 'text',
          text: '画像しか送信できません。'
        }
        # メッセージをWebSocketで返信
        client.reply_message(event['replyToken'], message)
        # websocket_message
      # メッセージタイプが画像の場合
      when Line::Bot::Event::MessageType::Image
        # 画像ファイル名を指定
        pid = DateTime.now.strftime('%Y%m%d%H%M%S')
        path = "./tmp/#{pid}.jpg"
        response = client.get_message_content(event.message['id'])
        # 画像ファイルをtmpディレクトリに書き込み
        file = File.open(path, "wb")
        file.write(response.body)
        # Cloudinaryへアップロード
        #Cloudinary::Uploader.upload(path, :public_id => pid, :width => 450, :height => 150, :crop => :limit)
        Cloudinary::Uploader.upload(path, :public_id => pid, :width => 0.2, :height => 0.2, :crop => :scale)
        # デバック用
        puts system('ls -ltr ./tmp') 
        # tmpディレクトリに配置した画像ファイルを削除
        File.unlink(file)
        message = {
           type: 'text',
           text: '画像をアップロードしました。'
        }
        # 画像ファイルをWebSocketで返信
        client.reply_message(event['replyToken'], message)
        websocket_image(pid)
      # メッセージタイプが画像、テキスト以外  
      when Line::Bot::Event::MessageType::Video
        message = {
          type: 'text',
          text: '画像しか送信できません。'
        }
        # メッセージをWebSocketで返信
        client.reply_message(event['replyToken'], message)
        # 後日削除
        #response = client.get_message_content(event.message['id'])
        #tf = Tempfile.open("content")
        #tf.write(response.body)
      end
    end
  }

 "OK"
end

# Cloudinaryから画像取得し、WebSocketを使用して表示する
# サーバは'thin'を使う
set :server, 'thin'
# WebSocketで情報が更新された時にレスポンス送り先を入れる
set :sockets, []

# WebSocket用
get '/websocket' do
  # WebSocket通信かどうかを判定
  if request.websocket?
    # WebSocket通信の場合、wsにセッティング情報書き込み
    # wsは、サーバーの情報やクライアントの情報が詰まった変数
    request.websocket do |ws|
      # onopen:WebSocket通信のための接続がされようとしている時の処理をまとめる
      ws.onopen do
        # set :socketsを呼び出し
        settings.sockets << ws
      end
      # onmessage:WebSocket通信によってメッセージが来た時の処理をまとめる
      ws.onmessage do |msg|
         # WebSocket通信でsndする
         # WebSocket通信で、クライアントに向かって情報をおくる
         # sendメソッドでは、１クライアントにしか送れない。
         # この処理はタイムアウト防止のため、受信後は何もしない 
      end
      # onclose:WebSocket通信が切断された時の処理をまとめる
      ws.onclose do
        # wsを削除
        settings.sockets.delete(ws)
      end
      # デバック用：LINEからのメッセージを受信後の処理
      # def websocket_message
      #  settings.sockets.each do |s|
      #    s.send("aaa")
      #  end
      #end
      # LINEからの画像ファイルをWebSocketを通して返信
      def websocket_image(img_name)
        settings.sockets.each do |s|
          #@cloud_img = Cloudinary::Utils.cloudinary_url("#{img_name}.jpg", :width=>150, :height=>100, :crop=>"scale") 
          @cloud_img = Cloudinary::Utils.cloudinary_url("#{img_name}.jpg", {secure: true, angle: "exif"}) 
          s.send(@cloud_img)
        end
      end
    end
  end
end

