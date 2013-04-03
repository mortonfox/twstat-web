class User < ActiveRecord::Base
  attr_accessible :report, :status, :userid, :username
end
