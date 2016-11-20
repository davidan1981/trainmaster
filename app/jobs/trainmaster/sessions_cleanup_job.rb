module Trainmaster
  class SessionsCleanupJob < ActiveJob::Base
    queue_as :default

    def perform(*args)
      # Do something later
      args.each do |uuid|
        session = Session.find_by_uuid(uuid)
        session.destroy()
      end
    end
  end
end
