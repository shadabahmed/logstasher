# frozen_string_literal: true

require 'logstasher/custom_fields'

describe LogStasher::CustomFields do
  describe '#add' do
    before do
      LogStasher::CustomFields.clear
      LogStasher::CustomFields.add(:test, :test2)
    end

    after do
      LogStasher::CustomFields.clear
    end

    it 'returns the stored var in current thread' do
      expect(Thread.current[:logstasher_custom_fields]).to eq %i[test test2]
    end
  end
end
