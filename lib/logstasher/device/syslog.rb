# inspired by [lumberjack](https://github.com/bdurand/lumberjack_syslog_device)

require 'syslog'
require 'thread'

module LogStasher
  module Device
    class Syslog

      SEMAPHORE = Mutex.new

      attr_reader :options

      def initialize(options = {})
        @options = default_options.merge(options)
        @closed  = false
      end

      def close
        SEMAPHORE.synchronize do
          ::Syslog.close if ::Syslog.opened?
        end

        @closed = true
      end

      def closed?
        @closed
      end

      def facility
        options[:facility]
      end

      def flags
        options[:flags]
      end

      def identity
        options[:identity]
      end

      def priority
        options[:priority]
      end

      def write(log)
        fail ::RuntimeError, 'Cannot write. The device has been closed.' if closed?

        with_syslog_open do
          ::Syslog.log(facility, log)
        end
      end

      private

      def default_options
        {
          :identity => 'logstasher',
          :facility => ::Syslog::LOG_LOCAL0,
          :priority => ::Syslog::LOG_INFO,
          :flags    => ::Syslog::LOG_PID | ::Syslog::LOG_CONS
        }
      end

      def syslog_configured?
        ::Syslog.ident == identity && ::Syslog.options == flags && ::Syslog.facility == facility
      end

      def with_syslog_open
        SEMAPHORE.synchronize do
          if ::Syslog.opened?
            ::Syslog.reopen(identity, flags, facility) unless syslog_configured?
          else
            ::Syslog.open(identity, flags, facility)
          end

          yield
        end
      end
    end
  end
end
