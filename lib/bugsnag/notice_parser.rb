class Bugsnag::NoticeParser

  attr_reader :params, :invalid_events_count

  def initialize(params)
    @params = params || {}
  end

  def reports
    @invalid_events_count = 0
    @reports = []
    events.each do |event|
      begin
        exception = exception(event)
        attributes = {
          error_class: exception['errorClass'],
          message: exception['message'].to_s,
          backtrace: backtrace(exception),
          request: request(event),
          server_environment: server_environment(event),
          api_key: params['apiKey'],
          notifier: params['notifier'],
          user_attributes: user_attributes(event)
        }

        @reports << ErrorReport.new(attributes)
      rescue Bugsnag::NoExceptionError
        @invalid_events_count += 1
      end
    end

    if events.size == @invalid_events_count
      raise Bugsnag::NoValidEventsError
    end

    @reports
  end

  def has_invalid_events?
    @invalid_events_count.to_i != 0
  end

  private

  def events
    raise Bugsnag::NoEventsError unless params['events'].present?
    params['events']
  end

  def exception event
    raise Bugsnag::NoExceptionError unless event['exceptions'].present?
    event['exceptions'].first
  end

  def backtrace exception
    fetch(exception, 'stacktrace', []).map do |backtrace_line|
      data = {
        method: backtrace_line['method'],
        file: backtrace_line['file'],
        number: backtrace_line['lineNumber'],
        column: backtrace_line['columnNumber']
      }
      clear_empty(data)
    end
  end

  def server_environment event
    app = app(event)
    device = device(event)
    data = {
      'os-version' => device['osVersion'],
      'environment-name' => app['releaseStage'],
      'hostname' => device['hostname'],
      'app-version' => app['version']
    }
    clear_empty(data)
  end

  def request event
    device = device(event)
    environment = tab(event, 'environment')
    request = tab(event, 'request')
    cookies = tab(event, 'cookies')
    data = {
      'cgi-data' => environment,
      'session' => tab(event, 'session'),
      'params' => request['params'],
      'url' => request['url'],
      'component' => event['context'],
      'referer' => request['clientIp'],
      'httpMethod' => request['httpMethod'],
      'headers' => request['headers'],
      'cookies' => cookies,
      'threads' => event['threads']
    }
    clear_empty(data)
  end

  def tab event, name
    @tabs ||= {}
    @tabs[event] ||= {}
    @tabs[event][name] = fetch(event['metaData'], name)
  end

  def user_attributes event
    fetch(event, 'user').slice('id', 'name', 'email')
  end

  def app event
    @apps ||= {}
    @apps[event] ||= fetch(event, 'app')
  end

  def device event
    @devices ||= {}
    @devices ||= fetch(event, 'device')
  end

  def clear_empty hash
    hash.delete_if { |k, v| !v.present? }
  end

  def fetch hash, key, default = {}
    hash.try(:fetch, key, default) || default
  end

end
