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
#require 'cloudinary/helper'

require 'line/bot'

get '/' do
  "Hello world"
end

# @clientがnull or falseの場合、代入する
def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def cloudinary_uploader

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
      # メッセージタイプが画像、動画の場合
      when Line::Bot::Event::MessageType::Image
        response = client.get_message_content(event.message['id'])
        file = File.open("/tmp/temp.jsp", "w+b")
        file.write(response.body)
        MessageImage.create!(message: message, value: file)
        File.unlink(file)
#        File.open(path, 'wb') do |f|
#          f.write(response.body) 
#        end
        message = {
#          type: 'image'
#          originalContentUrl: 
#          previewImageUrl: 
           type: 'text',
           text: 'テスト'
        }
#        Cloudinary::Uploader.upload(path, :width => 150, :height => 100, :crop => :limit)
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

 "OK"
end






# 画像のアップロード
# アップロード画面
get '/upload' do
  images_name = Dir.glob("app/public/images/*")
  @images_path=[] 

  images_name.each do |image|
    @images_path << image.gsub("app/public/","/")
  end
  erb :upload
end

# Cloudinaryへ画像アップロード
post '/cloudinary_upload' do
  # アップロード画面のパラメータ有無判定
  # params内のデータ
  # :tupe -> 画像の保存形式
  # :head -> ヘッダー
  # :file -> erbのname
  # :filename -> ファイル名
  # :tempfile -> 画像ファイルのリファレンス
  if params[:file]
    save_path = "./app/public/images/#{params[:file][:filename]}"
    File.open(save_path, 'wb') do |f|
      f.write params[:file][:tempfile].read
    end
    Cloudinary::Uploader.upload(save_path, :width => 150, :height => 100, :crop => :limit)
  else
   @massage = "アップロード失敗"
  end
  erb :upload
end


# ---------------------------------------------

# Cloudinaryから画像取得
get '/cloudinary_pull' do
#  include CloudinaryHelper
#  @config = settings.cloud_name
#  @config 
#  @cloud_img = CloudinaryHelper.cl_image_tag("sample.jpg", :width=>300, :height=>100, :crop=>"scale") 
  @cloud_img = Cloudinary::Utils.cloudinary_url("sample.jpg", :height=>154, :width=>394, :crop=>"scale") 
  puts @cloud_img  
  erb :index
end
  
# 単純画像表示
get '/test_page' do
  erb :test_page
end

# 複数画像表示
get '/test_page2' do
  images_name = Dir.glob("public/images/*")
  @images_path=[] 

  images_name.each do |image|
    @images_path << image.gsub("public/","/")
  end
  erb :test_page2
end

# 画像のアップロード
# アップロード画面
get '/test_page3' do
  images_name = Dir.glob("public/images/*")
  @images_path=[] 

  images_name.each do |image|
    @images_path << image.gsub("public/","/")
  end
  erb :test_page3
end

# アップロード画面表示
post '/test_upload' do
  # アップロード画面のパラメータ有無判定
  # params内のデータ
  # :tupe -> 画像の保存形式
  # :head -> ヘッダー
  # :file -> erbのname
  # :filename -> ファイル名
  # :tempfile -> 画像ファイルのリファレンス
  if params[:file]
    save_path = "./public/images/#{params[:file][:filename]}"
 
    File.open(save_path, 'wb') do |f|
      p params[:file][:tempfile]
      f.write params[:file][:tempfile].read
      @massage = "アップロード成功"
    end
  else
   @massage = "アップロード失敗"
  end
  erb :test_page3
end

# WebSocketでチャットを作る
# サーバとして'thin'を使う
set :server, 'thin'
# WebSocket通信で情報が更新された時にレスポンスを送る先を入れる
set :sockets, []

get '/index' do
  erb :index
end

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
        settings.sockets.each do |s|
          # WebSocket通信でsndする
          # WebSocket通信で、クライアントに向かって情報をおくる
          # sendメソッドでは、１クライアントにしか送れない。
          s.send(msg)
        end
      end
      # WebSocket通信が切断された時の処理をまとめる
      ws.onclose do
        # wsを削除
        settings.sockets.delete(ws)
      end
    end
  end
end

# WebSocketで画像チャットを作る
get '/index2' do
  erb :index2
end

get '/websocket2' do
 if request.websocket?
   request.websocket do |ws|

     ws.onopen do
       settings.sockets << ws
     end

     meflg=false
     save_path=""
     ws.onmessage do |me| 
       # 1番目はファイル名取得
       # ws.onmessage.each_with_index do |me, i|
       # sf = img.slice(/\/(.*)/)
       if meflg == false
         save_path = "./public/images/#{me}"
         meflg = true
       else
         # 2番目はファイルの書き出し
         File.open(save_path, 'w+b') do |f|
           # 1バイトずつ書き込み
           f.write me.each_byte { |b| print b }
         end
         settings.sockets.each do |s|
           puts save_path
           s.send(save_path)
         end
       end
     end
    
     ws.onclose do
       settings.sockets.delete(ws)
     end
   end
 end
end

