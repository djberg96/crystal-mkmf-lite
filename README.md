# crystal-mkmf-lite

A Crystal port of mkmf-lite, a light version of mkmf designed for use within programs.

## Installation
```yaml
   dependencies:
     crystal-mkmf-lite:
       github: djberg96/crystal-mkmf-lite
```

And then `shards install`.

## Usage

```crystal
require "mkmf-lite"

class Something
  include Mkmf::Lite

  def some_method
    if have_header("sys/something.h")
      # You have that header on your local system.
    else
      # You don't.
    end
  end
end
```

## Description
This is a port of my mkmf-lite Ruby library to Crystal, which in turn is
meant to be a smaller, lighter version of Ruby's heavy mkmf library.

The mkmf-lite library is a module, it's small, and it's designed to be mixed
into classes. It contains a handful of methods that, most likely, will be
used in conjunction with C extensions.

This library does not package C extensions, nor generate a log file or a
Makefile. It does, however, require that you have a C compiler somewhere on
your system.

## Supported Platforms
Linux and Darwin for now. Other platforms will only be added via
pull request.

## Copyright
(C) 2021, Daniel J. Berger
All Rights Reserved

## Author
Daniel J. Berger
