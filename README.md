# Cron Expression Parser

A command line application which accepts a cron string and expands each field to describe when the schedule will run.

## Requirements

[Ruby](https://www.ruby-lang.org/) 3.1.0 (tested with ruby 3.1.0p0 (2021-12-25 revision fb4df44d16) \[x86_64-darwin19])

## Running the code

After extracting the solution run bundler to install all the dependencies.

```
bundle install
```

To execute the program you can pass a cron string into the `bin/cronparser` executable. 

If you are using a shell such as zsh you will need to disable glob expansion (`set -o noglob`) before running the command or enclose the cron string within quotes. 

The application can support both integer and string literal values (e.g. 3,4 or TUE,WED).

```
bin/cronparser "*/15 0 1,15 * 1-5 /usr/bin/find"
```

or

```
set -o noglob
bin/cronparser */15 0 1,15 * 1-5 /usr/bin/find
```

or

```
ruby bin/cronparser "*/15 0 1,15 * 1-5 /usr/bin/find"
```

Example output:

```
minute         0 15 30 45
hour           0
day_of_month   1 15
month          1 2 3 4 5 6 7 8 9 10 11 12
day_of_week    1 2 3 4 5
command        /usr/bin/find
```

## Running tests

The solution uses [RSpec](https://rspec.info) to test the functionality and guard to run the tests in real time while developing.

```
rspec spec
```

or

```
bundle exec guard
```

Test cases:

```
CronParser
  When parsing a string it extracts
    the command
    the minute
    the hour
    the day of month
    the month
    the day of week
  When parsing a value
    it should return the full range of values for a wildcard (e.g. 1..12)
    it should return 'Unused' for an optional value
    for a range
      it should return a subset of values for a numeric range (e.g. 15-20)
      it should return a subset of values for a string range (e.g. TUE-FRI)
      that is invalid (e.g. TUE-BOB)
        it should not populate the field
        it should flag the model as invalid
        it should populate an error message for the problem
    for a step interval
      should return steps matching the interval with a wildcard
      should start at a given value and return intervals from that point
      should start at a given string value and return string intervals from that point (e.g. TUE/2)
      should validate that the starting point is within the range
    for a list
      should return only the values in the list
      should allow string values in the list
    for a literal value
      should return the value
      should ensure that the value is within a valid range
      should allow string based values
```
