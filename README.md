# sluggle
Simple IRC Searchbot

## Usage

    sluggle: Winter Olympics

## Purpose

At the time of writing sluggle only has two functions:

 1. To respond to sluggle: search requests
 2. To watch for web addresses and return a tinyurl and description

## Installation

 1. You will Perl 5 along with the following CPAN modules:

  * POE
  * Config::Simple
  * LWP::UserAgent
  * JSON

 2. Clone or save the repository.

 3. Obtain yourself a Bing Search API key, currently freely available for 5000 searches per month.

 4. Rename sluggle.conf.template to sluggle.conf and update the contents.

 5. Run sluggle.pl specifying config file:

    $ ./sluggle.pl sluggle.conf
