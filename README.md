# ERB::Formatter 🪜

Format ERB files with speed and precision.

Features:

- very fast
- attempts to limit length (configurable)
- tries to have an ouput similar to prettier for HTML
- indents correctly ruby blocks (e.g. `if`/`elsif`/`do`/`end`)
- designed to be integrated into editors and commit hooks
- gives meaningful output in case of errors (most of the time)
- will use multiline values for `class` and `data-action` attributes

Roadmap:

- extensive unit testing
- more configuration options
- more ruby reformatting capabilities
- JavaScript and CSS formatting
- VSCode plugin

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'erb-formatter'
gem 'rufo' # for enabling minimal ruby re-formatting
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install erb-formatter

## Usage

### From the command line

    $ echo "<div       > asdf  <% if 123%> <%='foobar'%> <%end-%>  </div>" | erb-format --stdin
    <div>
      asdf
      <% if 123 %>
        <%= 'foobar' %>
      <% end -%>
    </div>


Check out `erb-format --help` for more options.

### From Ruby

```ruby
require 'erb/formatter'

formatted = ERB::Formatter.format <<-ERB
<div        >
            asdf
                  <% if 123%>
                      <%='foobar'%> <%end-%>
           </div>
ERB

# => "<div>\n  asdf\n  <% if 123 %>\n    <%= 'foobar' %>\n  <% end -%>\n</div>\n"
#
# Same as:
#
#   <div>
#     asdf
#     <% if 123 %>
#       <%= 'foobar' %>
#     <% end -%>
#   </div>
```

### With `lint-staged`

Add the gem to your gemfile and the following to your `package.json`:

```js
"lint-staged": {
  // …
  "*.html.erb": "bundle exec erb-format --write"
}
```

### As a TextMate plugin

Create a command with the following settings:

- **Scope selector:** `text.html.erb`
- **Semantic class:** `callback.document.will-save`
- **Input:** `document` → `text`
- **Output:** `replace document` → `text`
- **Caret placement:** `line-interpolation`

```bash
#!/usr/bin/env bash

cd "$TM_PROJECT_DIRECTORY"
bundle exec erb-format --stdin-filename "$TM_FILEPATH" < /dev/stdin 2> /dev/stdout
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nebulab/erb-formatter.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
