module KubeBackup
  module Logger

    def logger
      @logger ||= begin
        require 'logger'
        logger = ::Logger.new(STDOUT)
        logger.level = ::Logger::INFO

        logger.formatter = proc { |severity, datetime, progname, msg|
          res = "#{datetime.strftime("%T.%L")}: #{msg}\n"
          if severity == "WARN"
            puts res.colorize(:yellow)
          elsif severity == "ERROR"
            puts res.colorize(:red)
          elsif severity == "DEBUG"
            puts res.colorize(:light_black)
          else
            puts res
          end
        }

        logger
      end
    end

    def verbose_logger!
      self.logger.level = ::Logger::DEBUG
    end

    def verbose_logging?
      self.logger.level == ::Logger::DEBUG
    end

  end
end
