require 'omniauth-oauth'
require 'json'

module OmniAuth
  module Strategies
    class Twitter < OmniAuth::Strategies::OAuth
      option :name, 'twitter'

      option :client_options, {:authorize_path => '/oauth/authenticate',
                               :site => 'https://api.twitter.com',
                               :proxy => ENV['http_proxy'] ? URI(ENV['http_proxy']) : nil}

      uid { access_token.params[:user_id] }

      info do
        {
          :nickname => raw_info['username'],
          :name => raw_info['name'],
          :email => raw_info["email"],
          :location => raw_info['location'],
          :image => raw_info["profile_image_url"],
          :description => raw_info['description'],
          :urls => {
            'Website' => raw_info['url'],
            'Twitter' => "https://twitter.com/#{raw_info['username']}",
          }
        }
      end

      extra do
        skip_info? ? {} : { :raw_info => raw_info }
      end

      def raw_info
        @raw_info ||= JSON.load(access_token.get('/2/users/me?user.fields=created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,verified_type,withheld').body)["data"]
      rescue ::Errno::ETIMEDOUT
        raise ::Timeout::Error
      end

      alias :old_request_phase :request_phase

      def request_phase
        %w[force_login lang screen_name].each do |v|
          if request.params[v]
            options[:authorize_params][v.to_sym] = request.params[v]
          end
        end

        %w[x_auth_access_type].each do |v|
          if request.params[v]
            options[:request_params][v.to_sym] = request.params[v]
          end
        end

        if options[:use_authorize] || request.params['use_authorize'] == 'true'
          options[:client_options][:authorize_path] = '/oauth/authorize'
        else
          options[:client_options][:authorize_path] = '/oauth/authenticate'
        end

        old_request_phase
      end

      alias :old_callback_url :callback_url

      def callback_url
        if request.params['callback_url']
          request.params['callback_url']
        else
          old_callback_url
        end
      end

      def callback_path
        params = session['omniauth.params']

        if params.nil? || params['callback_url'].nil?
          super
        else
          URI(params['callback_url']).path
        end
      end
    end
  end
end
