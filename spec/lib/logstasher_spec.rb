require 'spec_helper'

describe LogStasher do
  it 'has a version' do
    expect(::LogStasher::VERSION).not_to be_nil
  end

  it 'has a logger' do
    expect(::LogStasher.logger).to be_a_kind_of(::Logger)
  end

  it 'stores a callback for appending fields' do
    callback = proc { |fields| fail 'Did not expect this to run'  }

    ::LogStasher.append_fields(&callback)
    expect(::LogStasher.append_fields_callback).to be callback
  end
end
