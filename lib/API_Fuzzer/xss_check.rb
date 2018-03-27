require 'API_Fuzzer/vulnerability'
require 'API_Fuzzer/error'
require 'API_Fuzzer/request'
require 'log'

module API_Fuzzer

  class InvalidURLError < StandardError; end

  class XssCheck
    attr_accessor :parameters

    ALLOWED_METHODS = [:get, :post].freeze
    PAYLOADS = []
    PAYLOAD_PATH = File.expand_path('../../../payloads/xss.txt', __FILE__)

    def self.scan(options = {})

      @url = options[:url] || nil
      Log.info("Starting Xss Scan for: #{@url}")

      raise InvalidURLError, "[ERROR] URL missing in argument" unless @url
      @params = options[:params] || {}
      @cookies = options[:cookies] || {}
      @headers = options[:headers] || {}
      @json = options[:json] || false
      @vulnerabilities = []

      Log.debug('Going to fetch the payloads')
      fetch_payloads
      Log.debug('Payloads has been Fetched!!')

      Log.debug('Going to fuzz Each payloads')
      PAYLOADS.each do |payload|
        fuzz_each_payload(payload)
      end
      Log.info("Xss Scan has been Completed....!")
      @vulnerabilities.uniq { |vuln| vuln.description }
    end

    private

    def self.fuzz_each_payload(payload)
      Log.debug('Going to fuzz Each key in params........')
      @params.keys.each do |parameter|
        fuzz_each_parameter(parameter, payload)
      end
    end

    def self.fuzz_each_parameter(parameter, payload)
      Log.debug("Fuzzing params = #{parameter} with payload = #{payload}")
      @params[parameter] = payload

      ALLOWED_METHODS.each do |method|
        response = API_Fuzzer::Request.send_api_request(
          url: @url,
          params: @params,
          method: method,
          cookies: @cookies,
          headers: @headers
        )

        Log.info("Response Code = #{response.code}")

        if response_json?(response)
          body = JSON.parse(response.body)
        else
          vulnerable = check_response?(response.body, payload)

          if success?(response)
            @vulnerabilities << API_Fuzzer::Vulnerability.new(
              description: "Possible XSS in #{method} #{@url} parameter: #{@parameter}",
              value: "[PAYLOAD] #{payload}",
              type: 'MEDIUM'
            ) if vulnerable
          else
            API_Fuzzer::Error.new(description: "[ERROR] #{method} #{@url}", status: response.status, value: response.body)
          end
        end
      end
    end

    def self.check_response?(body, payload)
      if body.to_s.include?(payload)
        return true
      end
      false
    end

    def self.success?(response)
      response.code == 200
    end

    def self.response_json?(response)
      response && response.headers['Content-Type'].downcase =~ /application\/json/
    end

    def self.fetch_payloads
      file = File.expand_path(PAYLOAD_PATH, __FILE__)
      File.readlines(file).each do |line|
        PAYLOADS << line
      end
    end
  end
end
