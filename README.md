# ERB::Formatter 🪜

Format ERB files with speed and precision.

Features:

- very fast
- attempts to limit length (configurable)
- tries to have an output similar to prettier for HTML
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
- fix spaces after attribute equal signs instead of complaining

## Installation

Add this line to your application's Gemfile:

    $ bundle add erb-formatter

Or install it yourself as:

    $ gem install erb-formatter

## Usage

### From [Visual Studio Code](https://code.visualstudio.com)

Just install the [Ruby ERB::Formatter 🪜](https://marketplace.visualstudio.com/items?itemName=elia.erb-formatter) extension
and follow the setup instructions there.

### From the command line

Update files in-place:

    $ erb-format app/views/**/*.html.erb --write

or use stdin/stdout (useful for editor integrations):

    $ echo "<div       > asdf  <% if 123%> <%='foobar'%> <%end-%>  </div>" | erb-format --stdin
    <div>
      asdf
      <% if 123 %>
        <%= 'foobar' %>
      <% end -%>
    </div>

Check out `erb-format --help` for more options.

### From [Ruby](https://www.ruby-lang.org/en/)

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

### With [`lint-staged`](https://github.com/okonet/lint-staged#readme)

Add the gem to your gemfile and the following to your `package.json`:

```js
"lint-staged": {
  // …
  "*.html.erb": "bundle exec erb-format --write"
}
```

### As a [TextMate](http://macromates.com) command

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

### With [(Neo)VIM ALE](https://github.com/dense-analysis/ale)

Enable `erb-formatter` as a fixer in the ALE config:

```vim
let g:ale_fixers = {
\   'eruby': ['erb-formatter'],
\}
```

### With [Zed](https://zed.dev/) editor

With the gem installed, configure `settings.json` to use the formatter as an external command

```json
"language_overrides": {
  "ERB": {
    "formatter": {
      "external": {
        "command": "erb-format",
        "arguments": ["--stdin", "--print-width", "80"]
      }
    }
  }
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

In order to run a specific test, use the following command:

```bash
m test/erb/test_formatter.rb:123
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nebulab/erb-formatter.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
