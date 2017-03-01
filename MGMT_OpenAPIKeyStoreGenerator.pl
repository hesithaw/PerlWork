#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
#use DBI;
#use strict;
my $Version = 1.0;
my $RelDate = "2014/11/05";

my $SYSTEM_NAME = $ENV{'SYSTEM_NAME'};
my $SYSTEM_HOME = $ENV{'SYSTEM_HOME'};
my $PATH = $ENV{'PATH'};
my $LD_LIBRARY_PATH = $ENV{'LD_LIBRARY_PATH'};
my $LOGS_DIR = $ENV{'SYSTEM_LOGS'};
my $SCRIPT_NAME = "MGMT_OpenAPIKeyStoreGenerator";
my $LOG_FILE_NAME = $SYSTEM_NAME."_".$SCRIPT_NAME.".log";
my $LOG_FILE_FD;
my $MQ_SUFFIX = $ENV{'MQ_SUFFIX'}; 
my $ORACLE_HOME = $ENV{'ORACLE_HOME'};
my $ATS_DB_STRING = $ENV{'ATS_DB_STRING'};
$ATS_DB_STRING=~ s/wallet:\/\//\/@/g;
my $CA_NAME = "CertAuthority";
my $MQ_SYSTEM_NAME = $SYSTEM_NAME;	#this needs to be changed 

my $qman_IP = $ENV{'MQ_SERVER_IP_1'};
my $password = "nc123";
my $CommonMember = "CommonMember";
StartLog();
PrintLog("MGMT_OpenAPIKeyStoreGenerator.pl|$Version|$RelDate\n");
$ENV{'PATH'} = "$PATH:/opt/mqm/gskit8/bin:/opt/mqm/java/jre64/jre/bin/";
$ENV{'LD_LIBRARY_PATH'} = "$LD_LIBRARY_PATH:/opt/mqm/lib64/:/opt/mqm/gskit8/lib64";

#############################Creating CA and Certificate##########################
PrintLog("===================================START $CA_NAME=========================================");
if(!(MakeDirectory("../CA_KEYSTORE"))){
    PrintLog("Skipping generating KeyDB for CA");
	print "Skipping generating KeyDB for CA\n";
}
else{
        chdir "../CA_KEYSTORE" or DieFunc("Couldn't go inside $CA_NAME directory, $!");
        if(GenerateClientKeyDB($CA_NAME)){
		print "Keys created for CA\n";
		GenerateCASelfSignedCertificate($CA_NAME);
		my $ca_keyname = "$CA_NAME"."key.kdb";
		my $ExecuteString = "runmqckm -keydb -convert -db $ca_keyname -pw password -old_format cms -new_format JKS";
		my $status3 = `$ExecuteString`;
		PrintLog("$ExecuteString");
		if($status3){
			PrintLog("$status3");
			#exit(10);
		}
        PrintLog("jks created for $CA_NAME");
		my $status = `chmod g+rw *`;
	}
	chdir "../MGMT_SERVER_SCRIPTS" or DieFunc("Couldn't go to ../MGMT_SERVER_SCRIPTS directory, $!");
}
my $QMAN_NAME = GetQMANNamefromDB();
my @Clients = GetMembersfromDB();
my @Queues  = GetQueusfromDB();
PrintLog("===================================END $CA_NAME===========================================\n");
#############################Creating QMAN keys and sign certificate################
PrintLog("===================================START $QMAN_NAME=======================================");
        chdir "../MQ_SERVER_SCRIPTS/QMAN_KEYSTORE" or DieFunc("Couldn't go inside ../MQ_SERVER_SCRIPTS/QMAN_KEYSTORE directory, $!");
        if(GenerateQMANKeyDB("$QMAN_NAME")){
		print "Keys created for $QMAN_NAME\n";
		GenerateSignRquestforQMAN($QMAN_NAME);
		SignCertificateThroughCAforMQMan($QMAN_NAME);
		AddandReceiveCertificates($QMAN_NAME);
		CreateJKS($QMAN_NAME);
		my $status = `chmod g+rw *`;
		chdir "../../MGMT_SERVER_SCRIPTS" or DieFunc("Couldn't go to ../../MGMT_SERVER_SCRIPTS directory, $!");
	}

PrintLog("===================================END $QMAN_NAME=======================================\n");
#############################Creating Members' Keys ans sign certificates##########

$NC_MCA_ID = GetNCMCA_ID();
UpdateX509_DNfor_NC($NC_MCA_ID);
PrintLog("==================================START $NC_MCA_ID======================================\n");
if(!(MakeDirectory("../NC_SERVER_SCRIPTS/NC_KEYSTORE"))){
	PrintLog("Skipping generating KeyDB for $NC_MCA_ID");
	print "Skipping generating KeyDB for $NC_MCA_ID\n";
	chdir "../NC_SERVER_SCRIPTS/NC_KEYSTORE" or DieFunc("Couldn't go inside ../NC_SERVER_SCRIPTS/NC_KEYSTORE directory, $!");
	ChangeNCLabel();
	chdir "../../MGMT_SERVER_SCRIPTS" or DieFunc("Couldn't go outside directory, $!");
}
else{	
	MakeDirectory("../NC_SERVER_SCRIPTS/NC_KEYSTORE");
	chdir "../NC_SERVER_SCRIPTS/NC_KEYSTORE" or DieFunc("Couldn't go inside ../NC_SERVER_SCRIPTS/NC_KEYSTORE directory, $!");
	if(GenerateNCKeyDB($NC_MCA_ID)){
		print "Keys created for member $NC_MCA_ID\n";
		GenerateSignRquestforNC($NC_MCA_ID);
		SignCertificateThroughCAforNCUser($NC_MCA_ID);
		AddandReceiveCertificates($NC_MCA_ID);
	}
	chdir "../../MGMT_SERVER_SCRIPTS" or DieFunc("Couldn't go outside directory, $!");
}

PrintLog("==================================END $NC_MCA_ID======================================\n");
my $iCount = 0;
push(@Clients, $CommonMember);		
my $ClientCount = @Clients;
while ($iCount < $ClientCount){
	PrintLog("===================================START $client=======================================");
	$client = $Clients[$iCount];
	UpdateX509_DN($client);
	
	if(!(MakeDirectory("../MEMBER_KEYSTORES/$client"))){
		PrintLog("Skipping generating KeyDB for $client");
		print "Skipping generating KeyDB for $client\n";
	}
	else{
		chdir "../MEMBER_KEYSTORES/$client" or DieFunc("Couldn't go inside ../MEMBER_KEYSTORES/$client directory, $!");
		if(GenerateClientKeyDB($client)){
			print "Keys created for member $client\n";
			GenerateSignRquest($client);
			SignCertificateThroughCA($client);
			AddandReceiveCertificates($client);
			ShareandAddCertificatesforAMS($client);
			CreateJKS($client);
			CreateTestbed($client, $Queues[$iCount]);
			my $status = `chmod g+rw *`;
		}
		chdir "../" or DieFunc("Couldn't go outside directory, $!");
	}
	$iCount++;
	PrintLog("===================================END $client=======================================\n");
}
chdir "../NC_SERVER_SCRIPTS/NC_KEYSTORE" or DieFunc("Couldn't go inside ../NC_SERVER_SCRIPTS/NC_KEYSTORE directory, $!");
CreateJKS($NC_MCA_ID);
my $status = `chmod g+rw *`;
chdir "../../MGMT_SERVER_SCRIPTS" or DieFunc("Couldn't go inside ../../MGMT_SERVER_SCRIPTS, $!");
CloseLog();

sub GetQueusfromDB {
	if(!(CheckDBString("$ATS_DB_STRING"))){
		print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
		PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
		exit(10);
	}
	if(!(CheckTableExists("ATSD_OPN_NORMAL","$ATS_DB_STRING"))){
		print("red",0,"ATSD_OPN_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
		PrintLog("ATSD_OPN_NORMAL table cannot be found in ATS schema ! Exiting ...");
		exit(10);
    }
	my $QueueNames = qx {sqlplus -s $ATS_DB_STRING<< EOF
                SELECT OAPI_INPUT_QUEUE, OAPI_OUTPUT_QUEUE from ATSD_OPN_NORMAL;
                exit;
                EOF};	
	my @tmp_arr1 = grep { /\S/ } split('\n',$QueueNames);
    @tmp_arr1 = grep {! /OAPI_INPUT_QUEUE/}@tmp_arr1;
    @tmp_arr1 = grep {! /----------/}@tmp_arr1;
    @tmp_arr1 = grep {! /rows selected/}@tmp_arr1;
    return @tmp_arr1;			
}

sub ChangeNCLabel{
	my $NC_KEYDB_NAME = "$NC_MCA_ID"."key";
	my $labelInfo = `gsk8capicmd_64 -cert -list -db "$NC_MCA_ID"key.kdb -pw password`;
	my @tmp_arr1 = grep { /\S/ } split('\n',$labelInfo);
	@tmp_arr1 = grep {/ibmwebspheremq/}@tmp_arr1;
	@labels = split(' ',$tmp_arr1[0]);
	my $ExecutingString = "gsk8capicmd_64 -cert -rename -label \"$labels[1]\" -new_label \"ibmwebspheremq$SYSTEM_NAME\" -db $NC_KEYDB_NAME.kdb -pw password";
	my $status = `$ExecutingString`;
	PrintLog("$ExecutingString");
	PrintLog("$status");
	my $status2 = `gsk8capicmd_64 -cert -list -db $NC_KEYDB_NAME.kdb -pw password`;
	PrintLog("$status2");
}
sub CreateTestbed{
	my $NC_KEYDB_NAME = "$NC_MCA_ID"."key";
	my $CommonMember_KEYDB_NAME = "$CommonMember"."key";
	my @QueueArray = split(' ', $_[1]);
	my $InQueue = $QueueArray[0];
	my $OutQueue = $QueueArray[1];
	my $TestFileName = "$_[0]"."test.sh";
	my $TestFileFD ;
	open ($TestFileFD, "+>$TestFileName") or DieFunc("Cannot open the $TestFileName...!!!");
	print $TestFileFD "#!/bin/bash\n";
	print $TestFileFD "echo \"REFRESH SECURITY TYPE(SSL)\"  | runmqsc $QMAN_NAME\n";
	print $TestFileFD "export PATH=\$PATH:/opt/mqm/samp/bin/\n";
	print $TestFileFD "export MQCHLLIB=/var/mqm/qmgrs/$QMAN_NAME/\@ipcc\n";
	print $TestFileFD "export MQCHLTAB=AMQCLCHL.TAB\n";
	print $TestFileFD "export MQSSLKEYR=\$HOME/mq_scripts/Security/NC_SERVER_SCRIPTS/NC_KEYSTORE/$NC_KEYDB_NAME\n";
	print $TestFileFD "echo \"cms.keystore = $SYSTEM_HOME/mq_scripts/Security/NC_SERVER_SCRIPTS/NC_KEYSTORE/$NC_KEYDB_NAME
			cms.certificate = ibmwebspheremq$SYSTEM_NAME\" >   ~/.mqs/keystore.conf\n";
	print $TestFileFD "echo \"### put [Hi. im $NC_MCA_ID for $_[0]] to $OutQueue\"\n";
	print $TestFileFD "echo \"Hi. im $NC_MCA_ID for $_[0] \" | amqsputc $OutQueue  $QMAN_NAME\n";
	print $TestFileFD "export MQSSLKEYR=\$HOME/mq_scripts/Security/MEMBER_KEYSTORES/$_[0]/$_[0]key\n";
	print $TestFileFD "echo \"cms.keystore = $SYSTEM_HOME/mq_scripts/Security/MEMBER_KEYSTORES/$CommonMember/$CommonMember_KEYDB_NAME
					cms.certificate = ibmwebspheremq$SYSTEM_NAME\" >   ~/.mqs/keystore.conf \n";
	print $TestFileFD "echo \"### get [Hi. im $NC_MCA_ID for $_[0]] from $OutQueue\"\n";
	print $TestFileFD "amqsgetc $OutQueue  $QMAN_NAME\n";
	print $TestFileFD "echo \"### put [Hi. im $_[0] for $NC_MCA_ID] to $InQueue\"\n";
	print $TestFileFD "echo \"Hi. im $_[0] for $NC_MCA_ID\" | amqsputc $InQueue  $QMAN_NAME\n";
	print $TestFileFD "export MQSSLKEYR=\$HOME/mq_scripts/Security/NC_SERVER_SCRIPTS/NC_KEYSTORE/$NC_KEYDB_NAME\n";
	print $TestFileFD "echo \"cms.keystore = $SYSTEM_HOME/mq_scripts/Security/NC_SERVER_SCRIPTS/NC_KEYSTORE/$NC_KEYDB_NAME
			cms.certificate = ibmwebspheremq$SYSTEM_NAME\" >   ~/.mqs/keystore.conf\n";
	print $TestFileFD "echo \"### get [Hi. im $_[0] for $NC_MCA_ID] from $InQueue\"\n";	
	print $TestFileFD "amqsgetc $InQueue $QMAN_NAME\n";	
	close $TestFileFD ;
	`chmod 775 "$_[0]""test.sh"`; 
}

sub ShareandAddCertificatesforAMS{
	my $lc_client = lc($_[0]);
	my $status1 = `cp $_[0].crt ../../NC_SERVER_SCRIPTS/NC_KEYSTORE`;
	chdir "../../NC_SERVER_SCRIPTS/NC_KEYSTORE" or DieFunc("Couldn't go inside ../../NC_SERVER_SCRIPTS/NC_KEYSTORE directory, $!");
	my $label_member = "$lc_client".".pub.cert";
	my $NCkey_name = "$NC_MCA_ID"."key.kdb";
	my $ExecuteString1 = "gsk8capicmd_64 -cert -add -db \"$NCkey_name\" -pw password -label $label_member -file $_[0].crt -format ascii -trust enable";
	my $status2 = `$ExecuteString1`;
	PrintLog("$ExecuteString1");
	if($status2){
                PrintLog("$status2");
                exit(10);
        }
	my $status3 = `cp $NC_MCA_ID.crt ../../MEMBER_KEYSTORES/$_[0]`;
	chdir "../../MEMBER_KEYSTORES/$_[0]" or DieFunc("Couldn't go inside ../../MEMBER_KEYSTORES/$_[0] directory, $!");
	my $label_NC = "$NC_MCA_ID".".pub.cert";
	my $ExecuteString2 = "gsk8capicmd_64 -cert -add -db \"$_[0]key.kdb\" -pw password -label $label_NC -file $NC_MCA_ID.crt -format ascii -trust enable";
	my $status4 = `$ExecuteString2`;
	PrintLog("$ExecuteString2");
	if($status4){
                PrintLog("$status4");
                #exit(10);
        }
	my $status5 = `gsk8capicmd_64 -cert -list -db $_[0]key.kdb -pw password`;
	PrintLog("$status5");	
	PrintLog("AMS : Certificates shared and added successfully for $_[0]");
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

sub AddandReceiveCertificates{
	my $ExecuteString = "gsk8capicmd_64 -cert -add -db \"$_[0]key.kdb\" -pw password -label $CA_NAME -file $CA_NAME.crt -format ascii -trust enable";
	my $status1 = `$ExecuteString`;
	PrintLog("$ExecuteString");
	if($status1){
        PrintLog("$status1");
		exit(10);
        }
	my $ExecuteString2 = "gsk8capicmd_64 -cert -receive -db \"$_[0]key.kdb\" -pw password -file $_[0].crt -format ascii";
	my $status2 = `$ExecuteString2`;
	PrintLog("$ExecuteString2");
	if($status2){
                PrintLog("$status2");
		exit(10);
        }
	my $status3 = `gsk8capicmd_64 -cert -list -db "$_[0]key.kdb" -pw password`;
	PrintLog("$status3");
	PrintLog("Certificates added successfully for $_[0]");
}
sub CreateJKS{
	my $status3 = `runmqckm -keydb -convert -db $_[0]key.kdb -pw password -old_format cms -new_format JKS`;
        if($status3){
                PrintLog("$status3");
                exit(10);
        }
        PrintLog("jks created for $_[0]");
}
sub SignCertificateThroughCAforNCUser{
	my $status1 = `cp $_[0].req ../../CA_KEYSTORE`;
	chdir "../../CA_KEYSTORE" or DieFunc("Couldn't go inside $CA_NAME directory, $!");
	my $CAkey_name = "$CA_NAME"."key.kdb";
	my $ExecuteString1 = "gsk8capicmd_64 -cert -sign -file $_[0].req -db \"$CAkey_name\" -pw password -label $CA_NAME -target $_[0].crt -format ASCII -expire 366 -sigalg sha256";
	my $status2 = `$ExecuteString1`;
	PrintLog("$ExecuteString1");
	if($status2){
			PrintLog("$status2");
			exit(10);
	}
	my $status3 = `cp $_[0].crt "$CA_NAME".crt ../NC_SERVER_SCRIPTS/NC_KEYSTORE`;
	chdir "../NC_SERVER_SCRIPTS/NC_KEYSTORE" or DieFunc("Couldn't go inside MQ_SERVER_SCRIPTS/QMAN_KEYSTORE directory, $!");
	PrintLog("Generated $_[0].crt signed Certificate for $_[0]");
	#UpdateX509_DNfor_NC($_[0]);
}
sub SignCertificateThroughCAforMQMan{
	my $status1 = `cp $_[0].req ../../CA_KEYSTORE`;
	chdir "../../CA_KEYSTORE" or DieFunc("Couldn't go inside $CA_NAME directory, $!");
	my $CAkey_name = "$CA_NAME"."key.kdb";
	my $ExecuteString1 = "gsk8capicmd_64 -cert -sign -file $_[0].req -db \"$CAkey_name\" -pw password -label $CA_NAME -target $_[0].crt -format ASCII -expire 366 -sigalg sha256";
	my $status2 = `$ExecuteString1`;
	PrintLog("$ExecuteString1"); 
	if($status2){
                PrintLog("$status2");
                exit(10);
        }
	my $status3 = `cp $_[0].crt "$CA_NAME".crt ../MQ_SERVER_SCRIPTS/QMAN_KEYSTORE`;
	chdir "../MQ_SERVER_SCRIPTS/QMAN_KEYSTORE" or DieFunc("Couldn't go inside MQ_SERVER_SCRIPTS/QMAN_KEYSTORE directory, $!");
	PrintLog("Generated $_[0].crt signed Certificate for $_[0]");
}
sub SignCertificateThroughCA{
	my $status1 = `cp $_[0].req ../../CA_KEYSTORE`;
	chdir "../../CA_KEYSTORE" or DieFunc("Couldn't go inside ../../CA_KEYSTORE directory, $!");
	my $CAkey_name = "$CA_NAME"."key.kdb";
	my $ExecuteString1 = "gsk8capicmd_64 -cert -sign -file $_[0].req -db \"$CAkey_name\" -pw password -label $CA_NAME -target $_[0].crt -format ASCII -expire 366 -sigalg sha256";
	my $status2 = `$ExecuteString1`; 
	PrintLog("$ExecuteString1");
	if($status2){
		PrintLog("$status2");
		exit(10);
	}
	my $status3 = `cp $_[0].crt "$CA_NAME".crt ../MEMBER_KEYSTORES/$_[0]`;
	chdir "../MEMBER_KEYSTORES/$_[0]" or DieFunc("Couldn't go inside $_[0] directory, $!");
	PrintLog("Generated $_[0].crt signed Certificate for $_[0]");
}
sub GenerateSignRquestforNC{
	my $label = "ibmwebspheremq"."$SYSTEM_NAME";
	my $ExecuteString1 = "gsk8capicmd_64 -certreq -create -db \"$_[0]key.kdb\" -pw password -label $label -dn \"CN=$_[0],OU=PT,C=SL\" -file $_[0].req -sigalg sha256";
	my $status1 = `$ExecuteString1`;
	PrintLog("$ExecuteString1");
	if($status1){
			PrintLog("$status1");
			exit(10);
	}
	PrintLog("Generated $_[0].req sign request for $_[0]");
}	
sub GenerateSignRquestforQMAN{
	my $lcname = lc$_[0];	
	my $label = "ibmwebspheremq"."$lcname";
	my $ExecuteString1 = "gsk8capicmd_64 -certreq -create -db \"$_[0]key.kdb\" -pw password -label $label -dn \"CN=$_[0],OU=PT,C=SL\" -file $_[0].req -sigalg sha256";
	my $status1 = `$ExecuteString1`;
	PrintLog("$ExecuteString1");
	if($status1){
                PrintLog("$status1");
		exit(10);
        } 
	PrintLog("Generated $_[0].req sign request for $_[0]");
}
sub GenerateSignRquest{
	my $lcname = lc$_[0];	
	my $label = "ibmwebspheremq"."$SYSTEM_NAME";
	my $ExecuteString1 = "gsk8capicmd_64 -certreq -create -db \"$_[0]key.kdb\" -pw password -label $label -dn \"CN=$_[0],OU=PT,C=SL\" -file $_[0].req -sigalg sha256";
	my $status1 = `$ExecuteString1`;
	PrintLog("$ExecuteString1");
	if($status1){
                PrintLog("$status1");
		exit(10);
        } 
	PrintLog("Generated $_[0].req sign request for $_[0]");
}
sub UpdateX509_DN{
	my $dn_string = "CN=$_[0],OU=PT,C=SL";
	my $update_status = qx {sqlplus -s $ATS_DB_STRING<< EOF
		UPDATE ATSD_OPN_NORMAL SET X509_DN='$dn_string' WHERE OBJECT_ID='$_[0]';
		exit;
		EOF};
	PrintLog("Updated X509_DN of $_[0]");	
}
sub UpdateX509_DNfor_NC{
	my $dn_string = "CN=$_[0],OU=PT,C=SL";
	my $update_status = qx {sqlplus -s $ATS_DB_STRING<< EOF
		UPDATE ATSD_MQM_NORMAL SET X509_DN='$dn_string' WHERE OBJECT_ID='QMPTS';
		exit;
        EOF};
}
sub GenerateCASelfSignedCertificate{
	my $ExecuteString1 = "gsk8capicmd_64 -cert -create -db \"$_[0]key.kdb\" -pw password -label $_[0] -dn \"CN=$_[0],O=MIT,OU=PT,L=MLB,C=SL\" -expire 365 -sigalg sha256 -size 3072";
	my $status1 = `$ExecuteString1`;
	PrintLog("$ExecuteString1");
	if($status1){
		PrintLog("$status1");
		exit(10);
	}
	my $ExecuteString2 = "gsk8capicmd_64 -cert -extract -db \"$_[0]key.kdb\" -pw password -label $_[0] -target $_[0].crt -format ascii";
	my $status2 = `$ExecuteString2`;
	PrintLog("$ExecuteString2");
	if($status2){
                PrintLog("$status2");
		exit(10);
        }
	my $ExecuteString3 = "gsk8capicmd_64 -cert -list -db \"$_[0]key.kdb\" -pw password";
	my $status3 = `$ExecuteString3`;
	PrintLog("$ExecuteString3");
	PrintLog("$status3");
	PrintLog("Generated $_[0].crt selfsigned certificate for CA");
}
sub GetMembersfromDB{
	if(!(CheckDBString("$ATS_DB_STRING"))){
                print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
                PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
                exit(10);
        }
	if(!(CheckTableExists("ATSD_OPN_NORMAL","$ATS_DB_STRING"))){
                print("red",0,"ATSD_OPN_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
                PrintLog("ATSD_OPN_NORMAL table cannot be found in ATS schema ! Exiting ...");
                exit(10);
        }
	#my $dbh = DBI->connect('DBI:MYSQL:newcdev50', 'newcdev50', 'newcdev50' ) or die $DBI::errstr;
	my $membersNames = qx {sqlplus -s $ATS_DB_STRING<< EOF
		SELECT OBJECT_ID FROM ATSD_OPN_NORMAL;
		exit;
		EOF};
	my @tmp_arr1 = grep { /\S/ } split('\n',$membersNames);
	@tmp_arr1 = grep {! /OBJECT_ID/}@tmp_arr1;
	@tmp_arr1 = grep {! /----------/}@tmp_arr1;
	@tmp_arr1 = grep {! /rows selected/}@tmp_arr1;
	return @tmp_arr1;
}
sub GetQMANNamefromDB{
	if(!(CheckDBString("$ATS_DB_STRING"))){
		print("red",0,"Cannot login using ATS_DB_STRING ! Exiting ...\n");
		PrintLog("Cannot login using ATS_DB_STRING ! Exiting ...");
		exit(10);
	}
	if(!(CheckTableExists("ATSD_MQM_NORMAL","$ATS_DB_STRING"))){
		print("red",0,"ATSD_MQM_NORMAL table cannot be found in ATS schema ! Exiting ...\n");
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

sub CheckDBString
{
        my $tmp_db_string       = $_[0];
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
sub MakeDirectory{
	my $dir = $_[0] ;
	if(mkdir( $dir )){ 
		PrintLog("Directory $dir created successfully");
		print "Directory $dir created successfully\n";
		return 1;
	}
	else{
		PrintLog("Directory $dir has already been created");
		return 0;
	}
		
}
sub GenerateNCKeyDB{
	PrintLog("Generating Key database for $_[0]");
    system ("rm * -f");
	my $ExecuteString1 = "gsk8capicmd_64 -keydb -create -db \"$_[0]key.kdb\" -pw password -type cms -expire 365 -stash";
    my $status = system("$ExecuteString1");
	PrintLog("$ExecuteString1");
	if($status/256 == 0){
			PrintLog("Generated $_[0]key.kdb database successfully");
			return 1;
	}
	return 0;
}
sub GenerateClientKeyDB{
	
	PrintLog("Generating Key database for $_[0]");
	system ("rm * -f");
	my $ExecuteString1 = "gsk8capicmd_64 -keydb -create -db \"$_[0]key.kdb\" -pw password -type cms -expire 365 -stash";
	my $status = system("$ExecuteString1");
	PrintLog("$ExecuteString1");
	if($status/256 == 0){
		PrintLog("Generated $_[0]key database successfully");
		return 1;
	}	
	return 0;
}
sub GenerateQMANKeyDB{
	PrintLog("Generating Key database for $_[0]");
    system ("rm * -f");
	my $ExecuteString1 = "gsk8capicmd_64 -keydb -create -db \"$_[0]key.kdb\" -pw password -type cms -expire 365 -stash";
	my $status = system("$ExecuteString1");
	PrintLog("$ExecuteString1");
	if($status/256 == 0){
		PrintLog("Generated $_[0]key database successfully");
		return 1;
    }       
    return 0;	
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
