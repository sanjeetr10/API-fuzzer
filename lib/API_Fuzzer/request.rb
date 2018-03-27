require 'http'
require 'log'

module API_Fuzzer
  class Request
    attr_accessor :response, :request

    class << self
      def send_api_request(options = {})

        Log.debug('Preparing the Query')

        @url = options.delete(:url)
        @params = options.delete(:params) || {}
        @method = options.delete(:method) || :get
        @json = options.delete(:json) ? true : false
        @body = options.delete(:body) ? true : false
        @request = set_cookies_headers(options)

        Log.debug('Cookie header Has Been Set. Now Going to Send the Request')

        send_request
      end
    end

    def response
      @response
    end

    def success?
      @response.code == 200
    end

    private

    def self.set_cookies_headers(options = {})

      Log.debug('Setting the Cookie and Header')

      cookies = options.delete(:cookies) || {}
      headers = options.delete(:headers) || {}

      Log.debug("cookie = #{cookies}")
      Log.debug("headers = #{headers}")

      request_object = HTTP.headers(headers).cookies(cookies)
      Log.debug('Request Object has been Set')

      request_object
    end

    def self.send_request

      Log.debug("Sending... #{@method.to_sym} to #{@url} with Params = #{set_params}")

      @response = case @method.to_sym
      when :post
        @request.post(@url, set_params)
      when :put
        @request.put(@url, set_params)
      when :patch
        @request.patch(@url, set_params)
      when :head
        @request.head(@url, set_params)
      when :delete
        @request.delete(@url, set_params)
      else
        @request.get(@url, set_params)
      end
    end

    def self.set_params
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if @json && !method_get?
        { 'json' => @params, 'ssl_context' => ctx }
      elsif method_get?
        { 'params' => @params, 'ssl_context' => ctx }
      elsif @body
        { 'body' => @params, 'ssl_context' => ctx }
      else
        { 'form' => @params, 'ssl_context' => ctx  }
      end
    end

    def self.method_get?
      @method.to_s == 'get'
    end
  end
end
