# inspired by [lumberjack](https://github.com/bdurand/lumberjack_syslog_device)

require 'logstasher/device'
require 'syslog'

module LogStasher
  module Device
    class Syslog
      include ::LogStasher::Device

      attr_reader :options

      def initialize(options = {})
        raw_options = default_options.merge(stringify_keys(options))

        @options = parse_options(raw_options)
        open_syslog
      end

      def close
        ::Syslog.close rescue nil
      end

      def closed?
        !::Syslog.opened?
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
        fail ::RuntimeError, 'Syslog has been closed.' if closed?
        fail ::RuntimeError, 'Syslog re-configured unexpectedly.' if syslog_config_changed?

        ::Syslog.log(priority, '%s', log)
      end

      private

      def default_options
        {
          'identity' => 'logstasher',
          'facility' => ::Syslog::LOG_LOCAL0,
          'priority' => ::Syslog::LOG_INFO,
          'flags'    => ::Syslog::LOG_PID | ::Syslog::LOG_CONS,
        }
      end

      def open_syslog
        if ::Syslog.opened?
          ::Syslog.reopen(identity, flags, facility)
        else
          ::Syslog.open(identity, flags, facility)
        end
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

      def syslog_config_changed?
        ::Syslog.ident != identity || ::Syslog.options != flags || ::Syslog.facility != facility
      end
    end
  end
end
