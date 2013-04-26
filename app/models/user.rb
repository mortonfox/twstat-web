class User < ActiveRecord::Base
  attr_accessible :report, :status, :userid, :username

  def self.update_status params = {}
    userid     = params[:userid] or fail 'Error in User::update_status: userid not specified'
    status     = params[:status] || 'ready'
    tweetsDone = params[:tweetsDone] || 0
    untilDate  = params[:untilDate] || ''
    report     = params[:report]
    errorMsg   = params[:errorMsg]

    datestr = case untilDate
              when Time
                untilDate.strftime '%Y-%m-%d'
              else
                untilDate
              end

    user = find_by_userid userid
    user.status = {
      'status'     => status,
      'tweetsDone' => tweetsDone,
      'untilDate'  => datestr,
      'errorMsg'   => errorMsg,
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
