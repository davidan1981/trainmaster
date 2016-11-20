class ApplicationMailer < ActionMailer::Base
  default from: Trainmaster::MAILER_EMAIL
  layout 'mailer'
end
