# twstat-web - Online Twitter stats generator

> Warning: This software package is still under development. If you use it, be
> prepared to wipe it out and reinstall from scratch because of incompatible
> design changes.

## Introduction

This is a Rails web interface wrapper around
[twstat](https://github.com/mortonfox/twstat), a script that generates a page
of charts from a Twitter archive.

### Twitter archive

In December 2012, Twitter
[introduced](http://blog.twitter.com/2012/12/your-twitter-archive.html) a
feature allowing users to download an archive of their entire user timeline. By
February 2013, it was available to all users.

To request your Twitter archive:

1. Visit https://twitter.com/settings/account
1. Click on the "Request your archive" button. (near the bottom of the settings page)
1. Wait for an email from Twitter with a download link.

## Installation

Download the file tree and deploy it as a Rails application. This step depends
on your web hosting setup.

By default, twstat-web uses SQLite for the database backend. Edit
`config/database.yml` if you wish to use a different database server.

Sign up for a Twitter API key at https://apps.twitter.com/ and add it to the
production section in `config/apikeys.yml`. You may also add a development API
key here if you are installing another copy for testing.

Run the following in the root of the file tree:

* `bundle install`
* `RAILS_ENV=production rake db:migrate`
* `RAILS_ENV=production script/delayed_job start`
* `rails server -e production`

The delayed\_job startup command should be placed in bootup actions or
equivalent at your web host.

The rails server startup command may also differ or be eliminated entirely
depending on your web hosting setup.

## Demo

There is a live demo at http://qslv.com/twstat
