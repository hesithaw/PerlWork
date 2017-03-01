#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
use strict;

my $Version = 1.0;
my $RelDate = "2014/11/28";
my $SYSTEM_NAME = $ENV{'SYSTEM_NAME'};
my $SCRIPT_NAME = "QManagerConfigurator";
my $LOG_FILE_NAME = $SYSTEM_NAME."_".$SCRIPT_NAME.".log";

my $LOG_FILE_FD;
my $USER_FILE_NAME = "MQ_SERVER_DATA_FILES/ChannelInfo.txt";
my $USER_FILE_FD;
my $QMGR_NAME;
my $QMGR_SSL_KEYR;
#my $PATH = Cwd::cwd()."/QMAN_KEYSTORE/";

StartLog();
PrintLog("QManagerConfigurator.pl|$Version|$RelDate\n");

open ($USER_FILE_FD, "<$USER_FILE_NAME") or DieFunc("Cannot open the text file...!!!");
while(my $user = <$USER_FILE_FD>){
	my @array1 = split(' ', $user);
	my $match_found = grep { /QMAN/ }@array1 ;
        if($match_found){
                if(my $whichmatch = grep { /NAME/ }@array1){
			chomp $array1[3];
			$QMGR_NAME = $array1[3];
			last;
		}
	}
}
QMgrKeyrepoChange();
`endmqm -i $QMGR_NAME`;
sleep(2);
CopyQMANKeys();
`strmqm $QMGR_NAME`;
CloseLog();

sub CopyQMANKeys{
	chdir("QMAN_KEYSTORE") or DieFunc("Cannot go to directory QMAN_KEYSTORE");
	`rm -rf  /var/mqm/qmgrs/$QMGR_NAME/ssl/*`;
	`cp  $QMGR_NAME* /var/mqm/qmgrs/$QMGR_NAME/ssl/`;
	`chmod g+rw /var/mqm/qmgrs/$QMGR_NAME/ssl/*`;
	chdir ("../");
	PrintLog ("copied QMANS keys to /var/mqm/qmgrs/$QMGR_NAME/ssl");
}
sub RenameWithDateTime
{
        my $METHOD = "rename_with_datetime";
        if(-e "$_[0]"){
                my $tmp =`ls -lct --time-style=\"+%Y-%m-%d %T\" $_[0]`;
                my @tmparr                      = split(' ',$tmp);
                my @file_date           = split('-',$tmparr[5]);
                my @file_time           = split(':',$tmparr[6]);
                my $new_file_name       = $_[0]."_".@file_date[0].@file_date[1].@file_date[2]."_".@file_time[0].@file_time[1].@file_time[2];
                system("mv $_[0] $new_file_name");
        }else{
                Print("red",1,"#rename with datetime# - File does not exist - not renaming\n");
        }
}

sub PrintLog
{
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $year += 1900;
        $mon++;
        print $LOG_FILE_FD "$year.$mon.$mday|$hour:$min:$sec"." : "."$_[1]"."$_[0]\n";
}

sub CloseLog
{
        print $LOG_FILE_FD ">> - - - - - Ending Program :";
        my $path = abs_path($0);
        print $LOG_FILE_FD "$path";
        foreach (@ARGV) {
                        print $LOG_FILE_FD " $_";
        }
        print $LOG_FILE_FD " - - - - -\n";
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $year += 1900;
        $mon++;
        print $LOG_FILE_FD "Execution finished time - $year.$mon.$mday|$hour:$min:$sec\n";
        print $LOG_FILE_FD ">> - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n";
        close $LOG_FILE_FD;
}

sub DieFunc
{
        print("$_[0]\n");
        PrintLog("$_[0]\n");
        exit 1;
}

sub StartLog
{
        if(-e "$LOG_FILE_NAME"){RenameWithDateTime("$LOG_FILE_NAME");}
        open ($LOG_FILE_FD, ">>$LOG_FILE_NAME") or DieFunc("Cannot open the log...!!!");
        select((select($LOG_FILE_FD), $|=1)[0]);
        print $LOG_FILE_FD ">> - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n";
        print $LOG_FILE_FD ">> - - - - - Starting Program :";
        my $path = abs_path($0);
        print $LOG_FILE_FD "$path";
        foreach (@ARGV)
        {
                print $LOG_FILE_FD " $_";
        }
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $year += 1900;
        $mon++;
        print $LOG_FILE_FD "\nStart execution time - $year.$mon.$mday|$hour:$min:$sec\n";
        print $LOG_FILE_FD " - - - - -\n";
}

sub QMgrKeyrepoChange{
	my $PATH = "/var/mqm/qmgrs/$QMGR_NAME/ssl/";
	$QMGR_SSL_KEYR = $PATH.$QMGR_NAME."key";
	PrintLog ("$QMGR_SSL_KEYR\n");
	#print "$QMGR_NAME\n";
	my $status1 = qx {
		runmqsc $QMGR_NAME << EOF
		ALTER QMGR SSLKEYR('$QMGR_SSL_KEYR');
		END;
                EOF};
	PrintLog ("$status1\n");
}
