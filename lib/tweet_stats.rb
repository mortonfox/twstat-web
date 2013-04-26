require 'csv'
require 'zip/zipfilesystem'
require 'tempfile'

class CanceledException < RuntimeError
end

class TweetStats < Struct.new(:userid, :zipfile)

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

  def init
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

  PROGRESS_INTERVAL = 300

  def process_row row
    @row_count += 1

    # Skip header row.
    return if @row_count <= 1

    # Skip malformed/short rows.
    return if row.size < 8

    _, _, _, _, _, tstamp_str, source_str, tweet_str, _ = row
    tstamp = Time.parse tstamp_str

    if @row_count % PROGRESS_INTERVAL == 0
      user = User.update_status :userid => userid, :status => 'busy', :tweetsDone => @row_count, :untilDate => tstamp
      if user.cancel
        # User requested job cancel.
        User.update_status :userid => userid, :status => 'ready'
        raise CanceledException
      end
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
    Zip::ZipFile.open(zipfile) { |zipf|
      zipf.file.open('tweets.csv', 'r') { |f|

        # Save tweets.csv to tempfile because Ruby 1.9 CSV needs to be able
        # to move the file pointer in the IO Stream. Ruby 2.0 CSV got rid
        # of that requirement.
        tempfile = Tempfile.new ['tweetdata', '.csv'], :encoding => 'ascii-8bit'
        tempfile.write f.read
        tempfile.rewind

        # CSV module is different in Ruby 1.8.
        if CSV.const_defined? :Reader
          CSV::Reader.parse(tempfile) { |row|
            process_row row
          }
        else
          CSV.parse(tempfile) { |row|
            process_row row
          }
        end

        tempfile.close
      }
    }

    report = gen_report
    User.update_status :userid => userid, :status => 'ready', :report => report
  end

  def run
    Rails.logger.info "Running TweetStats::run... (user: #{userid} file: #{zipfile})"
    init
    process_zipfile
    Rails.logger.info "Finished TweetStats::run. (user: #{userid} file: #{zipfile})"
  rescue CanceledException
    Rails.logger.info "Canceled TweetStats::run. (user: #{userid} file: #{zipfile})"
  rescue Exception => e
    errormsg = "Error in TweetStats::run: #{e}"
    Rails.logger.error errormsg
    Rails.logger.error e.backtrace.join("\n")

    User.update_status :userid => userid, :status => 'error', :errorMsg => errormsg
  end
end

