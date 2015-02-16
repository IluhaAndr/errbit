describe Bugsnag::NoticesController, type: :controller do
  let(:app) { Fabricate(:app) }

  it 'sets CORS headers on POST request' do
    post :create
    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
    expect(response.headers['Access-Control-Allow-Headers']).to eq('origin, content-type, accept')
  end

  it 'returns created notice id in json format' do
    json = Rails.root.join('spec', 'fixtures', 'bugsnag_request.json').read
    data = JSON.parse(json)
    data['apiKey'] = app.api_key
    post :create, data.to_json
    notice = Notice.last
    expect(response.body).to match(/\ANotices with ids [0-9a-z, ]+ were saved\.\Z/)
    expect(Notice.count).to eq(2)
  end

  it 'responds with 400 when request attributes are not valid' do
    allow_any_instance_of(Bugsnag::NoticeParser).to receive(:reports).and_raise(Bugsnag::NoValidEventsError)
    post :create
    expect(response.status).to eq(400)
    expect(response.body).to eq('No valid events were found.')
    expect(Notice.count).to eq(0)
  end

  it 'responds with 400 when request attributes are not valid' do
    allow_any_instance_of(Bugsnag::NoticeParser).to receive(:reports).and_raise(Bugsnag::NoEventsError)
    post :create
    expect(response.status).to eq(400)
    expect(response.body).to eq('No events were found.')
    expect(Notice.count).to eq(0)
  end

  it 'responds with 422 when apiKey is invalid' do
    json = Rails.root.join('spec', 'fixtures', 'bugsnag_request.json').read
    data = JSON.parse(json)
    data['apiKey'] = 'invalid'
    post :create, data.to_json
    expect(response.status).to eq(422)
    expect(response.body).to eq('Your API key is unknown.')
    expect(Notice.count).to eq(0)
  end

  it 'ignores notices for older api' do
    upgraded_app = Fabricate(:app, current_app_version: '2.0')
    json = Rails.root.join('spec', 'fixtures', 'bugsnag_request.json').read
    data = JSON.parse(json)
    data['apiKey'] = upgraded_app.api_key
    post :create, data.to_json
    expect(response.body).to match(/\ANotices with ids [0-9a-z, ]+ were saved\. 1 old app notices were found\.\Z/)
    expect(Notice.count).to eq(1)
  end

  it 'process request with device and app optional fields' do
    upgraded_app = Fabricate(:app)
    json = Rails.root.join('spec', 'fixtures', 'bugsnag_request_with_device_app_optional.json').read
    data = JSON.parse(json)
    data['apiKey'] = upgraded_app.api_key
    post :create, data.to_json
    expect(response.body).to match(/\ANotices with ids [0-9a-z, ]+ were saved\.\Z/)
    expect(Notice.count).to eq(1)
  end

  it 'process request without optional fields' do
    upgraded_app = Fabricate(:app)
    json = Rails.root.join('spec', 'fixtures', 'bugsnag_request_without_optional.json').read
    data = JSON.parse(json)
    data['apiKey'] = upgraded_app.api_key
    post :create, data.to_json
    expect(response.body).to eq('No valid events were found.')
    expect(Notice.count).to eq(0)
  end

end
