require 'tempfile'
require 'tweet_stats'

class TwstatController < ApplicationController

  CONSUMER_KEY = 'kENAx1tEBxoalX9e7dMuw'
  CONSUMER_SECRET = 'A7XNOF3XWpyAdILj0k5IPuUWeCwV6AKiEvzkFuPFE'

  def initialize
    super
    @COUNT_DEFS = TweetStats::COUNT_DEFS
  end

  def index
    if session[:userid]
      redirect_to :action => :dashboard
      return
    end
  end

  def login
    oauth = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET,
                                { :site => "https://api.twitter.com" })
    callback_url = 'http://127.0.0.1:3000/twstat/oauth'
    request_token = oauth.get_request_token(:oauth_callback => callback_url)

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

    oauth = OAuth::Consumer.new(CONSUMER_KEY, CONSUMER_SECRET,
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
    unless session[:userid]
      redirect_to :action => :index
      return
    end

    @userid = session[:userid]
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
    logger.info @user_status.to_s
    @do_refresh = @user_status['status'] == 'busy'
  end

  def upload
    unless session[:userid]
      redirect_to :action => :index
      return
    end

    uploaded_file = params[:tweetdata]
    @uploadtemp = Tempfile.new ['tweetdata', '.zip'], :encoding => 'ascii-8bit'
    @uploadtemp.write uploaded_file.read
    @uploadtemp.close

    TweetStats::update_status session[:userid], 'busy', 0, ''
    TweetStats.new(session[:userid], @uploadtemp.path).delay.run

    redirect_to :action => :dashboard
  end


  def report
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
