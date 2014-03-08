require 'spec_helper'

describe LogStasher do
  it 'has a version' do
    ::LogStasher::VERSION.should_not be_nil
  end

  it 'has a logger' do
    ::LogStasher.logger.should be_a_kind_of(::Logger)
  end

  it 'stores a callback for appending fields' do
    callback = proc { |fields| fail 'Did not expect this to run'  }

    ::LogStasher.append_fields(&callback)
    ::LogStasher.append_fields_callback.should be callback
  end
end
