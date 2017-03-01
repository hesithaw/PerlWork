#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
use strict;

my $Version = 1.0;
my $RelDate = "2014/11/28";
my $SYSTEM_NAME = $ENV{'SYSTEM_NAME'};
my $SCRIPT_NAME = "MQ_ServerChannelCreator";
my $LOG_FILE_NAME = $SYSTEM_NAME."_".$SCRIPT_NAME.".log";

my $LOG_FILE_FD;
my $USER_FILE_NAME = "MQ_SERVER_DATA_FILES/ChannelInfo.txt";
my $USER_FILE_FD;
my $MQ_IP ;
my $MQ_PORT ;
my $MQ_NAME ;
my $LISTENER = "LISTENER.NC" ;

StartLog();
PrintLog("MQ_ServerChannelCreator.pl|$Version|$RelDate\n");
open ($USER_FILE_FD, "<$USER_FILE_NAME") or DieFunc("Cannot open the text file...!!!");
while(my $user = <$USER_FILE_FD>){
	my @array1 = split(' ', $user);
	my $match_found = grep { /QMAN/ }@array1 ;
	if($match_found){
			if(my $whichmatch = grep { /NAME/ }@array1){
		chomp $array1[3];
		$MQ_NAME = $array1[3];
	}
	elsif(my $whichmatch = grep { /IP/ }@array1){
		chomp $array1[3];
		$MQ_IP = $array1[3];
	}
	elsif(my $whichmatch = grep { /PORT/ }@array1){
		chomp $array1[3];
		$MQ_PORT = $array1[3];
	}
	}
	else{
		chomp $array1[0];
		chomp $array1[1];
		chomp $array1[2];
		if($array1[0] eq 'PTS.SVRCONN'){
			DefinePTSChannel($array1[0], $array1[1], $array1[2]);
		}
		else{
			DefineChannel($array1[0], $array1[1], $array1[2]);
		}
	}
}
DefineAdminChannel();
CloseLog();

sub DefinePTSChannel{
	my $status1 = qx {runmqsc $MQ_NAME << EOF
		DEFINE CHANNEL('$_[0]') CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCIPH(TLS_RSA_WITH_AES_128_CBC_SHA256) SSLCAUTH(REQUIRED) SSLPEER('$_[2]') MCAUSER('$_[1]') REPLACE
		END;
        EOF};
	PrintLog ("$status1\n");
	my $status2 = qx {runmqsc $MQ_NAME << EOF
		DEFINE CHANNEL('$_[0]') CHLTYPE(CLNTCONN) CONNAME('$MQ_IP($MQ_PORT)') TRPTYPE(TCP)  SSLCIPH('TLS_RSA_WITH_AES_128_CBC_SHA256') QMNAME($MQ_NAME) REPLACE
		END;
        EOF};
	PrintLog ("$status2\n");
	my $status3 = qx {runmqsc $MQ_NAME << EOF
		ALTER CHANNEL('$_[0]') CHLTYPE(CLNTCONN) QMNAME($MQ_NAME)
		END;
        EOF};
	PrintLog ("$status3\n");
}
sub DefineAdminChannel{
	my $status1 = qx {runmqsc $MQ_NAME << EOF
		DEFINE CHANNEL('SYSTEM.ADMIN.SVRCONN') CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCAUTH(OPTIONAL) REPLACE
		SET CHLAUTH('SYSTEM.ADMIN.SVRCONN') TYPE(BLOCKUSER) USERLIST('nobody')" | runmqsc QMPTSSGEXT
		END;
        EOF};
	PrintLog ("$status1\n");
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

sub DefineChannel{
	my $EXMQ_PORT = $MQ_PORT+1;
	my $status1 = qx {runmqsc $MQ_NAME << EOF
		DEFINE CHANNEL('$_[0]') CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCIPH(TLS_RSA_WITH_AES_128_CBC_SHA256) SSLCAUTH(REQUIRED) SSLPEER('$_[2]') MCAUSER('$_[1]') REPLACE
		END;
        EOF};
	PrintLog ("$status1\n");
	my $status2 = qx {runmqsc $MQ_NAME << EOF
		DEFINE CHANNEL('$_[0]') CHLTYPE(CLNTCONN) CONNAME('$MQ_IP($EXMQ_PORT)') TRPTYPE(TCP)  SSLCIPH('TLS_RSA_WITH_AES_128_CBC_SHA256') QMNAME($MQ_NAME) REPLACE
		END;
        EOF};
	PrintLog ("$status2\n");
	my $status3 = qx {runmqsc $MQ_NAME << EOF
		ALTER CHANNEL('$_[0]') CHLTYPE(CLNTCONN) QMNAME($MQ_NAME)
		END;
        EOF};
	PrintLog ("$status3\n");
}
sub DefineListener{
	my $status = qx {runmqsc $MQ_NAME << EOF
		DEFINE LISTENER('$LISTENER') TRPTYPE(TCP) PORT($MQ_PORT) CONTROL(QMGR);
		END;
		EOF};
	PrintLog ("$status\n");
}

sub StartListener{
	my $status = qx {runmqsc $MQ_NAME << EOF
		START LISTENER('$LISTENER');
		END;
                EOF};
	 PrintLog ("$status\n");
}

