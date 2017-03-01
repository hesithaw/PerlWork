#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
use strict;

my $Version = 1.0;
my $RelDate = "2014/11/28";
my $SYSTEM_NAME = $ENV{'SYSTEM_NAME'};
my $SCRIPT_NAME = "MQ_AMSQueueConfigurator";
my $LOG_FILE_NAME = $SYSTEM_NAME."_".$SCRIPT_NAME.".log";
my $LOG_FILE_FD;
my $USER_FILE_NAME = "MQ_SERVER_DATA_FILES/QueueInfo.txt";
my $USER_FILE_FD;
my $MQ_NAME ;
my $NC_MCA_ID;
my $NC_DN;
my $CommonMember = "CommonMember";
my $Common_DN_string = "CN=$CommonMember,OU=PT,C=SL";
StartLog();
PrintLog("MQ_AMSQueueConfigurator.pl|$Version|$RelDate\n");
open ($USER_FILE_FD, "<$USER_FILE_NAME") or DieFunc("Cannot open the text file...!!!");
while(my $user = <$USER_FILE_FD>){
    my @array1 = split(' ', $user);
    my $match_found = grep { /QMAN/ }@array1 ;
    if($match_found){
		if(my $whichmatch = grep { /NAME/ }@array1){
                        chomp $array1[3];
                        $MQ_NAME = $array1[3];
                }
		elsif(my $whichmatch = grep { /NC_MCA_ID/ }@array1){
			chomp $array1[3];
			$NC_MCA_ID = $array1[3];
		}
		elsif(my $whichmatch = grep { /NC_DN/ }@array1){
			chomp $array1[3];
			$NC_DN = $array1[3];
		}
	}
	else{
                chomp $array1[1];
                chomp $array1[2];
		chomp $array1[3];
		GeneratePolicy($array1[1], $array1[2], $array1[3]);
	}
}
#GeneratePTSMQPolicy();
CloseLog();

sub GeneratePTSMQPolicy{
	my $ExecutingString1 = "setmqspl -m $MQ_NAME -p PTSMQPSMS.DATA.OUT -s SHA256 -e AES128 -r $NC_DN -a $Common_DN_string";
	my $status1 = `$ExecutingString1`;
	PrintLog("$ExecutingString1");
	PrintLog("$status1");
	my $ExecutingString2 = "dspmqspl -m $MQ_NAME -p PTSMQPSMS.DATA.OUT";
	my $status2 = `$ExecutingString2`;
	PrintLog("$ExecutingString2");
	PrintLog("$status2");
	my $ExecutingString3 = "setmqspl -m $MQ_NAME -p PTSMQPSMS.DATA.IN -s SHA256 -e AES128 -r $Common_DN_string -a $NC_DN";
	my $status3 = `$ExecutingString3`;
	PrintLog("$ExecutingString3");
	PrintLog("$status3");
    my $ExecutingString4 = "dspmqspl -m $MQ_NAME -p PTSMQPSMS.DATA.IN"; 
	my $status4 = `$ExecutingString4`;
	PrintLog("$ExecutingString4");
	PrintLog("$status4");
	my $ExecutingString1 = "setmqspl -m $MQ_NAME -p PTSMQSWIFT.DATA.OUT -s SHA256 -e AES128 -r $NC_DN -a $Common_DN_string";
	my $status1 = `$ExecutingString1`;
	PrintLog("$ExecutingString1");
	PrintLog("$status1");
	my $ExecutingString2 = "dspmqspl -m $MQ_NAME -p PTSMQSWIFT.DATA.OUT";
	my $status2 = `$ExecutingString2`;
	PrintLog("$ExecutingString2");
	PrintLog("$status2");
	my $ExecutingString3 = "setmqspl -m $MQ_NAME -p PTSMQSWIFT.DATA.IN -s SHA256 -e AES128 -r $Common_DN_string -a $NC_DN";
	my $status3 = `$ExecutingString3`;
	PrintLog("$ExecutingString3");
	PrintLog("$status3");
    my $ExecutingString4 = "dspmqspl -m $MQ_NAME -p PTSMQSWIFT.DATA.IN"; 
	my $status4 = `$ExecutingString4`;
	PrintLog("$ExecutingString4");
	PrintLog("$status4");
}
sub GeneratePolicy{
	my $ExecutingString1 = "setmqspl -m $MQ_NAME -p $_[0] -s SHA256 -e AES128 -r $NC_DN -a $Common_DN_string";
	my $status1 = `$ExecutingString1`;
	PrintLog("$ExecutingString1");
	PrintLog("$status1");
	my $ExecutingString2 = "dspmqspl -m $MQ_NAME -p $_[0]";
	my $status2 = `$ExecutingString2`;
	PrintLog("$ExecutingString2");
	PrintLog("$status2");
	my $ExecutingString3 = "setmqspl -m $MQ_NAME -p $_[1] -s SHA256 -e AES128 -r $Common_DN_string -a $NC_DN";
	my $status3 = `$ExecutingString3`;
	PrintLog("$ExecutingString3");
	PrintLog("$status3");
    my $ExecutingString4 = "dspmqspl -m $MQ_NAME -p $_[1]"; 
	my $status4 = `$ExecutingString4`;
	PrintLog("$ExecutingString4");
	PrintLog("$status4");
	#PrintLog("Generated Policy for channels $_[0] and $_[1]");
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




