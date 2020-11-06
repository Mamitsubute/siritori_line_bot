class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'json'
  require 'net/https'
  require "uri"

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head :bad_request
    end

    events = client.parse_events_from(body)

    events.each { |event|

      # # event.message['text']でLINEで送られてきた文書を取得
      # if event.message['text'].include?("好き")
      #   response = "へーい"
      # elsif event.message["text"].include?("行ってきます")
      #   response = "はーい"
      # else
      #   response = "test"
      # end
      # #if文でresponseに送るメッセージを格納
      response = fetch_word_from_api(word:"ア",word_count:6)

      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'text',
            text: response
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end

  private

  def fetch_word_from_api(word:,word_count:)
    uri = URI.parse URI.encode "https://siritori-api.herokuapp.com/api/v1/?word=#{word}&word_count=#{word_count.to_s}"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri)
    res = http.request(req)
    result = JSON.parse(res.body)
    result["data"][0]["word"]
  end
end