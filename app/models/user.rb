# user record in database.
class User < ActiveRecord::Base
  attr_accessible :report, :status, :userid, :username

  def self.update_status params = {}
    userid     = params[:userid] or fail 'Error in User::update_status: userid not specified'
    status     = params[:status] || 'ready'
    tweets_done = params[:tweets_done] || 0
    until_date  = params[:until_date] || ''
    report     = params[:report]
    error_msg   = params[:error_msg]

    datestr = case until_date
              when Time
                until_date.strftime '%Y-%m-%d'
              else
                until_date
              end

    user = find_by_userid userid
    user.status = {
      'status'     => status,
      'tweetsDone' => tweets_done,
      'untilDate'  => datestr,
      'errorMsg'   => error_msg,
    }.to_json

    if status == 'waiting'
      # All new jobs start in non-cancel state.
      user.cancel = false
    end

    if report
      user.report = report
      user.last_generated = Time.now
    end

    user.save
    user
  end
end
