# sluggle
Simple IRC Searchbot

## Usage

    !find Winter Olympics
    !find http://google.com
    !wot http://google.com

## Address vs Command Modes

There are two modes - address mode:

    sluggle: find Winter Olympics

And command mode:

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

  * POE
  * Config::Simple
  * LWP::UserAgent
  * JSON
  * Net::WOT
  * POE::Component::IRC::Plugin::BotCommand
  * POE::Component::IRC
  * POE
  * Regexp::Common
  * Regexp::IPv6
  * URI::URL
  * URI
  * WWW::Shorten::TinyURL

 2. Clone or save the repository.

 3. Obtain yourself a Bing Search API key, currently freely available for 5000 searches per month.

 4. Rename sluggle.conf.template to sluggle.conf and update the contents.

 5. Run sluggle.pl specifying config file:

    $ ./sluggle.pl sluggle.conf
