#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
use strict;
#use Net::SSH::Expect;
#use Math::GMP

my $Version = 1.0;
my $RelDate = "2014/11/21";
my $SYSTEM_NAME = $ENV{'SYSTEM_NAME'};
my $SYSTEM_IP = $ENV{'MQ_SERVER_IP_1'};
my $SCRIPT_NAME = "MQ_UNIXUserIDCreator";
my $LOG_FILE_NAME = $SYSTEM_NAME."_".$SCRIPT_NAME.".log";
my $LOG_FILE_FD;

my $USER_FILE_NAME = "MQ_SERVER_DATA_FILES/UNIXUserFile.txt";
my $USER_FILE_FD;
my $SHELL_FILE_NAME = "USER_ADD.sh";
my $SHELL_FILE_FD;

StartLog();
PrintLog("MQ_UNIXUserIDCreator.pl|$Version|$RelDate\n");
#my $ExecutingString = "ssh -t -t ptadm\@$SYSTEM_IP";

#my $ssh_status = `$ExecutingString`;
open ($USER_FILE_FD, "<$USER_FILE_NAME") or DieFunc("Cannot open the text file...!!!");
open ($SHELL_FILE_FD, "+>$SHELL_FILE_NAME") or DieFunc("Cannot open the $SHELL_FILE_NAME file...!!!");
print $SHELL_FILE_FD "#!/bin/bash\n";
print $SHELL_FILE_FD "echo \" ";
while(my $user = <$USER_FILE_FD>){
	chomp $user;
	my $status1 = system("egrep -i \"^$user\" /etc/passwd");#`id $line"); 
	if($status1/256 == 0){
		PrintLog ("user $user exist\n");
	}
	else{
		print $SHELL_FILE_FD "sudo useradd -p nc123 -U $user\n";
		PrintLog("User $user added to $SHELL_FILE_NAME");
	}
	
}
print $SHELL_FILE_FD "exit\" | ssh -t -t ptadm\@$SYSTEM_IP";
close $USER_FILE_FD;
close $SHELL_FILE_FD;
`chmod 775 $SHELL_FILE_NAME`;
`$SHELL_FILE_NAME`;
CloseLog();

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

