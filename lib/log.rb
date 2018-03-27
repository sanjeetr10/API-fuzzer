require 'logger'
require 'rails'

class Log
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::DEBUG

  $logger.formatter = proc { |severity, datetime, progname, msg|
    call_details = Kernel.caller[4].gsub(/#{Rails.root}/, '');
    call_details.match /(.+):(.+):/
    filename = $1
    line = $2
    length = 40
    # filename = "#{filename[-length, filename.length]}" if filename.length >= length
    # filename = filename.rjust(length + 2, '.')
    # "[#{severity} #{datetime} #{filename}:#{line}] #{msg}\n"
    "[#{severity} #{datetime} #{filename}:#{line}] #{msg}\n"
  }
  # [DEBUG 2018-03-06 11:58:09 +0530 /Users/sanjeet.roy/projects/API-fuzzer-master/lib/testing.rb:80] Hi
  # D, [2018-03-06T11:59:18.356428 #11603] DEBUG -- : Hi

  def self.info(msg)
    $logger.info(msg)
  end

  def self.debug(msg)
    $logger.debug(msg)
  end

  def self.warn(msg)
    $logger.warn(msg)
  end

  def self.error(msg)
    $logger.error(msg)
  end

  def self.fatal(msg)
    $logger.fatal(msg)
  end
end
