#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
use strict;

my $Version = 1.0;
my $RelDate = "2014/11/21";
my $MQ_NAME ;
my $USER_FILE_NAME = "MQ_SERVER_DATA_FILES/ChannelInfo.txt";
my $USER_FILE_FD;
open ($USER_FILE_FD, "<$USER_FILE_NAME") or die("Unable to Open the file $USER_FILE_NAME");
while(my $user = <$USER_FILE_FD>){
        my @array1 = split(' ', $user);
        my $match_found = grep { /QMAN/ }@array1 ;
        if($match_found){
                if(my $whichmatch = grep { /NAME/ }@array1){
                        chomp $array1[3];
                        $MQ_NAME = $array1[3];
			last;
                }
	}
}
my $QueueCreator = `$MQ_NAME.sh`;
my $ServerChannelCreator = `MQ_ServerChannelCreator.pl`;
my $UNIXUserIDCreator =`MQ_UNIXUserIDCreator.pl`;
my $QueueAutherizationConfigurator =`MQ_QueueAutherizationConfigurator.pl`;
my $AMSQueueConfigurator =`MQ_AMSQueueConfigurator.pl`;

