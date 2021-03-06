require 'API_Fuzzer/vulnerability'
require 'API_Fuzzer/error'
require 'API_Fuzzer/request'
require 'log'

module API_Fuzzer
  class InvalidURLError < StandardError; end

  class SqlCheck
    attr_accessor :parameters
    attr_accessor :payloads, :sql_errors

    ALLOWED_METHODS = [:get, :post].freeze
    PAYLOAD_PATH = File.expand_path('../../../payloads/sql.txt', __FILE__)
    DETECT_PATH = File.expand_path('../../../payloads/detect/sql.txt', __FILE__)

    def self.scan(options = {})
      @payloads  = []
      @sql_errors = []

      @url = options[:url] || nil
      raise InvalidURLError, "[ERROR] URL missing in argument" unless @url
      Log.info("Starting Sql check for Url:#{@url}")

      Log.debug('Fetching payload for Sql Check')
      fetch_payloads

      Log.debug('Payload has been fetched..!!')


      @params = options[:params] || {}
      @cookies = options[:cookies] || {}
      @json = options[:json] || false
      @headers = options[:headers] || {}
      @vulnerabilities = []

      Log.info('Going to Fuzz the Payloads')
      fuzz_payloads

      Log.debug('Payloads has been Fuzzed...!!')
      Log.info('Sql check has benn completed..................!')

      return @vulnerabilities.uniq { |vuln| vuln.description }
    rescue HTTP::ConnectionError => e

      Log.error('Something Wrong with the Connection. Will try Again')
      sleep(5)
      fuzz_payloads
      return @vulnerabilities.uniq { |vuln| vuln.description }
    end


    def self.fuzz_payloads

      Log.debug('Going to Fuzz payloads ')
      @payloads.each do |payload|
        fuzz_each_payload(payload)
      end
    end

    def self.fuzz_each_payload(payload)

      Log.debug('Fuzzing payload =  #{payload}')
      uri = URI(@url)
      path = uri.path
      query = uri.query
      base_uri = query.nil? ? path : [path, query].join("?")

      Log.debug('Fragmenting the base_uri')
      fragments = base_uri.split(/[\/,?,&]/) - ['']

      Log.debug('Going to Fuzz each Fragment..')

      fragments.each do |fragment|
        if fragment.match(/\A(\w)+=(\w)*\z/)
          url = @url.gsub(fragment, [fragment, payload].join('')).chomp
          fuzz_each_fragment(url, payload)
        else
          url = @url.gsub(fragment, payload).chomp
          fuzz_each_fragment(url, payload)
        end
      end

      Log.debug("Checking Params for Empty = #{@params.empty?}")
      Log.debug('###############################################################################')

      return if @params.empty?

      Log.debug('Going to Fuzz each Params..')

      @params.keys.each do |parameter|
        fuzz_each_parameter(parameter, payload)
      end
    end

    def self.fuzz_each_fragment(url, payload)

      Log.debug("Fuzzing fragment =  #{payload} for url: #{url}")
      Log.debug('_________________________+++++++++++++++++++')

      ALLOWED_METHODS.each  do |method|
        begin
          Log.info("Sending #{method} request  to #{url}")
          response = API_Fuzzer::Request.send_api_request(
            url: url,
            method: method,
            cookies: @cookies,
            headers: @headers
          )
          Log.info("Response Code = #{response.code}")

          @vulnerabilities << API_Fuzzer::Error.new(description: "#{method} #{@url}", status: response.status, value: response.body) unless success?(response)
          body = ''
          if response_json?(response)
            body = JSON.parse(response.body)
          else
            body = response.body
          end

          vulnerable = check_response?(body.to_s.downcase, payload)
          next unless vulnerable
          @vulnerabilities << API_Fuzzer::Vulnerability.new(
            description: "Possible SQL injection in #{method} #{@url}",
            parameter: "URL: #{url}",
            value: "[PAYLOAD] #{payload}",
            type: 'HIGH'
          )
        rescue Exception => e
          puts e.message
        end
      end
    end

    def self.fuzz_each_parameter(parameter, payload)

      Log.info("payload =  #{payload}")
      Log.info("url =  #{@url}")

      @params[parameter] = payload
      ALLOWED_METHODS.each do |method|
        begin
          response = API_Fuzzer::Request.send_api_request(
            url: @url,
            params: @params,
            method: method,
            cookies: @cookies,
            headers: @headers
          )

          Log.info("Response Code = #{response.code}")

          @vulnerabilities << API_Fuzzer::Error.new(description: "[ERROR] #{method} #{@url}", status: response.status, value: response.body) unless success?(response)
          body = response.body.to_s.downcase
          vulnerable = check_response?(body, payload)
          next unless vulnerable

          @vulnerabilities << API_Fuzzer::Vulnerability.new(
            description: "Possible SQL injection in #{method} #{@url} parameter: #{parameter}",
            parameter: "parameter: #{@parameter}",
            value: "[PAYLOAD] #{payload}",
            type: 'HIGH'
          )
        rescue Exception => e
          puts e.message
        end
      end
    end

    def self.check_response?(body, payload)

      @sql_errors.each do |error|
        if body.match(error.chomp)
          puts error
          return true
        end
      end
      false
    end

    def self.success?(response)
      response.code == 200
    end

    def self.response_json?(response)
      response && response.headers['Content-Type'] && response.headers['Content-Type'].downcase =~ /application\/json/
    end

    def self.fetch_payloads
      file = File.expand_path(PAYLOAD_PATH, __FILE__)
      File.readlines(file).each do |line|
        @payloads << line
      end

      file = File.expand_path(DETECT_PATH, __FILE__)
      File.readlines(file).each do |line|
        @sql_errors << line.downcase
      end
    end
  end
end
