require 'tweet_stats'
Rails.logger.info 'Setting destroy_failed_jobs to false...'
Delayed::Worker.destroy_failed_jobs = false
