---
title: Rake Tasks 101
publishDate: 2010-06-06
---

I've been working with Rake quite a bit on my current project so I
thought I'd share some beginner tips.

Before I go into Rake, what is it? Rake is a Ruby-based build program.
Ruby on Rails uses Rake quite a bit in it's process. If you've worked on
a Rails project you'll used one, some or all of the following: rake
db:create, rake gems:unpack, rake db:migrate, and  rake test. Now that's
not all of Rail's Rake tasks, just some common ones.

You're here to make your own Rake tasks so lets get started!

<!-- more -->

## Make Your Task

Rake files can live within plugins or in your `Rails.root/lib/tasks`
directory. In this post I'll be referencing the latter. Let's create our
new rake file: `Rails.root/lib/tasks/manners.rake`

Next we can declare our Rake task in the manners.rake file:

```
namespace :manners do
  desc 'the description of what my rake task will do'
  task :greet do
    puts 'Hello from Rake'
  end
end
```

After thats done we should be able to execute our new task at the
command-line with `rake manners:greet`.

## Task Variables

Let's make the Rake task reusable. To do this we'll pass in some
variables. Rewrite the task block of the manners.rake file like this:

```
task :greet, :name do |cmd, args|
  puts "command: #{cmd}"
  puts "args: #{args.inspect}"
end
```

The output you receive from running the task again should look like
this:

```
command: manners:greet
args: {}
```

Now run the task again, but define the variable by calling it like this,
`rake manners:greet[Dane]`. That should yield:

```
command: manners:greet
args: {:name => "Dane"}
```

This is where Rake tasks get interesting. Rake always passes in the
command run into the task block as the first variable, thats why we see
"command: manners:greet."  The second variable defines the hash that
will contain all the variables passed into the the Rake task. The args
hash index is any symbol that follows the task name symbol. We set
`:greet` as the task name so :name becomes an available index in the args
hash.

Lets rework the `:greet` task a little bit by defining our variables as
`:first_name` and `:last_name`.

```
task :greet, :first_name, :last_name do |cmd, args|
  puts "Good day #{args[:first_name]} #{args[:last_name]}"
end
```

Run the Rake task and define both variables, `rake
manners:greet[Dane,Harrigan]`.

Spaces are not allowed when passing variables into a Rake task when
calling it at the command-line. This is why its written as
`[Dane,Harrigan]` and not `[Dane, Harrigan]`. Quotes can be used if
spaces are necessary to a variable for example, `rake manners:greet['Mr.
Dane',Harrigan]`.

## Rake Dependencies

We've built a Rake task so now lets make another and have it depend on
`manners:greet`. Add a `manners:question` task that asks, "How are you?"
Start by just making a Rake task like we did with `manners:greet`. To
make the `:question` task dependent on `:greet` define the task as `task
:question => 'manners:greet'`. Our `manners.rake` file should look like
this:

```
namespace :manners do
  desc 'Greet the Rake user'
  task :greet, :first_name, :last_name do |cmd, args|
    puts "Good day #{args[:first_name]} #{args[:last_name]}"
  end

  desc 'Ask a question'
  task :question => 'manners:greet' do
    puts 'How are you doing?'
  end
end
```

If we run rake `manners:question` you'll see that it greets us with,
"Good day," and, "How are you doing?" but we can't set variables in a
task dependency when its declared this way. Defining the dependency this
way doesn't work either, `task :question =>
'manners:greet[Dane,Harrigan]'`. Let's remove the 'manners:greet'
dependency and call `invoke` on it instead.

```
task :question do
  Rake::Tasks['manners:greet'].invoke('Dane','Harrigan')
  puts 'How are you doing?'
end
```

Now when we run the task you'll see a greeting to Dane and the question.

## Tasks Run Once

When calling a task with `invoke` or `execute` Rake keeps track of
whether or not it has already run. If the task has run already it wont
run a second time. If we did the following you'll only see one greeting.

```
task :question do
  Rake::Task['manners:greet'].invoke('Dane','Harrigan')
  Rake::Task['manners:greet'].invoke('John','Smith')
  puts 'How are you doing?'
end
```

You won't see the greeting to John Smith. Well that's rude, but we can
fix this easily. If you want to call the task multiple times you'll need
to `reenable` the task each time before calling it. You can `reenable` a
task anywhere, but I've found it makes the most sense to call `reenable`
at the end of the task block of the one being reenabled. In our example
we'll call `reenable` inside of task `:greet`.

```
task :greet, :first_name, :last_name do |cmd, args|
  puts "Good day #{args[:first_name]} #{args[:last_name]}"
  Rake::Task['manners:greet'].reenable
end
```

Now if we call `rake manners:question` we'll see both greetings.
Perfect!

## And We're Done

Rake is a very nice piece of software and I encourage others to read up
on it. I hope this  post gave you enough understanding to start writing
your own tasks. Also, please do comment if there are questions or other
areas of Rake you'd like to know about. A Rake Tasks 102 post perhaps?

[Rake Tasks 102 is up!][1] If
you liked Rake Tasks 101, I think you'll enjoy 102 just as much.

[1]: /articles/rake-tasks-102
