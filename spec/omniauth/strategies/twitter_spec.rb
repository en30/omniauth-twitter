require 'spec_helper'

describe OmniAuth::Strategies::Twitter do
  let(:request) { double('Request', :params => {}, :cookies => {}, :env => {}) }

  subject do
    args = ['appid', 'secret', @options || {}].compact
    OmniAuth::Strategies::Twitter.new(*args).tap do |strategy|
      allow(strategy).to receive(:request) {
        request
      }
    end
  end

  describe 'client options' do
    it 'should have correct name' do
      expect(subject.options.name).to eq('twitter')
    end

    it 'should have correct site' do
      expect(subject.options.client_options.site).to eq('https://api.twitter.com')
    end

    it 'should have correct authorize url' do
      expect(subject.options.client_options.authorize_path).to eq('/oauth/authenticate')
    end
  end

  describe 'info' do
    before do
      allow(subject).to receive(:raw_info).and_return(raw_info_hash)
    end

    it 'should returns the nickname' do
      expect(subject.info[:nickname]).to eq(raw_info_hash['username'])
    end

    it 'should returns the name' do
      expect(subject.info[:name]).to eq(raw_info_hash['name'])
    end

    it 'should returns the email' do
      expect(subject.info[:email]).to eq(raw_info_hash['email'])
    end

    it 'should returns the location' do
      expect(subject.info[:location]).to eq(raw_info_hash['location'])
    end

    it 'should returns the description' do
      expect(subject.info[:description]).to eq(raw_info_hash['description'])
    end

    it 'should returns the urls' do
      expect(subject.info[:urls]['Website']).to eq(raw_info_hash['url'])
      expect(subject.info[:urls]['Twitter']).to eq("https://twitter.com/#{raw_info_hash['username']}")
    end
  end

  describe 'skip_info option' do
    context 'when skip info option is enabled' do
      it 'should not include raw_info in extras hash' do
        @options = { :skip_info => true }
        allow(subject).to receive(:raw_info).and_return({:foo => 'bar'})
        expect(subject.extra[:raw_info]).to eq(nil)
      end
    end
  end

  describe 'request_phase' do
    context 'with no request params set and x_auth_access_type specified' do
      before do
        allow(subject).to receive(:request).and_return(
          double('Request', {:params => {'x_auth_access_type' => 'read'}})
        )
        allow(subject).to receive(:old_request_phase).and_return(:whatever)
      end

      it 'should not break' do
        expect { subject.request_phase }.not_to raise_error
      end
    end

    context "with no request params set and use_authorize options provided" do
      before do
        @options = { :use_authorize => true }
        allow(subject).to receive(:request) do
          double('Request', {:params => {} })
        end
        allow(subject).to receive(:old_request_phase) { :whatever }
      end

      it "should switch authorize_path from authenticate to authorize" do
        expect { subject.request_phase }.to change { subject.options.client_options.authorize_path }.from('/oauth/authenticate').to('/oauth/authorize')
      end
    end

    context 'with a specified callback_url in the params' do
      before do
        params = { 'callback_url' => 'http://foo.dev/auth/twitter/foobar' }
        allow(subject).to receive(:request) do
          double('Request', :params => params)
        end
        allow(subject).to receive(:session) do
          double('Session', :[] => { 'callback_url' => params['callback_url'] })
        end
        allow(subject).to receive(:old_request_phase) { :whatever }
      end

      it 'should use the callback_url' do
        expect(subject.callback_url).to eq 'http://foo.dev/auth/twitter/foobar'
      end

      it 'should return the correct callback_path' do
        expect(subject.callback_path).to eq '/auth/twitter/foobar'
      end
    end

    context 'with no callback_url set' do
      before do
        allow(subject).to receive(:request) do
          double('Request', :params => {})
        end
        allow(subject).to receive(:session) do
          double('Session', :[] => {})
        end
        allow(subject).to receive(:old_request_phase) { :whatever }
        allow(subject).to receive(:old_callback_url).and_return(:old_callback)
      end

      it 'callback_url should return nil' do
        expect(subject.callback_url).to eq :old_callback
      end

      it 'should return the default callback_path value' do
        expect(subject.callback_path).to eq '/auth/twitter/callback'
      end
    end

    context "with no request params set and force_login specified" do
      before do
        allow(subject).to receive(:request) do
          double('Request', {:params => { 'force_login' => true } })
        end
        allow(subject).to receive(:old_request_phase) { :whatever }
      end

      it "should change add force_login=true to authorize_params" do
        expect { subject.request_phase }.to change {subject.options.authorize_params.force_login}.from(nil).to(true)
      end
    end
  end
end

private

def raw_info_hash
  {
    'username' => 'foo',
    'name' => 'Foo Bar',
    'email' => 'foo@example.com',
    'location' => 'India',
    'description' => 'Developer',
    'url' => 'example.com/foobar'
  }
end
