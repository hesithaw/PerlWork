#!/usr/bin/perl
use Cwd;
use Cwd 'abs_path';
use strict;

my $Version = 1.0;
my $RelDate = "2014/11/21";

my $ArraySize = scalar(@ARGV);
if($ArraySize == 0){
        print "Usage : [SECURITY(yes/no)] [LOCAL_GW_MQ_SCRIPTS(yes/no)]\n";
}
elsif($ArraySize == 1){
	my $IssecurityEnabled = $ARGV[0];
	if($IssecurityEnabled eq 'yes'){
		my $MITUserScriptGenerator = `MITUserScriptGenerator.pl`;
		my $OpenAPIKeyStoreGenerator = `MGMT_OpenAPIKeyStoreGenerator.pl`;
		my $UNIXUserIDFileGenerator = `MGMT_UNIXUserIDFileGenerator.pl`;
		my $ServerChannelConfigurationFileGenerator = `MGMT_ServerChannelConfigurationFileGenerator.pl`;
		my $QueueConfigurationFileGenerator = `MGMT_QueueConfigurationFileGenerator.pl`;
	}
	elsif($IssecurityEnabled eq 'no'){
		my $MITUserScriptGenerator = `MITUserScriptGenerator.pl`;
	}
}
else{
        print "Invalid Arguments ! \nUsage : [SECURITY(yes/no)] [LOCAL_GW_MQ_SCRIPTS(yes/no)]\n";
}



