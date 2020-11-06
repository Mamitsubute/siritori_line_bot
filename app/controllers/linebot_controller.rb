class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'json'
  require 'net/https'
  require "uri"
  require 'nkf'

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
      message = event.message['text'].gsub(/[[:space:]]/,'')
      word = NKF.nkf("--katakana -w",message[0])
      word_count = message[1]
      response = fetch_word_from_api(word:word, word_count:word_count)

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