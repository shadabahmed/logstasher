require 'action_mailer'

class SampleMailer < ActionMailer::Base
  def welcome
    mail(from: 'some-dude@example.com', to: 'some-other-dude@example.com', subject: 'Hello, there') do |format|
      format.text { render plain: 'OK' }
    end
  end

  def receive(email)
  end

  def _render_template(_)
    ""
  end
end
