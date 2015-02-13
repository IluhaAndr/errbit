class Bugsnag::NoticesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  respond_to :json

  def create
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'origin, content-type, accept'

    parser = Bugsnag::NoticeParser.new(params)
    reports = parser.reports
    notices_ids = []
    invalid_notices, old_app_notices_size = 0, 0

    reports.each do |report|
      if report.valid?
        if report.should_keep?
          report.generate_notice!
          if report.notice.valid?
            notices_ids << report.notice.id
          else
            invalid_notices += 1
          end
        else
          old_app_notices_size += 1
        end
      else
        raise ErrorReport::ApiKeyError
      end
    end

    raise Bugsnag::NoValidEventsError if invalid_notices == reports.size

    render text: response_message(parser.invalid_events_count + invalid_notices,
                   notices_ids, old_app_notices_size)

  rescue ErrorReport::ApiKeyError
    render text: 'Your API key is unknown.', status: 422
  rescue Bugsnag::NoValidEventsError
    render text: 'No valid events were found.', status: 400
  rescue Bugsnag::NoEventsError
    render text: 'No events were found.', status: 400
  end

  private

  def response_message invalid_events_count, notices_ids, old_app_notices_size
    messages = []
    if notices_ids.present?
      messages << [ "Notices with ids #{notices_ids.join(', ')} were saved." ]
    end
    if invalid_events_count != 0
      messages << "#{invalid_events_count} invalid events were found."
    end
    if old_app_notices_size != 0
      messages << "#{old_app_notices_size} old app notices were found."
    end

    messages.join(' ')
  end

end
