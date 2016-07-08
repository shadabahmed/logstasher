require 'logstasher/custom_fields'

describe LogStasher::CustomFields do
  describe '#add' do
    before(:each) { LogStasher::CustomFields.add(:test, :test2) }
    after(:each) { LogStasher::CustomFields.custom_fields = [] }
    it 'returns the stored var in current thread' do
      expect(Thread.current[:logstasher_custom_fields]).to eq [:test, :test2]
    end
  end
end
