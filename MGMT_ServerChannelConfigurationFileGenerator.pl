#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
#use DBI;
#use strict;
my $Version = 1.0;
my $RelDate = "2014/11/28";
my $ATS_DB_STRING = $ENV{'ATS_DB_STRING'};
$ATS_DB_STRING ==~ s/wallet:\/\//\/@/g;
my $LOGS_DIR = $ENV{'SYSTEM_LOGS'};
my $SYSTEM_NAME = $ENV{'SYSTEM_NAME'};
my $SCRIPT_NAME = "MGMT_ServerChannelConfigurationFileGenerator";
my $LOG_FILE_NAME = $SYSTEM_NAME."_".$SCRIPT_NAME.".log";
my $USER_FILE_NAME = "../MQ_SERVER_SCRIPTS/MQ_SERVER_DATA_FILES/ChannelInfo.txt";
my $LOG_FILE_FD;
my $USER_FILE_FD;
my $MQ_SYSTEM_NAME = $SYSTEM_NAME;
my $MQ_SUFFIX = $ENV{'MQ_SUFFIX'};
my $qman_IP = $ENV{'MQ_SERVER_IP_1'};
my $MQ_BASE_PORT = $ENV{'MQ_BASE_PORT'};
my $password = "nc123";

StartLog();
PrintLog("MGMT_ServerChannelConfigurationFileGenerator.pl|$Version|$RelDate\n");
@UNIXUsers = GetUsersfromDB();
@DN_NAMES = GetX509_DN();
open($USER_FILE_FD, "+>$USER_FILE_NAME") or DieFunc("Cannot open the text file...!!!");

my $QMAN_NAME = GetQMANNamefromDB();
my $QMAN_PORT = GetPortOffsetfromDB();
my $NC_MCA_ID = GetNCMCA_ID();
my $NC_DN = GetNC_DN();
my $NC_CHANNEL = GetNCChannel();
my $NC_INFO = $NC_CHANNEL."\t".$NC_MCA_ID."\t".$NC_DN;
print $USER_FILE_FD "QMAN NAME = $QMAN_NAME\n" ;
print $USER_FILE_FD "QMAN IP = $qman_IP\n" ;
print $USER_FILE_FD "QMAN PORT = $QMAN_PORT\n" ;
print $USER_FILE_FD "$NC_INFO\n";
my $count = 0;
foreach my $user (@UNIXUsers){
	my @array1 = split(' ', $user);
	my $char = '-';
	if(index($array1[0], $char) != -1){
		PrintLog ("$user not added to the file since contains '-'");
	}
	else{
		$user = $user."\t".$DN_NAMES[$count];
		PrintLog ("$user added to the file");
		print $USER_FILE_FD "$user\n" ;
	}
	$count++;
}
close $USER_FILE_FD ;
#my $status = system("sshpass -p $password scp $USER_FILE_NAME $MQ_SYSTEM_NAME\"@\"$qman_IP:~/mq_scripts/TextFiles ");
#if($status/256 == 0){
#	PrintLog("$USER_FILE_NAME copied successfully");
#}
#else{
#	PrintLog("$USER_FILE_NAME not copied to the destination !!");
#	print "$USER_FILE_NAME not copied to the destination !!";
#}
CloseLog();
sub GetNC_DN{
        if(!(CheckDBString("$ATS_DB_STRING"))){
                Print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
        if(!(CheckTableExists("ATSD_MQM_NORMAL","$ATS_DB_STRING"))){
                Print("red",0,"ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
        my $nc_dn = qx {sqlplus -s $ATS_DB_STRING<< EOF
                SELECT X509_DN FROM ATSD_MQM_NORMAL;
                exit;
                EOF};
        my @tmp_arr1 = split('\n',$nc_dn);
        my $NewC_DN = $tmp_arr1[3];
        return $NewC_DN;
}
sub GetNCMCA_ID{
        if(!(CheckDBString("$ATS_DB_STRING"))){
                Print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
        if(!(CheckTableExists("ATSD_MQM_NORMAL","$ATS_DB_STRING"))){
                Print("red",0,"ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
        my $mca_id = qx {sqlplus -s $ATS_DB_STRING<< EOF
                SELECT MCA_ID FROM ATSD_MQM_NORMAL;
                exit;
                EOF};
        my @tmp_arr1 = split('\n',$mca_id);
        my $ncmca_id = "$tmp_arr1[3]";
        return $ncmca_id;
}
sub GetNCChannel{
	if(!(CheckDBString("$ATS_DB_STRING"))){
                Print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
        if(!(CheckTableExists("ATSD_MQM_NORMAL","$ATS_DB_STRING"))){
                Print("red",0,"ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
	my $nc_channel = qx {sqlplus -s $ATS_DB_STRING<< EOF
                SELECT MQ_CHANNEL FROM ATSD_MQM_NORMAL;
                exit;
                EOF};
	my @tmp_arr1 = split('\n',$nc_channel);
	my $ncchannel = "$tmp_arr1[3]";
	return $ncchannel;
}
sub GetX509_DN{
	my $dn_names = qx {sqlplus -s $ATS_DB_STRING<< EOF
		SELECT X509_DN from ATSD_OPN_NORMAL where SERVER_CHANNEL IS NOT NULL;
		exit;
                EOF};
	my @tmp_arr1 = grep { /\S/ } split('\n',$dn_names);
	@tmp_arr1 = grep {! /X509_DN/}@tmp_arr1;
	@tmp_arr1 = grep {! /----------/}@tmp_arr1;
        @tmp_arr1 = grep {! /rows selected/}@tmp_arr1;
	return @tmp_arr1;
}
sub GetPortOffsetfromDB{
	if(!(CheckDBString("$ATS_DB_STRING"))){
                Print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
	if(!(CheckTableExists("ATSD_MQM_NORMAL","$ATS_DB_STRING"))){
                Print("red",0,"ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
	my $mqportoffset = qx {sqlplus -s $ATS_DB_STRING<< EOF
		SELECT MQ_SERVER_PORT_OFFSET FROM ATSD_MQM_NORMAL;
		exit;
                EOF};
	my @tmp_arr1 = split('\n',$mqportoffset);
	my $mq_port = $tmp_arr1[3] + $MQ_BASE_PORT ;
	return $mq_port;
}

sub GetUsersfromDB{
        if(!(CheckDBString("$ATS_DB_STRING"))){
                Print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
        if(!(CheckTableExists("ATSD_OPN_NORMAL","$ATS_DB_STRING"))){
                Print("red",0,"ATSD_OPN_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_OPN_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
	my $membersNames = qx {sqlplus -s $ATS_DB_STRING<< EOF
                SELECT SERVER_CHANNEL, MCA_ID from ATSD_OPN_NORMAL where SERVER_CHANNEL IS NOT NULL;
                exit;
                EOF};
        my @tmp_arr1 = grep { /\S/ } split('\n',$membersNames);
        @tmp_arr1 = grep {! /MCA_ID/}@tmp_arr1;
        @tmp_arr1 = grep {! /----------/}@tmp_arr1;
        @tmp_arr1 = grep {! /rows selected/}@tmp_arr1;
        return @tmp_arr1;
}

sub GetQMANNamefromDB{
        if(!(CheckDBString("$ATS_DB_STRING"))){
                Print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
        if(!(CheckTableExists("ATSD_MQM_NORMAL","$ATS_DB_STRING"))){
                Print("red",0,"ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
        my $mqname = qx {sqlplus -s $ATS_DB_STRING<< EOF
                SELECT OBJECT_ID FROM ATSD_MQM_NORMAL;
                exit;
                EOF};
        my @tmp_arr1 = split('\n',$mqname);
        my $mqman_name = "$tmp_arr1[3]"."$MQ_SUFFIX";
        return $mqman_name;

}

sub CheckDBString
{
        my $tmp_db_string       = $_[0];
	$tmp_db_string=~ s/wallet:\/\//\/@/g;
	print $tmp_db_string."\n";
        my $results     = qx {sqlplus -s $tmp_db_string<< EOF
        exit ;
        EOF};
        if($results=~ m/^ERROR/)
        {
                return 0;
        }
        else
        {
                return 1;
        }
}

sub CheckTableExists
{
        my $METHOD = "CheckDBString";
        my $tmp_db_string       = $_[1];
        my $table_name = $_[0];
        my $sql = "SELECT TNAME FROM TAB WHERE TNAME='$table_name';";
        my $results     = qx {sqlplus -s $tmp_db_string<< EOF
        $sql
        exit;
        EOF};
        my @result_arr = split('\n',$results);
        if($result_arr[1] eq 'no rows selected')
        {
                return 0;
        }
        else
        {
                if($result_arr[1] eq 'TNAME')
                {
                        return 1;
                }
                else
                {
                        return -99
                }
        }
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
        if(-e "$LOGS_DIR/$LOG_FILE_NAME"){RenameWithDateTime("$LOGS_DIR/$LOG_FILE_NAME");}
        open ($LOG_FILE_FD, ">>$LOGS_DIR/$LOG_FILE_NAME") or DieFunc("Cannot open the log...!!!");
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

