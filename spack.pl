#!/usr/bin/perl

#   Copyright 2009-2010 Michael Contento <michaelcontento@gmail.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

use LWP;
use HTTP::Cookies;
use File::stat;
use File::Path;

my $Agent = 'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.5a) Gecko/20030714 Mozilla Firebird/0.6';

# If you  need a proxy, remove the # infront of the next line and enter your PROXY and PORT
# my $HttpProxy = 'http://PROXY_IP:PROXY_PORT';
my $NumArgs       = $#ARGV + 1;
my $ImageCounter  = 0;
my $DownloadCount = 0;
my $FailedCount   = 0;
my $ExistCount    = 0;
my $SizeFetched   = 0;
my $UserAgent     = 0;
my $CookieJar     = 0;
my $DefaultPage   = 0;
my $Request       = 0;
my $Response      = 0;
my $EventId       = $ARGV[0];
my $Path          = './';
my $Path          = $ARGV[1]    if ($NumArgs == 2);
my $Path          = $Path . '/' if ($Path =~ m![^/]$!);
my $Debug         = 0;
my $Debug         = $ARGV[2]    if ($ARGV[2] =~ m/[0-1]/);
my $BaseUrl       = 'http://www.spack.info/';
my $BasePicUrl    = 'http://www.spack-static.de/';
my $OverviewUrl   = $BaseUrl . 'fotos/galerie/' . $EventId; 
my $CookiePath    = '/tmp/SpackSucker.cookie';

print "######\n";
print "## Event-Id: $EventId\n";
print "## Path    : $Path\n";
print "######\n";

print "Debug: BaseUrl     -> $BaseUrl\n"     if $Debug;
print "Debug: OverviewUrl -> $OverviewUrl\n" if $Debug;
print "Debug: CookiePath  -> $CookiePath\n"  if $Debug;

if ($EventId =~ m/^[^0-9]*$/) {
    print "!! Error: Your eventid seems to be invalid.\n";
    print "!! Error: EventId -> $EventId\n";
    die;
}

if (!-e $Path) {
    mkpath($Path);
    print "Debug: Path created\n"     if $Debug;
}

$UserAgent = new LWP::UserAgent;
$UserAgent->agent($Agent)             if $Agent;
$UserAgent->proxy('http', $HttpProxy) if $HttpProxy;
$CookieJar   = HTTP::Cookies->new(file => $CookiePath, autosave => 0);
$UserAgent->cookie_jar($CookieJar);

print "Get the cookies from the server\n";
$DefaultPage = $UserAgent->get($BaseUrl);
$CookieJar->extract_cookies($DefaultPage);

print "Debug: Try to get the 'Overviewpage'..." if $Debug;
$Request  = HTTP::Request->new('GET', $OverviewUrl);
$UserAgent->cookie_jar->add_cookie_header($Request);
$Response = $UserAgent->request($Request);

if ($Response->is_success) {
    print "Ok\n" if $Debug;
} else {
    print "Error\n" if $Debug;
    print "!! Error: Can't get the 'Overviewpage'\n";
    print "!! Error: Url      -> $OverviewUrl\n";
    print "!! Error: Response -> $Response->status_line\n";
    die;
}

$_ = $Response->content;
while ($_ =~ m!(pictures/pics/$EventId/([0-9]*)\.(thumb)\.jpg)!i) {
    $PicAddr  = $1;
    $PicName  = $2 . '.jpg';
    $PicType  = $3;

    $ImageCounter++;
    print "Try to get image no. $ImageCounter ($PicName)...";
    
    if (-e $Path . $PicName) {
        print "Exist\n";
        $ExistCount += 1;
    } else {       
        $PicAddr =~ s/thumb/screen/;
        $Request  = HTTP::Request->new('GET', $BasePicUrl . $PicAddr);
        $Response = $UserAgent->request($Request, $Path . $PicName);    
    
        if ($Response->is_success) {
            $FileStatus = stat($Path . $PicName);
            
            if ($FileStatus->size != $Response->content_length) {
                print "Error\n";
                print "!! Error: Bytes to receive -> $Response->content_length\n";
                print "!! Error: Bytes got        -> $FileStatus->size\n";
                
                unlink $Path . $PicName; 
                $FailedCount += 1;
            } else {	
                print "Ok\n";
                $DownloadCount += 1;
                $SizeFetched   += $FileStatus->size;
            }
        } else {
            print "Error\n";
            print "!! Error: Url      -> $BaseUrl$PicAddr\n";
            print "!! Error: Response -> $Response->status_line\n";    
            
            unlink $Path . $PicName;     
        }       
    }
    
    $_ = $';    
}

if ($ImageCounter == 0) {
    print "Error\n";
    print "!! Nothing done\n";
} else {
    print "-> $DownloadCount images fetched with a size of $SizeFetched bytes.\n";
    print "-> $FailedCount images that i can't fetch.\n";
    print "-> $ExistCount images that already exist.\n";
}
