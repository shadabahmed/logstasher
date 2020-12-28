# frozen_string_literal: true

require 'action_mailer'

class SampleMailer < ActionMailer::Base
  default 'message-id': 'message-id' # this is needed to make sure that the message id is set

  def welcome
    mail(from: 'some-dude@example.com', to: 'some-other-dude@example.com', subject: 'Hello, there') do |format|
      format.text { render plain: 'OK' }
    end
  end

  def receive(email); end

  def _render_template(_)
    ''
  end
end
