require 'tweet_stats'
$stderr.puts 'Setting destroy_failed_jobs to false...'
Delayed::Worker.destroy_failed_jobs = false
