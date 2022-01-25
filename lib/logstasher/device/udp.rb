# simple UDP logger

require 'logstasher/device'
require 'socket'


module LogStasher
  class << self
    attr_accessor :namespace
  end

  module Device
    class UDP
      include ::LogStasher::Device

      attr_reader :options, :socket

      def initialize(options = {})
        @options = default_options.merge(stringify_keys(options))
        LogStasher::namespace = @options["namespace"]
        @socket = UDPSocket.new
      end

      def close
        @socket.close
      end

      def write(log)
        @socket.send(log, 0, options['hostname'], options['port'])
      end

      private

      def default_options
        {
          'hostname' => '127.0.0.1',
          'port'     => 31459,
          'namespace' => 'test'
        }
      end
    end
  end
end



