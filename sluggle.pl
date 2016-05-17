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
use POE qw(Component::IRC);

use vars qw( $CONF );
use Config::Simple;

if ( (defined $ARGV[0]) and (-r $ARGV[0]) ) {
    $CONF = new Config::Simple($ARGV[0]);
} else {
    print "USAGE: sluggle.pl sluggle.conf\n";
    exit;
}

my @channels = channel_list();

# We create a new PoCo-IRC object
my $irc = POE::Component::IRC->spawn(
   nick     => $CONF->param('nickname'),
   ircname  => $CONF->param('ircname'),
   server   => $CONF->param('server'),
) or die "Oh noooo! $!";

POE::Session->create(
    package_states => [
        main => [ qw(_default _start irc_001 irc_public) ],
    ],
    heap => { irc => $irc },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

    # retrieve our component's object from the heap where we stashed it
    my $irc = $heap->{irc};

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

sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

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

    # Ignore find bot to prevent bot battles
    if ($nick eq 'find') {
        next;

    # Simple link to readme if someone asks for help
    } elsif ( $what =~ /^sluggle: help/i ) {
        $irc->yield( privmsg => $channel => "$nick: For help please visit https://github.com/chrisjrob/sluggle/blob/master/README.md" );

    # Bing search
    } elsif ( (my $request) = $what =~ /^sluggle: (.+)/ ) {
        if ($request =~ /^https?:\/\//) {
            my $response = title($request);
            my $shorten  = shorten($request);
            $irc->yield( privmsg => $channel => "$nick: " . $shorten . ' - ' . $response );
        } else {
            my $response = search($request);
            $irc->yield( privmsg => $channel => "$nick: " . $response->{'Title'} . ' - ' . $response->{'Url'} );
            $irc->yield( privmsg => $channel => "$nick: " . $response->{'Description'} );
        }

    # Shorten links and return title
    } elsif ( (my @requests) = $what =~ /\b(https?:\/\/[^ ]+)\b/g ) {
        foreach my $request (@requests) {
            my $response = title($request);
            my $shorten  = shorten($request);
            $irc->yield( privmsg => $channel => "$nick: " . $shorten . ' - ' . $response );
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

sub shorten {
    my $query = shift;

    use WWW::Shorten 'TinyURL';
    my $short = makeashorterlink($query);
    # $long_url  = makealongerlink($short_url);

    return $short;
}

sub title {
    my $query = shift;

    use LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(20);
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

sub channel_list {
    my @channels;

    my $ref_type = ref $CONF->param('channels');
    if ($ref_type eq 'ARRAY') {
        @channels = @{ $CONF->param('channels') };
    } else {
        push(@channels, $CONF->param('channels') );
    }

    return @channels;
}


