# trainmaster

[![Build Status](https://travis-ci.org/davidan1981/trainmaster.svg?branch=master)](https://travis-ci.org/davidan1981/trainmaster)
[![Coverage Status](https://coveralls.io/repos/github/davidan1981/trainmaster/badge.svg?branch=master)](https://coveralls.io/github/davidan1981/trainmaster?branch=master)
[![Code Climate](https://codeclimate.com/github/davidan1981/trainmaster/badges/gpa.svg)](https://codeclimate.com/github/davidan1981/trainmaster)
[![Gem Version](https://badge.fury.io/rb/trainmaster.svg)](https://badge.fury.io/rb/trainmaster)

trainmaster is a Rails engine that provides
a [JWT](https://jwt.io/)-based session management platform for API
development. This plugin is suitable for developing RESTful APIs that do
not require an enterprise identity service. No cookies or non-unique IDs
involved in this project.

It is a continuation of
[rails-identity](https://github.com/davidan1981/rails-identity) which has
been deprecated due to backwards compatibility issues.

This documentation uses [httpie](https://github.zom/) (rather than curl)
to demonstrate making HTTP requests from the command line.

## Features

* Mountable Rails engine
* JWT-based session management API (REST)
* API key based authentication
* Email verification workflow
* Password reset workflow
* Caching
* OAuth authentication (beta)

## Install

Install the gem, or
go to your app's directory and add this line to your `Gemfile`:

```ruby
gem 'trainmaster'
```

Then, add the following line in `application.rb`:

```ruby
require 'trainmaster'
```

And the following in `route.rb`:

```ruby
require 'trainmaster'

Rails.application.routes.draw do
  mount Trainmaster::Engine, at: "/"
end
```

Note that you may designate a different target prefix other than the root.
Then, run `bundle install` and do `rake routes` to verify the routes.

Next, install migrations from trainmaster and perform migrations:

    $ bundle exec rake trainmaster:install:migrations
    $ bundle exec rake db:migrate RAILS_ENV=development

FYI, to see all `rake` tasks, do the following:

    $ bundle exec rake --tasks

### Other Plugins

trainmaster uses ActiveJob to perform tasks asynchronously, which
requires a back-end module. For example, you can use
[DelayedJob](https://github.com/collectiveidea/delayed_job) by adding the
following in Gemfile.

```ruby
gem 'delayed_job_active_record'
gem 'daemons'
```
    
Also, email service must be specified in your app for sending out
email verification token and password reset token. Note that the 
default email template is not sufficient for real use. 
You must define your own mailer action views to cater emails for 
your need.

To use OAuth, you must configure two endpoints. First, specify
`oauth_landing_page_url` to the URL that will assign token (from query
string) to a temporary storage such as cookie.

    config.oauth_landing_page_url = '/oauth_success'

Once OAuth callback is successful, the controller will response a redirect
(302) to the URL specified above with `token=<actual token>` as a query
string.

Second, set a route for oauth failure.

    get 'auth/failure', redirect_to('/oauth_failure')

This page should simply display failed authentication.


### Other Changes

`Trainmaster::User` model is a STI model. It means your app can inherit
from `Trainmaster::User` with additional attributes. All data will be
stored in `trainmaster_users` table. This is particularly useful if you
want to extend the model to meet your needs.

```ruby
class User < Trainmaster::User
  # more validations, attributes, methods, ...
end
```

### Running Your App

Now you're ready. Run the server to test:

    $ bundle exec rails server

To allow DelayedJob tasks to run, do

    $ RAILS_ENV=development bin/delayed_job start

## Usage

### Create User

Make a POST request on `/users` with `email`, `password`, and
`password_confirmation` in the JSON payload.

    $ http POST localhost:3000/users email=foo@example.com password="supersecret" password_confirmation="supersecret"

The response should be 201 if successful.

    HTTP/1.1 201 Created
    {
        "created_at": "2016-04-05T02:02:11.410Z",
        "deleted_at": null,
        "metadata": null,
        "role": 10,
        "updated_at": "2016-04-05T02:02:11.410Z",
        "username": "foo@example.com",
        "uuid": "68ddbb3a-fad2-11e5-8fc3-6c4008a6fa2a",
        "verified": false
    }
    
This request will send an email verification token to the user's email.
The app should craft the linked page to use the verification token to
start a session and set `verified` to true by the following:

    http PATCH localhost:3000/users/current verified=true token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOm51bGwsInNlc3Npb25fdXVpZCI6IjU5YTQwODRjLTAwNWMtMTFlNi1hN2ExLTZjNDAwOGE2ZmEyYSIsInJvbGUiOm51bGwsImlhdCI6MTQ2MDQzMDczMiwiZXhwIjoxNDYwNDM0MzMyfQ.rdi5JT5NzI9iuXjWfhXjYhc0xF-aoVAaAPWepgSUaH0
    
Note that `current` can be used when UUID is unknown but the token is
specified.  Also note that, if user's `verified` is `false`, some endpoints
will reject the request.

### Create Session

A proper way to create a session is to use username and password:

    $ http POST localhost:3000/sessions username=foo@example.com password=supersecret

    HTTP/1.1 201 Created
    {
        "created_at": "2016-04-05T02:04:22.465Z",
        "metadata": null,
        "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOiI2OGRkYmIzYS1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJzZXNzaW9uX3V1aWQiOiJiNmZhZGJhNC1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJyb2xlIjoxMCwiaWF0IjoxNDU5ODIxODYyLCJleHAiOjE0NjEwMzE0NjJ9.B9Ld00JvHUZT37THrwFrHzUwxIx6s3UFPbVCCwYzRrQ",
        "updated_at": "2016-04-05T02:04:22.465Z",
        "user_uuid": "68ddbb3a-fad2-11e5-8fc3-6c4008a6fa2a",
        "uuid": "b6fadba4-fad2-11e5-8fc3-6c4008a6fa2a"
    }

Notice this is essentially a login process for single-page apps. The client
app should store the value of `token` in either `localStore` or `cookie`.
(To allow cross-domain, you may want to use `cookie`.)

### Delete Session

A session can be deleted via a DELETE method. This is essentially a logout
process.

    $ http DELETE localhost:3000/sessions/b6fadba4-fad2-11e5-8fc3-6c4008a6fa2a token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOiI2OGRkYmIzYS1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJzZXNzaW9uX3V1aWQiOiJiNmZhZGJhNC1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJyb2xlIjoxMCwiaWF0IjoxNDU5ODIxODYyLCJleHAiOjE0NjEwMzE0NjJ9.B9Ld00JvHUZT37THrwFrHzUwxIx6s3UFPbVCCwYzRrQ

    HTTP/1.1 204 No Content

Make sure to remove the token from its storage. The old tokens will no
longer work.

### Password Reset

Since trainmaster is a RESTful service itself, password reset is done via
a PATCH method on the user resource. But you must specify either the old
password or a reset token. To use the old password:

    $ http PATCH localhost:3000/users/68ddbb3a-fad2-11e5-8fc3-6c4008a6fa2a old_password="supersecret" password="reallysecret" password_confirmation="reallysecret" token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOiI2OGRkYmIzYS1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJzZXNzaW9uX3V1aWQiOiJiNmZhZGJhNC1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJyb2xlIjoxMCwiaWF0IjoxNDU5ODIxODYyLCJleHAiOjE0NjEwMzE0NjJ9.B9Ld00JvHUZT37THrwFrHzUwxIx6s3UFPbVCCwYzRrQ

To use a reset token, you must issue one first:

    $ http PATCH localhost:3000/users/current username=foo@example.com issue_reset_token=true

    HTTP/1.1 204 No Content

User token will be sent to the user's email. In a real application, the email
would include a link to a _page_ with JavaScript code automatically making a
PATCH request to `/users/current?token=<reset_token>`.

Note that the response includes a JWT token that looks similar to a normal
session token. Well a surprise! It _is_ a session token but with a shorter life span (1
hour). So use it instead on the password reset request:

    http PATCH localhost:3000/users/current password="reallysecret" password_confirmation="reallysecret" token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOiI2OGRkYmIzYS1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJzZXNzaW9uX3V1aWQiOiIzYjI5ZGI4OC1mYjlhLTExZTUtODNhOC02YzQwMDhhNmZhMmEiLCJyb2xlIjoxMCwiaWF0IjoxNDU5OTA3NTU0LCJleHAiOjE0NTk5MTExNTR9.g4iosqm8dOVUL5ErtCggsNAOs4WQV2u-heAUPf145jg

    HTTP/1.1 200 OK
    {
        "created_at": "2016-04-05T02:02:11.410Z",
        "deleted_at": null,
        "metadata": null,
        "reset_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOiI2OGRkYmIzYS1mYWQyLTExZTUtOGZjMy02YzQwMDhhNmZhMmEiLCJzZXNzaW9uX3V1aWQiOiIzYjI5ZGI4OC1mYjlhLTExZTUtODNhOC02YzQwMDhhNmZhMmEiLCJyb2xlIjoxMCwiaWF0IjoxNDU5OTA3NTU0LCJleHAiOjE0NTk5MTExNTR9.g4iosqm8dOVUL5ErtCggsNAOs4WQV2u-heAUPf145jg",
        "role": 10,
        "updated_at": "2016-04-06T01:55:45.163Z",
        "username": "foo@example.com",
        "uuid": "68ddbb3a-fad2-11e5-8fc3-6c4008a6fa2a",
        "verification_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX3V1aWQiOm51bGwsInNlc3Npb25fdXVpZCI6IjU5YTQwODRjLTAwNWMtMTFlNi1hN2ExLTZjNDAwOGE2ZmEyYSIsInJvbGUiOm51bGwsImlhdCI6MTQ2MDQzMDczMiwiZXhwIjoxNDYwNDM0MzMyfQ.rdi5JT5NzI9iuXjWfhXjYhc0xF-aoVAaAPWepgSUaH0",
        "verified": true
    }

The token used with the request _must_ match the reset token previously 
issued for the user.

### Authentication and Authorization

There are two ways to do general authentication: token or API key.

To authorize a request to an action, use provided callbacks. trainmaster
provides three controller callbacks for each approach:

* Token
    * `require_token`
    * `require_admin_token`
    * `accept_token` - If a token is given, trainmaster will validate it.
* API key
    * `require_api_key`
    * `require_admin_api_key`
    * `accept_api_key`  - If an API key is given, trainmaster will validate it.
* Both
    * `require_auth` - A token or an API key must be given.
    * `require_admin_auth` - A token or an API key of an admin must be given.
    * `accept_auth` - If either a token or an API key is given, trainmaster will validate it

To determine if the authenticated user has access to a specific resource
object, use `authorized?`. An example of a resource authorization callback
looks like the following:

```ruby
def authorize_user_to_obj(obj)
  unless authorized?(obj)
    raise Repia::Errors::Unauthorized
  end
end
```

### Other Notes

#### Instance Variables

`ApplicationHelper` module will define the following instance variables:

* `@auth_user` - the authenticated user object
* `@auth_session` - the authenticated session
* `@token` - the token that authenticated the current session
* `@user` - the context user, only available if `get_user` is called 

Try not to overload these variables. You may use these variables to enforce
further access control. Note that `@auth_session` and `@token` will be
populated only if a token is used to authenticate.

#### Roles

For convenience, trainmaster pre-defined four roles:

* Owner (1000) - the owner of the app
* Admin (100) - the admin(s) of the app
* User (10) - the user(s) of the app
* Public (0) - the rest of the world
