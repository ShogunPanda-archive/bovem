# bovem

[![Gem Version](https://badge.fury.io/rb/bovem.png)](http://badge.fury.io/rb/bovem)
[![Dependency Status](https://gemnasium.com/ShogunPanda/bovem.png?travis)](https://gemnasium.com/ShogunPanda/bovem)
[![Build Status](https://secure.travis-ci.org/ShogunPanda/bovem.png?branch=master)](http://travis-ci.org/ShogunPanda/bovem)
[![Code Climate](https://codeclimate.com/github/ShogunPanda/bovem.png)](https://codeclimate.com/github/ShogunPanda/bovem)
[![Coverage Status](https://coveralls.io/repos/ShogunPanda/bovem/badge.png)](https://coveralls.io/r/ShogunPanda/bovem)
[![Bitdeli Trend](https://d2weczhvl823v0.cloudfront.net/ShogunPanda/bovem/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

A command line manager and a collection of utilities for developers.

http://sw.cowtech.it/bovem

http://rdoc.info/gems/bovem

## Description

Bovem is a command line manager and small set of utilities for Ruby developers.

See the documentation for more informations.

## Basic usage

As ever, talking by example is always better.
This application:

```ruby
require "bovem"

Bovem::Application.create(name: "Bovem Usage Test", version: "1.0.0", description: "An example modelled like a TODO application", banner: "Do you like Bovem?") do
  option(:storage, ["f", "file"], {type: String, help: "The file where store TODOs to.", meta: "FILE"})

  command :list do
    description "List all TODOs."
    action do |command|
      # You should implement this.
    end
  end

  command :manage, {description: "Manage existing TODO."} do
    option(:verbose, [], {help: "Be verbose."})

    action do |command|
      puts "Please use \"add\" or \"remove\" subcommands."
    end

    command :add, {description: "Add a TODO."} do
      action do |command|
        # You should implement this.
      end
    end

    command :remove, {description: "Removes a TODO."} do
      action do |command|
        # You should implement this.
      end
    end
  end
end
```

Will create a complete (at least at the interface model) TODO application which support commands `list` and `manage`.

The `manage` command supports subcommands `add` and `remove`. You can invoke it via syntax `manage add` or `manage:add`. **If there is no conflict, just `m:r` is sufficient!**

To provide (sub)commands, both hash-style or block-style method style are supported (except for the `action` option), as you can see in the example.

You can use the `--help` switch or the `help command` syntax to navigate through commands details.

After setting up the skeleton, you will just need to write the action bodies and you're done. **Happy coding!**

### Wrapping up the example
Here's the help screen of the application above for the global application and for the `manage` command.

#### General help

```
$ ./test -h
[NAME]
    Bovem Usage Test 1.0.0 - An example modelled like a TODO application

[SYNOPSIS]
    test [options] [command [subcommand ...]][command-options] [arguments]

[DESCRIPTION]
    Do you like Bovem?

[GLOBAL OPTIONS]
    -f FILE, --file FILE - The file where store TODOs to.
    -h, --help           - Shows this message.

[COMMANDS]
    help   - Shows a help about a command.
    list   - List all TODOs.
    manage - Manage existing TODO.
```

#### The `manage` command help

```
$ ./test help manage
[SYNOPSIS]
    test [options] manage [subcommand ...]] [command-options] [arguments]

[OPTIONS]
    -v, --verbose - Be verbose.

[SUBCOMMANDS]
    add    - Add a TODO.
    remove - Removes a TODO.
```


## Advanced usage

See documentation for more information.

## Contributing to bovem

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (C) 2013 and above Shogun (shogun@cowtech.it).

Licensed under the MIT license, which can be found at [http://www.opensource.org/licenses/mit-license.php](http://www.opensource.org/licenses/mit-license.php).
