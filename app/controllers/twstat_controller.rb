require 'tempfile'
require 'tweet_stats'
require 'api_key'

class TwstatController < ApplicationController

  def initialize
    super
    @COUNT_DEFS = TweetStats::COUNT_DEFS
  end

  def index
    @title = 'Log in'
    if session[:userid]
      redirect_to :action => :dashboard
      return
    end
  end

  def login
    apikey = ApiKey.new
    oauth = OAuth::Consumer.new(apikey.consumer_key, apikey.consumer_secret,
                                { :site => "https://api.twitter.com" })
    request_token = oauth.get_request_token(:oauth_callback => apikey.callback_url)

    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
    redirect_to request_token.authorize_url.sub('authorize', 'authenticate')
  end

  def logout
    session[:userid] = nil
    session[:username] = nil
    redirect_to :action => :index
  end

  def oauth
    unless params[:oauth_verifier]
      redirect_to :action => :index
      return
    end

    apikey = ApiKey.new
    oauth = OAuth::Consumer.new(apikey.consumer_key, apikey.consumer_secret,
                                { :site => "https://api.twitter.com" })
    request_token = OAuth::RequestToken.new(oauth, session[:request_token],
                                            session[:request_token_secret])
    access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])

    response = oauth.request(:get, '/1.1/account/verify_credentials.json', access_token, { :scheme => :query_string })
    @user_info = JSON.parse response.body

    session[:username] = @user_info['screen_name']
    session[:userid] = @user_info['id']

    User.find_or_create_by_userid(session[:userid]) { |u| 
      u.username = session[:username] 
    }
    
    redirect_to :action => :dashboard
  end

  def dashboard
    @title = 'Dashboard'

    @userid = session[:userid]
    unless @userid
      redirect_to :action => :index
      return
    end

    @user = User.find_by_userid @userid

    unless @user
      # No user record? Let user log in again.
      session[:userid] = nil
      session[:username] = nil
      redirect_to :action => :index
      return
    end

    @user_status = if @user.status
                     JSON.parse @user.status
                   else
                     { 'status' => 'ready', 'tweetsDone' => 0, 'untilDate' => '' }
                   end

    @last_generated = @user.last_generated
    @cancel = @user.cancel
    logger.info @user_status.to_s
    @do_refresh = (@user_status['status'] == 'busy' || @user_status['status'] == 'waiting')
  end

  def upload
    @userid = session[:userid]
    unless @userid
      redirect_to :action => :index
      return
    end

    uploaded_file = params[:tweetdata]
    @uploadtemp = Tempfile.new ['tweetdata', '.zip'], :encoding => 'ascii-8bit'
    @uploadtemp.write uploaded_file.read
    @uploadtemp.close

    TweetStats::update_status @userid, 'waiting', 0, ''
    TweetStats.new(@userid, @uploadtemp.path).delay.run

    redirect_to :action => :dashboard
  end

  def about
    @title = 'About'
    @userid = session[:userid]
  end

  def cancel
    @userid = session[:userid]
    unless @userid
      redirect_to :action => :index
      return
    end

    Delayed::Job.all.each { |job|
      if job.name =~ /^TweetStats/ and job.payload_object.userid == @userid and not job.failed?
        if job.locked_at
          user = User.find_by_userid @userid
          if user
            user.cancel = true
            user.save
            # Already running. Wait for job to cancel itself.
            redirect_to :action => :dashboard
            return
          end
        else
          job.destroy
        end
      end
    }

    # No job running for this user. We can simply reset the status.
    TweetStats::update_status @userid, 'ready', 0, ''
    redirect_to :action => :dashboard
  end

  def report
    @title = 'Report'

    userid = nil
    if params[:userid]
      userid = params[:userid]
    elsif session[:userid]
      userid = session[:userid]
    else
      redirect_to :action => :index
      return
    end

    user = User.find_by_userid userid

    unless user.report
      redirect_to :action => :dashboard
      return
    end
    report = JSON.parse user.report

    @by_month_data = report['by_month_data']
    @by_month_min = report['by_month_min']
    @by_month_max = report['by_month_max']
    @by_dow_data = report['by_dow_data']
    @by_hour_data = report['by_hour_data']
    @by_mention_data = report['by_mention_data']
    @by_source_data = report['by_source_data']
    @by_words_data = report['by_words_data']
    @subtitle = report['subtitle']

    render :template => 'twstat/report', :layout => false
  end
end
