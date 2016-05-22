# sluggle
Simple IRC Searchbot

## Usage

    sluggle: year of linux desktop
    sluggle: http://example.com

## Address vs Command Modes

There are two modes - address mode and command mode, and this is set in the conf file:

    addressed 0 (for !find)
    addressed 1 (for sluggle: find)

Addressed mode:

    sluggle: find Winter Olympics

Command mode:

    !find Winter Olympics

## Find

The !find command can take either text or a URL:

    !find Winter Olympics
    !find http://google.com

## WOT (Web of Trust)

The !wot command requires a URL:

    !wot http://google.com


## Installation

 1. You will Perl 5 along with the following CPAN modules:

  * Config::Simple
  * Encode
  * File::Temp
  * Graphics::Magick
  * Image::ExifTool
  * JSON
  * LWP::UserAgent
  * Net::Address::IP::Local
  * Net::WOT
  * POE::Component::IRC::Plugin::BotCommand
  * POE::Component::IRC::State
  * POE::Component::IRC
  * POE
  * Regexp::Common
  * Regexp::IPv6
  * URI::URL
  * WWW::Shorten

 2. Clone or save the repository.

 3. Obtain yourself a Bing Search API key, currently freely available for 5000 searches per month.

 4. Rename sluggle.conf.template to sluggle.conf and update the contents.

 5. Run sluggle.pl specifying config file:

    $ ./sluggle.pl sluggle.conf
