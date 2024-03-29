---
title: "Rake Tasks 102"
publishDate: 2010-06-21
---

This is a follow up post to [Rake Tasks 101][1]. In the 101 post we
created Rake tasks, setup dependencies and made our tasks reusable by
passing in parameters. In Rake Tasks 102 we'll be building on those
practices, interfacing with a Rails environment and leveraging the cron
to automate our Rake task.

<!-- more -->

Our tasks will search Twitter for any mentions of "daneharrigan" and add
the most recent to our Tweet model. In this article I'm making a few
assumptions. You're on a Linux/Unix-based machine. You have [John
Nunemaker's Twitter gem][2] installed in
your Rails project. Lastly, your `Tweet` model was built with one of the
two commands:

```
# rails 2
$ script/generate model Tweet username:string message:string tweeted_at:datetime

# rails 3
$ rails generate model Tweet username:string message:string tweeted_at:datetime
```

## Task Setup

Let's create our Rake file as `Rails.root/libs/tasks/twitter.rake` and
get started. First we'll make a reusable task called `:search` in the
`:twitter` namespace. This task will search Twitter for whatever
parameter we pass it. Next, we'll make a task called `:daneharrigan`.
This task will live in a `:search` namespace, nested in the `:twitter`
namespace. You'll notice that we're nesting namespaces because this
wasn't covered in the 101 post.

```
namespace :twitter do
  desc 'Search Twitter for the parameter you pass in'
  task :search, :query do |cmd, args|
    # some very impressive search code...
    Rake::Task['twitter:search'].reenable
  end

  namespace :search do
    desc 'Search Twitter for "@daneharrigan" and save it in the database'
    task :daneharrigan => :search do
      # save results from :search and be happy
    end
  end
end
```

## Instance Variables in Tasks

Why would we ever want to use instance variables in a Rake task? The
same reason you use an instance variable in a Ruby class. You want to
make certain data available to multiple areas of your code. Instance
variables in Rake tasks are no different, but that instance variable
will be available to any other task run at that time. For example, if we
set `@name` equal to "Dane" in the `:search` task, we can do puts
`@name` in the `:daneharrigan` task and see the `@name` output when
running `rake twitter:search:daneharrigan`. That makes things really
easy, but you run the risk of overwriting instance variables from other
higher level tasks.

I took a look through the Rake tasks that come with Rails 3 and I didn't
see anything that we could conflict with. I'll digress for just a moment
and say the "rails:update" task does set the `@app_generator` instance
variable so that is a potential conflict, but I can't think of a
scenario where you'd need to set "rails:update" as a dependency to any
new task. Please share your scenario if you have one!

Instance variables look safe enough, but I think we could do better. How
about storing our data in an object?. This sounds a lot safer than using
instance variables.

## Objects in Tasks

You can create your class file in `Rails.root/lib` or
`Rails.root/app/model`. Either location will yield identical results for
what we're doing. As your code changes pick whichever location makes the
most sense to you. The following is a our object that will store our
data between Rake tasks:

```
class TwitterStore
  def self.search(query)
    @results = Twitter::Search.new(query)
  end

  def self.latest_result
    @results.first
  end
end
```

The `TwitterStore` object has only a search method and a results method.
You can certainly get more fancy at this step or even use an
`ActiveRecord` model instead so feel free to use your creative license.

We have our object and we have our task, but at this point Rake is
unaware of any object or model in Rails --- that includes our nifty
`TwitterStore`. Rails comes with a handy `:environment` task that sets
up this awareness. We just need to set `:environment` as a task
dependency or invoke it within the task. For us, we'll be choosing the
latter.

```
namespace :twitter do
  desc 'Search Twitter for the parameter you pass in'
  task :search, :query do |cmd, args|
    Rake::Task[:environment].invoke
    # Rake is now aware of our Rails environment!
    TwitterStore.search args[:query]
  end
  # ...
end
```

## Putting the Pieces Together

You can see we're putting the pieces together now. We setup the Rails
environment within our task, called `TwitterStore.search` and passed
`args[:query]` to the search method. Now for the `:daneharrigan` task.

```
task :daneharrigan do
  Rake::Task[:search].invoke('daneharrigan')
  result = TwitterStore.latest_result
  params = {
    :username => result[:from_user],
    :message => result[:text],
    :tweeted_at => result[:created_at].to_datetime
  }
  Tweet.find_or_create_by_username_and_message_and_tweeted_at(params)
end
```

In the `:search` task we called `TwitterStore.search` which makes the
response available to the `:daneharrigan` task through the
`latest_result` method. I decided to use the `find_or_create_by` method
because it's easy enough to show that we don't store the same tweet more
than once.

Our tasks are complete, let's give it a try, `rake
twitter:search:daneharrigan`, then check your `Tweet` model to see what
data is populated.

## Cron Jobs

if you aren't familiar with the cron or a cron job I recommend reading
over [Wikipedia's page][3] on it.

Time to setup our cron job! Before we can start we need to know what the
cron job does, where does the cron have to be on the system to run
properly and how often does it run. After we answer those questions we
put them all together.

When you're answering "what cron job does" make sure to always use full
paths to your executable files. The cron doesn't have the `$PATH`
environmental variable set so it needs to know exactly where files live.
For example, write `/usr/bin/rake twitter:search:daneharrigan` opposed
to `rake twitter:search:daneharrigan`.

Now "where does the cron have to be in the system to run properly?" We
know we want to run our Rake task, but that can't be run from just
anywhere. It needs to run from within our Rails project directory. Let's
say `/home/dane/twitter_store`.

Finally, "how often does it run?" How about every 5 minutes? That's
reflected in the cron as `*/5 * * * *`.

We've answered all 3 questions so let's put them together.

```
*/5 * * * * cd /home/dane/twitter_store && /usr/bin/rake
twitter:search:daneharrigan
```

You know how a cron entry should look, but how do you actually _add_ an
entry to the cron? Run `crontab -e` from the command-line. This will
launch the system's default editor or whatever you have set in
`$EDITOR`. Fill out your entry there, save it and you're set!

## And We're Done

We created our Rake tasks, made them aware of the Rails environment,
passed data between tasks through a storage class and added an entry to
our cron to run every 5 minutes. We're done! I hope this post gave you
additional understanding to enhance your own tasks. Please do comment if
there are questions or other areas of Rake you'd like to know about.

I'd like to thank Gokul Janga and Stuart Ellis for suggesting these
topics from the [Rake Tasks 101][1] comments, thanks guys!

[1]: /articles/rake-tasks-101
[2]: http://rubygems.org/gems/twitter
[3]: http://en.wikipedia.org/wiki/Cron
