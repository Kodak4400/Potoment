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

get '/test_page' do
  @t_cloud_img = Cloudinary::Utils.cloudinary_url("20180308010833.jpg")
  @t_cloud_img = Cloudinary::Utils.cloudinary_url("20180308010857.jpg")
  erb :test_page
end


get '/potoment_page' do
  erb :potoment_page 
end

# @clientがnull or falseの場合、代入する
def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

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
          text: event.message['text']
        }
        # メッセージを返す
        client.reply_message(event['replyToken'], message)
        websocket_message
      # メッセージタイプが画像の場合
      when Line::Bot::Event::MessageType::Image
        pid = DateTime.now.strftime('%Y%m%d%H%M%S')
        path = "./tmp/#{pid}.jpg"
        response = client.get_message_content(event.message['id'])
        file = File.open(path, "wb")
        file.write(response.body)
        #Cloudinary::Uploader.upload(path, :public_id => pid, :width => 450, :height => 150, :crop => :limit)
        Cloudinary::Uploader.upload(path, :public_id => pid, :width => 0.5, :height => 0.5 , :crop => :scale)
        puts system('ls -ltr ./tmp') 
        message = {
           type: 'text',
           text: '画像をアップロードしました。'
        }
        client.reply_message(event['replyToken'], message)
        File.unlink(file)
        websocket_image(pid)
        #@cloud_img = Cloudinary::Utils.cloudinary_url("#{pid}.jpg", :height=>154, :width=>394, :crop=>"scale") 
        #puts @cloud_img
        #@page_title = "index message"
        #erb :potoment_page
      when Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

 "OK"
end

# Cloudinaryから画像取得
# WebSocketでチャットを作る
# サーバとして'thin'を使う
set :server, 'thin'
# WebSocket通信で情報が更新された時にレスポンスを送る先を入れる
set :sockets, []

get '/websocket' do
  # WebSocket通信かどうか
  if request.websocket?
    # WebSocket通信の場合、wsにセッティング情報書き込み
    # wsは、サーバーの情報やクライアントの情報が詰まった変数
    request.websocket do |ws|
      # WebSocket通信のための接続がされようとしている時の処理をまとめる
      ws.onopen do
        # set :socketsを呼び出し
        settings.sockets << ws
      end
      # WebSocket通信によってメッセージが来た時の処理をまとめる
      ws.onmessage do |msg|
#        puts msg
#        settings.sockets.each do |s|
          # WebSocket通信でsndする
          # WebSocket通信で、クライアントに向かって情報をおくる
          # sendメソッドでは、１クライアントにしか送れない。
#          s.send(msg)
#        end
      end
      # WebSocket通信が切断された時の処理をまとめる
      ws.onclose do
        # wsを削除
        settings.sockets.delete(ws)
      end
#      def websocket_message
#        settings.sockets.each do |s|
#          s.send("aaa")
#        end
#      end
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

