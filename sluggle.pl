#!/usr/bin/perl
#
# A simple IRC searchbot

# Copyright (C) 2016 Christopher Roberts
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use POE;
use POE::Component::IRC;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::BotCommand;

use vars qw( $CONF );
use Config::Simple;

if ( (defined $ARGV[0]) and (-r $ARGV[0]) ) {
    $CONF = new Config::Simple($ARGV[0]);
} else {
    print "USAGE: sluggle.pl sluggle.conf\n";
    exit;
}

my @channels = $CONF->param('channels');

# We create a new PoCo-IRC object
my $irc = POE::Component::IRC::State->spawn(
   nick     => $CONF->param('nickname'),
   ircname  => $CONF->param('ircname'),
   server   => $CONF->param('server'),
) or die "Oh noooo! $!";

POE::Session->create(
    package_states => [
        main => [ qw(
            _default 
            _start 
            irc_001 
            irc_invite
            irc_botcmd_find 
            irc_botcmd_wot
            irc_botcmd_op
            irc_public
        ) ],
    ],
    heap => { irc => $irc },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

    # retrieve our component's object from the heap where we stashed it
    my $irc = $heap->{irc};

    $irc->plugin_add('BotCommand',
        POE::Component::IRC::Plugin::BotCommand->new(
            Commands => {
                find        => 'A simple Internet search, takes one argument - a string to search.',
                wot         => 'Looks up WoT Web of Trust reputation, takes one argument - an http web address.',
                op          => 'Currently has no other purpose than to tell you if you are an op or not!',
            },
            In_channels     => 1,
            In_private      => $CONF->param('private'),
            Auth_sub        => \&check_if_bot,
            Ignore_unauthorized => 1,
            Addressed       => $CONF->param('addressed'),
            Prefix          => $CONF->param('prefix'),
            Eat             => 1,
            Ignore_unknown  => 1,
        )
    );

    $irc->yield( register => 'all' );
    $irc->yield( connect => { } );
    return;
}

sub irc_001 {
    my $sender = $_[SENDER];

    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

    # we join our channels
    $irc->yield( join => $_ ) for @channels;
    return;
}

sub irc_invite {
    my ($who, $where) = @_[ARG0 .. ARG1];

    # we join our channels
    $irc->yield( join => $where );
    return;
}

sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

    unless (check_if_bot('', $nick) ) {
        return;
    }

#  { 
#    'ID' => 'f7572a24-b282-4f14-9326-9a29dcc7250d',
#    '__metadata' => { 
#                      'type' => 'WebResult',
#                      'uri' => 'https://api.datamarket.azure.com/Data.ashx/Bing/SearchWeb/v1/Web?Query=\'Surrey LUG\'&Latitude=51.2362&Longitude=-0.5704&$skip=0&$top=1'
#                    },
#    'Url' => 'http://surrey.lug.org.uk/',
#    'Description' => 'Surrey LUG is a friendly Linux user group. If you have any interest in Linux, GNU (or related systems such as *BSD, Solaris, OpenSolaris, etc) and are based in Surrey ...',
#    'DisplayUrl' => 'surrey.lug.org.uk',
#    'Title' => 'Surrey Linux User Group'
#  }

    # Ignore sluggle: commands - handled by botcommand plugin
    my $whoami = $CONF->param('nickname');
    if ($what =~ /^(?:!|$whoami:)/i) {
        # Do nothing

    # Shorten links and return title
    } elsif ( (my @requests) = $what =~ /\b(https?:\/\/[^ ]+)\b/g ) {
        foreach my $request (@requests) {
            my $response = find($request);
            $irc->yield( privmsg => $channel => "$nick: " . $response);
        }
    }

    return;
}

# We registered for all events, this will produce some debug info.
sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event: " );

    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']' );
        }
        else {
            push ( @output, "'$arg'" );
        }
    }
    print join ' ', @output, "\n";
    return;
}

sub sanitise_address {
    my $request = shift;

    use Regexp::IPv6 qw($IPv6_re);
    use Regexp::Common qw /net/;
    my $IPv4_re = $RE{net}{IPv4};

    use URI::URL;
    my $url = new URI::URL $request;
    my $port;
    eval { $port = $url->port; };
    warn "Port not found $@" if $@;

    my $response = 0;

    if ( (defined $port) and ($port ne '80' ) and ($port ne '443') ) {
        $response = 'Non-standard HTTP ports are not permitted';

    } elsif ( $request =~ m/^(?:https?:\/\/)?$IPv4_re/i ) {
        $response = 'IP addresses are not permitted';

    } elsif ( $request =~ m/^(?:https?:\/\/)?$IPv6_re/i ) {
        $response = 'IP addresses are not permitted';

    } elsif ( $request =~ m/^(?:https?:\/\/)?[\/\.]+/i ) {
        $response = 'URLs starting with a file path are not permitted';

    }

    return $response;
}

sub irc_botcmd_op {
    my $nick = ( split /!/, $_[ARG0] )[0];

    my ($channel, $request) = @_[ ARG1, ARG2 ];

    if ( check_if_op($channel, $nick) ) {
        $irc->yield( privmsg => $channel => "$nick: You are indeed a might op!");
    } else {
        $irc->yield( privmsg => $channel => "$nick: Only channel operators may do that!");
    } 

    return;

}

sub irc_botcmd_find {
    my $nick = ( split /!/, $_[ARG0] )[0];

    my ($channel, $request) = @_[ ARG1, ARG2 ];

    my $response = find($request);

    $irc->yield( privmsg => $channel => "$nick: " . $response);

    return;

}

sub find {
    my $request = shift;

    my $errors = sanitise_address($request);
    if ($errors ne '0') {
        return $errors;
    }

    my ($url, $title, $shorten);

    # Web address search
    if ($request =~ /^https?:\/\//i) {
        $url     = $request;
        $title   = title($request);
        $shorten = shorten($url);

    # Assume string search
    } else {
        my $response = search($request);
        $url     = $response->{'Url'};
        $title   = $response->{'Title'};
        $shorten = $url; # Don't shorten URL on plain web search
    }

    if (! defined $url) {
        return "There were no search results!";
    }

    my $wot     = wot($url);

    my @elements;
    if (defined $shorten) {
        push(@elements, $shorten);
    } else {
        push(@elements, 'URL shortener failed');
    }

    if (defined $title) {
        push(@elements, $title);
    } else {
        push(@elements, 'Title lookup failed');
    }

    if ((defined $wot) and ($wot->{trustworthiness_score} =~ /^\d+$/)) {
        push(@elements, 'WoT is ' 
            . $wot->{trustworthiness_description}
            . ' ('
            . $wot->{trustworthiness_score}
            . ')'
        );
    } else {
        # push(@elements, 'WoT lookup failed');
    }

    my $count = @elements;
    if ($count != 0) {
        my $message = join(' - ', @elements);
        return $message . '.';
    } else {
        # Do nothing, hopefully no-one will notice
    }

    return;

}

sub irc_botcmd_wot {
    my $nick = ( split /!/, $_[ARG0] )[0];

    my ( $channel, $request ) = @_[ ARG1, ARG2 ];

    if ($request !~ /^https?:\/\//i) {
        $request = 'http://' . $request;
    }

    my $errors = sanitise_address($request);
    if ($errors ne '0') {
        $irc->yield( privmsg => $channel => "$nick: $errors");
        return;
    }

    my $wot = wot($request);
    if ((defined $wot) and ($wot->{trustworthiness_score} =~ /\d/) ) {
        $irc->yield( privmsg => $channel => "$nick: Site reputation is "
           . $wot->{trustworthiness_description}
           . ' (' 
           . $wot->{trustworthiness_score} 
           . ').'
        );
    } else {
        $irc->yield( privmsg => $channel => "$nick: WoT did not return any site reputation.");
    }

    return;

}

sub wot {
    my $query = shift;

    use URI;
    my $uri = URI->new($query);

    use Net::WOT;
    my $wot = Net::WOT->new;

    my %wot = $wot->get_reputation($uri->host);

    # the %wot hash seems oddly structured
    my $mywot = {
        'trustworthiness_description'       => $wot->trustworthiness_description,
        'trustworthiness_score'             => $wot->trustworthiness_score,
        'trustworthiness_confidence'        => $wot->trustworthiness_confidence,
        'vendor_reliability_description'    => $wot->vendor_reliability_description,
        'vendor_reliability_score'          => $wot->vendor_reliability_score,
        'vendor_reliability_confidence'     => $wot->vendor_reliability_confidence,
        'privacy_description'               => $wot->privacy_description,
        'privacy_score'                     => $wot->privacy_score,
        'privacy_confidence'                => $wot->privacy_confidence,
        'child_safety_description'          => $wot->child_safety_description,
        'child_safety_score'                => $wot->child_safety_score,
        'child_safety_confidence'           => $wot->child_safety_confidence
    };

    return $mywot;
}

sub shorten {
    my $query = shift;

    use WWW::Shorten 'TinyURL';

    # Eval required as WWW::Shorten falls over if service unavailable
    my $short;
    eval {
        $short = makeashorterlink($query);
    };
    warn "URL shortener failed $@" if $@;

    # Stop using shortened address if it's actually longer!
    if ( length($short) >= length($query) ) {
        $short = $query;
    }

    return $short;
}

sub title {
    my $query = shift;

    use LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(20);
    $ua->protocols_allowed( [ 'http', 'https'] );
    $ua->max_size(1024 * 1024 * 8);
    $ua->env_proxy;

    my $response = $ua->get($query);

    if ($response->is_success) {
        return $response->title();
    } else {
        return $response->status_line;
    }
}

sub search {
    my $query = shift;

    # Remove any non-ascii characters
    $query =~ s/[^[:ascii:]]//g;

    my $account_key = $CONF->param('key');
    my $serviceurl  = $CONF->param('url');
    my $searchurl   = $serviceurl . '%27' . $query . '%27';

    use LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(20);
    $ua->env_proxy;

    my $req = HTTP::Request->new( GET => $searchurl );
    $req->authorization_basic('', $account_key);
    my $response = $ua->request( $req );

    # use Data::Dumper;
    # warn Dumper( $response->{'_content'} );

# RAW

# '_content' => '{
#   "d":{
#       "results":
#           [
#               {
#                   "__metadata": {
#                       "uri":"https://api.datamarket.azure.com/Data.ashx/Bing/SearchWeb/v1/Web?Query=\\u0027Surrey LUG\\u0027&Latitude=51.2362&Longitude=-0.5704&$skip=# 0&$top=1",
#                       "type":"WebResult"
#                   },
#                   "ID":"bd83151f-c94e-4a44-916c-4d9dba501a69",
#                   "Title":"Surrey Linux User Group",
#                   "Description":"Surrey LUG is a friendly Linux user group. If you have any interest in Linux, GNU (or related systems such as *BSD, Solaris, OpenSolaris, etc) and are based in Surrey ...",
#                   "DisplayUrl":"surrey.lug.org.uk",
#                   "Url":"http://surrey.lug.org.uk/"
#               }
#           ],
#           "__next":"https://api.datamarket.azure.com/Data.ashx/Bing/SearchWeb/v1/Web?Query=\\u0027Surrey%20LUG\\u0027&Latitude=51.2362&Longitude=-0.5704&$skip=1&$top=1"
#       }
#   }',

    use JSON;
    my $ref = JSON::decode_json( $response->{'_content'} );
    # warn Dumper( $ref );

# JSON:

#$VAR1 = { 
#          'd' => { 
#                   '__next' => 'https://api.datamarket.azure.com/Data.ashx/Bing/SearchWeb/v1/Web?Query=\'Surrey%20LUG\'&Latitude=51.2362&Longitude=-0.5704&$skip=1&$top=1',
#                   'results' => [ 
#                                  { 
#                                    'ID' => 'f7572a24-b282-4f14-9326-9a29dcc7250d',
#                                    '__metadata' => { 
#                                                      'type' => 'WebResult',
#                                                      'uri' => 'https://api.datamarket.azure.com/Data.ashx/Bing/SearchWeb/v1/Web?Query=\'Surrey LUG\'&Latitude=51.2362&Longitude=-0.5704&$skip=0&$top=1'
#                                                    },
#                                    'Url' => 'http://surrey.lug.org.uk/',
#                                    'Description' => 'Surrey LUG is a friendly Linux user group. If you have any interest in Linux, GNU (or related systems such as *BSD, Solaris, OpenSolaris, etc) and are based in Surrey ...',
#                                    'DisplayUrl' => 'surrey.lug.org.uk',
#                                    'Title' => 'Surrey Linux User Group'
#                                  }
#                                ]
#                 }
#        };

    return( $ref->{'d'}{'results'}[0] );

}

sub check_if_bot {
    my ($object, $nick, $where, $command, $args) = @_;

    my @bots = $CONF->param('bots');
    my $bots = join('|', @bots );

    if ($nick =~ /^(?:$bots)\b/i) {
        warn "Blocked";
        return 0;
    }

    return 1;
}

sub check_if_op {
  my ($chan, $nick) = @_;
  return 0 unless $nick;
  if (($irc->is_channel_operator($chan, $nick)) or 
      ($irc->nick_channel_modes($chan, $nick) =~ m/[aoq]/)) {
    return 1;
  }
  else {
    return 0;
  }
}
