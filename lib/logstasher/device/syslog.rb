# inspired by [lumberjack](https://github.com/bdurand/lumberjack_syslog_device)

require 'logstasher/device'
require 'syslog'
require 'thread'

module LogStasher
  module Device
    class Syslog
      include ::LogStasher::Device

      SEMAPHORE = Mutex.new

      attr_reader :options

      def initialize(options = {})
        raw_options = default_options.merge(stringify_keys(options))

        @options = parse_options(raw_options)
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
        options['facility']
      end

      def flags
        options['flags']
      end

      def identity
        options['identity']
      end

      def priority
        options['priority']
      end

      def write(log)
        fail ::RuntimeError, 'Cannot write. The device has been closed.' if closed?

        with_syslog_open do
          ::Syslog.log(facility, '%s', log)
        end
      end

      private

      def default_options
        {
          'identity' => 'logstasher',
          'facility' => ::Syslog::LOG_LOCAL0,
          'priority' => ::Syslog::LOG_INFO,
          'flags'    => ::Syslog::LOG_PID | ::Syslog::LOG_CONS
        }
      end

      def parse_option(value)
        case value
        when ::String
          ::Syslog.const_get(value.to_s)
        when ::Array
          value.reduce(0) { |all, current| all |= parse_option(current) }
        else
          value
        end
      end

      def parse_options(options)
        options['facility'] = parse_option(options['facility'])
        options['priority'] = parse_option(options['priority'])
        options['flags']    = parse_option(options['flags'])
        options
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
