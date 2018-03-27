require 'API_Fuzzer/vulnerability'
require 'API_Fuzzer/error'
require 'API_Fuzzer/request'
require 'log'

module API_Fuzzer
  class CsrfCheck
    VALID_CSRF_PARAMS = ['csrf', 'token', 'authenticity_token', 'csrf_token'].map(&:downcase)
    VALID_CSRF_HEADERS = ['X-CSRF', 'CSRF-Token'].map(&:downcase)
    class << self
      def scan(options = {})
        @url = options[:url] || nil
        Log.info("Starting CSRF Scan for: #{@url}")

        @params = options[:params] || {}
        @cookies = options[:cookies] || {}
        @methods = options[:method] || [:get]
        @headers = options[:headers] || {}
        @json = options[:json] || false
        @vulnerabilities = []

        Log.debug("Going to Fuzz CSRF Scan")
        fuzz_csrf
        Log.info("CSRF Scan Completed...............!!")

        @vulnerabilities.uniq { |vuln| vuln.description }
      rescue Exception => e
        # Rails.logger.info e.message
        Log.error(e.message)
      end

      def fuzz_csrf
        Log.debug("Fuzzing CSRF Scan")
        @vulnerabilities << API_Fuzzer::Vulnerability.new(
          type: 'MEDIUM',
          value: 'No Cross-site request forgery protection found in API',
          description: "Cross-site request forgery vulnerability in GET #{@url}"
        ) if @methods.map(&:downcase).include?(:get)
      end

      def validate_csrf
        Log.debug("Validating CSRF Scan")
        params = @params
        headers = request.headers
        matched_headers = headers.keys.select { |header| VALID_CSRF_HEADERS.any? { |exp| header.match(exp) } }
        matched_param = params.keys.select { |param| VALID_CSRF_PARAMS.any? { |exp| param.match(exp) } }
      end
    end
  end
end
