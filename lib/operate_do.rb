require "operate_do/version"
require 'logger'

module OperateDo
  OPERATE_DO_KEY = :operate_do_operator

  class Config
    attr_reader :logger_class, :logger_initialize_proc

    def initialize
      @logger_class = OperateDo::Logger
      @logger_initialize_proc = nil
    end

    def logger=(logger_class, initialize_proc = nil)
      @logger_class = logger_class
      @logger_initialize_proc = initialize_proc
    end
  end


  class Logger
    def initialize(logger_instance = ::Logger.new(STDOUT))
      logger_insance ||= ::Logger.new(STDOUT)
      @logger_instance = logger_instance
    end

    def flush!(messages)
      messages.each do |message|
        @logger_instance.log log_level, build_message(message)
      end
    end

    def build_message(message)
      [
        message.operate_at.strftime('%Y%m%d%H%M%S'),
        "#{message.operator.operate_inspect} is operate : #{message.message}"
      ].join("\t")
    end

    def log_level
      ::Logger::INFO
    end
  end

  class Message
    attr_reader :operator, :message, :operate_at

    def initialize(operator, message, operate_at)
      @operator   = operator
      @message    = message
      @operate_at = operate_at
    end
  end

  class Recorder
    def initialize
      @operators = []
      @messages  = []
    end

    def push_operator(operator)
      @operators.push operator
    end

    def pop_operator
      @operators.pop
    end

    def current_operator
      @operators.last
    end

    def write(message, operate_at = Time.now)
      @messages << OperateDo::Message.new(current_operator, message, operate_at)
    end

    def flush_message!
      OperateDo.current_logger.flush!(@messages)
      @messages.clear
    end
  end

  class << self
    def configure
      @config ||= OperateDo::Config.new
      yield @Config if block_given?
    end

    def current_logger
      configure unless @config
      @current_logger ||= setup_logger
    end

    private def setup_logger
      if @config.logger_initialize_proc
        @config.logger_class.new(@config.logger_initialize_proc.call)
      else
        @config.logger_class.new
      end
    end

    def push_operator(operator)
      Thread.current[OPERATE_DO_KEY] ||= OperateDo::Recorder.new
      Thread.current[OPERATE_DO_KEY].push_operator operator
    end

    def pop_operator
      Thread.current[OPERATE_DO_KEY].pop_operator
    end

    def current_operator
      Thread.current[OPERATE_DO_KEY].current_operator
    end

    def flush_message!
      Thread.current[OPERATE_DO_KEY].flush_message!
    end

    def write(message, operate_at = Time.now)
      Thread.current[OPERATE_DO_KEY].write(message, operate_at)
    end
  end

  module Operator
    def operate
      OperateDo.push_operator self

      begin
        yield
      ensure
        OperateDo.pop_operator
        OperateDo.flush_message! unless OperateDo.current_operator
      end
    end

    def operate_inspect
      inspect
    end
  end
end
