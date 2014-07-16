require 'action_mailer'

class SampleMailer < ActionMailer::Base
  def welcome
    mail(from: 'some-dude@example.com', to: 'some-other-dude@example.com', subject: 'Hello, there')
  end

  def receive(email)
  end
end
