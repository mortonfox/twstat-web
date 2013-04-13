require 'tempfile'
require 'csv'
require 'zip/zipfilesystem'

def update_status userid, status, tweetsDone, untilDate, report=nil
  datestr = case untilDate
            when Time
              untilDate.strftime '%Y-%m-%d'
            else
              untilDate
            end

  user = User.find_by_userid userid
  user.status = {
    'status' => status,
    'tweetsDone' => tweetsDone,
    'untilDate' => datestr,
  }.to_json

  if report
    user.report = report
  end

  user.save
end

class TweetStats

  COUNT_DEFS = {
    :alltime => { :title => 'all time', :days => nil, },
    :last30 => { :title => 'last 30 days', :days => 30, },
  }

  MENTION_REGEX = /\B@([A-Za-z0-9_]+)/
  STRIP_A_TAG = /<a[^>]*>(.*)<\/a>/

  COMMON_WORDS = %w{
    the and you that 
    was for are with his they
    this have from one had word
    but not what all were when your can said
    there use each which she how their 
    will other about out many then them these 
    some her would make like him into time has look
    two more write see number way could people
    than first water been call who oil its now
    find long down day did get come made may part
    http com net org www https 
  }

  attr_reader :row_count

  def initialize userid, zipfile
    @userid = userid
    @zipfile = zipfile

    @count_by_month = {}

    @all_counts = {}
    COUNT_DEFS.keys.each { |period|
      @all_counts[period] = {
        :by_dow => {},
        :by_hour => {},
        :by_mention => {},
        :by_source => {},
        :by_word => {},
      }
    }

    @row_count = 0
    @newest_tstamp = nil
    @oldest_tstamp = nil
  end

  PROGRESS_INTERVAL = 100

  def process_row row
    @row_count += 1

    # Skip header row.
    return if @row_count <= 1

    # Skip malformed/short rows.
    return if row.size < 8

    _, _, _, _, _, tstamp_str, source_str, tweet_str, _ = row
    tstamp = Time.parse tstamp_str

    if @row_count % PROGRESS_INTERVAL == 0
      update_status @userid, 'busy', @row_count, tstamp
    end

    # Save the newest timestamp because any last N days stat refers to N
    # days prior to this timestamp, not the current time.
    unless @newest_tstamp
      @newest_tstamp = tstamp

      COUNT_DEFS.each { |period, periodinfo|
        periodinfo[:cutoff] = nil
        periodinfo[:cutoff] = @newest_tstamp - periodinfo[:days] * 24 * 60 * 60 if periodinfo[:days]
      }
    end

    # This assumes that tweets.csv is ordered from newest to oldest.
    @oldest_tstamp = tstamp

    mon_key = [ "%04d-%02d" % [ tstamp.year, tstamp.mon ], tstamp.year, tstamp.mon ]
    @count_by_month[mon_key] ||= 0
    @count_by_month[mon_key] += 1

    mentions = tweet_str.scan(MENTION_REGEX).map { |match| match[0].downcase }
    source = source_str.gsub(STRIP_A_TAG, '\1')

    # This is for Ruby 1.9 when reading from ZIP file.
    if tweet_str.respond_to? :force_encoding
      tweet_str.force_encoding 'utf-8'
    end

    # The gsub() converts Unicode right single quotes to ASCII single quotes.
    # This works in Ruby 1.8 as well.
    words = tweet_str.gsub(['2019'.to_i(16)].pack('U*'), "'").downcase.split(/[^a-z0-9_']+/).select { |word|
      word.size >= 3 and not COMMON_WORDS.include? word
    }

    COUNT_DEFS.each { |period, periodinfo|
      next if periodinfo[:cutoff] and tstamp < periodinfo[:cutoff]

      @all_counts[period][:by_hour][tstamp.hour] ||= 0
      @all_counts[period][:by_hour][tstamp.hour] += 1

      @all_counts[period][:by_dow][tstamp.wday] ||= 0
      @all_counts[period][:by_dow][tstamp.wday] += 1

      mentions.each { |user|
        @all_counts[period][:by_mention][user] ||= 0
        @all_counts[period][:by_mention][user] += 1
      }

      @all_counts[period][:by_source][source] ||= 0
      @all_counts[period][:by_source][source] += 1

      words.each { |word|
        @all_counts[period][:by_word][word] ||= 0
        @all_counts[period][:by_word][word] += 1
      }
    }
  end

  DOWNAMES = %w{ Sun Mon Tue Wed Thu Fri Sat }


  def make_tooltip category, count
    "<div class=\"tooltip\"><strong>#{category}</strong><br />#{count} tweets</div>"
  end

  def gen_report 
    report_data = {}

    months = @count_by_month.keys.sort { |a, b| a[0] <=> b[0] }
    report_data['by_month_data'] = months.map { |mon|
      "[new Date(#{mon[1]}, #{mon[2] - 1}), #{@count_by_month[mon]}, '#{make_tooltip mon[0], @count_by_month[mon]}']"
    }.join ','
    first_mon = Date.civil(months.first[1], months.first[2], 15) << 1
    last_mon = Date.civil(months.last[1], months.last[2], 15)
    report_data['by_month_min'] = [ first_mon.year, first_mon.mon - 1, first_mon.day ].join ','
    report_data['by_month_max'] = [ last_mon.year, last_mon.mon - 1, last_mon.day ].join ','

    by_dow_data = {}
    COUNT_DEFS.each { |period, periodinfo|
      by_dow_data[period] = 0.upto(6).map { |dow|
        "['#{DOWNAMES[dow]}', #{@all_counts[period][:by_dow][dow].to_i}, '#{make_tooltip DOWNAMES[dow], @all_counts[period][:by_dow][dow].to_i}']"
      }.join ','
    }
    report_data['by_dow_data'] = by_dow_data

    by_hour_data = {}
    COUNT_DEFS.each { |period, periodinfo|
      by_hour_data[period] = 0.upto(23).map { |hour|
        "[#{hour}, #{@all_counts[period][:by_hour][hour].to_i}, '#{make_tooltip "Hour #{hour}", @all_counts[period][:by_hour][hour].to_i}']"
      }.join ','
    }
    report_data['by_hour_data'] = by_hour_data

    by_mention_data = {}
    COUNT_DEFS.each { |period, periodinfo|
      by_mention_data[period] = @all_counts[period][:by_mention].keys.sort { |a, b| 
        @all_counts[period][:by_mention][b] <=> @all_counts[period][:by_mention][a] 
      }.first(10).map { |user|
        "[ '@#{user}', #{@all_counts[period][:by_mention][user]} ]"
      }.join ','
    }
    report_data['by_mention_data'] = by_mention_data

    by_source_data = {}
    COUNT_DEFS.each { |period, periodinfo|
      by_source_data[period] = @all_counts[period][:by_source].keys.sort { |a, b| 
        @all_counts[period][:by_source][b] <=> @all_counts[period][:by_source][a] 
      }.first(10).map { |source|
        "[ '#{source}', #{@all_counts[period][:by_source][source]} ]"
      }.join ','
    }
    report_data['by_source_data'] = by_source_data

    by_words_data = {}
    COUNT_DEFS.each { |period, periodinfo|
      by_words_data[period] = @all_counts[period][:by_word].keys.sort { |a, b| 
        @all_counts[period][:by_word][b] <=> @all_counts[period][:by_word][a] 
      }.first(100).map { |word|
        "{text: \"#{word}\", weight: #{@all_counts[period][:by_word][word]} }"
      }.join ','
    }
    report_data['by_words_data'] = by_words_data

    report_data['subtitle'] = "from #{@oldest_tstamp.strftime '%Y-%m-%d'} to #{@newest_tstamp.strftime '%Y-%m-%d'}"

    report_data.to_json
  end

  def process_zipfile 
    Zip::ZipFile.open(@zipfile.path) { |zipf|
      zipf.file.open('tweets.csv', 'r') { |f|

        # CSV module is different in Ruby 1.8.
        if CSV.const_defined? :Reader
          CSV::Reader.parse(f) { |row|
            process_row row
          }
        else
          CSV.parse(f) { |row|
            process_row row
          }
        end
      }
    }

    report = gen_report
    update_status @userid, 'ready', 0, '', report
  end
end


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

    @user = User.find_by_userid(session[:userid])

    @user_status = if @user.status
                     JSON.parse @user.status
                   else
                     { 'status' => 'ready', 'tweetsDone' => 0, 'untilDate' => '' }
                   end
    $stderr.puts @user_status
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

    update_status session[:userid], 'busy', 0, ''

    @twstat = TweetStats.new session[:userid], @uploadtemp
    @twstat.process_zipfile 

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
