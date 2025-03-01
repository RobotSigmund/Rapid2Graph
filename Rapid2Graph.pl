#!c:/perl/bin/perl

use strict;
use warnings;

use Time::Local;
use Win32;


our($APP_NAME) = 'Rapid2Graph_V2';
our($APP_REV) = 'rev2023-09-22';
our($APP_AUTH) = 'Sigmund Straumland';
our($APP_USER) = Win32::LoginName() || "Unknown";
our($APP_USER_MACHINE) = Win32::NodeName() || "Unknown";
our($APP_WEB) = 'http://www.straumland.com';

our($CFG_HIDE_IGNORED_NODES) = 1;


print $APP_NAME.' '.$APP_REV."\n";
print 'By '.$APP_AUTH.' - '.$APP_WEB."\n";
print "---\n\n";



# Find latest backup according to backinfo.txt
our($BACKUP_TIME) = time();
our($BACKUP_ID) = '';
our($BACKUP_RW) = '';
print 'Found backups:'."\n";
my($BACKUP_FOLDER) = BackupFindMostRecent('.');
print 'Most recent backup folder found:'.$BACKUP_FOLDER."\n\n";



# @TASK_LIST will contain indexes of 'TASKn;<TaskName>'
our(@TASK_LIST) = BackupFindTaskList($BACKUP_FOLDER);
print 'Found tasks:'."\n";
my($i);
foreach $i (0..$#TASK_LIST) {
	print $TASK_LIST[$i]."\n";
}
print "\n";



# Look for entry points if changed from 'Main'
BackupFindTaskEntryPoints($BACKUP_FOLDER);
print 'Found entry points:'."\n";
foreach $i (0..$#TASK_LIST) {
	print $TASK_LIST[$i]."\n";
}
print "\n";



# Look for EVENT routines in system parameters
# @EVENT_ROUTINE_LIST will contain entries like <EventRoutineName;Action;Task>
our(@EVENT_ROUTINE_LIST) = ();
BackupFindEventRoutines($BACKUP_FOLDER);
print 'Found event routines:'."\n";
foreach (@EVENT_ROUTINE_LIST) {
	print $_."\n";
}
print "\n";



our(%FILEDATA);
my(@PROG_MODULES) = BackupFindProgModules($BACKUP_FOLDER);
print 'Found modules:'."\n";
foreach $i (0..$#PROG_MODULES) {
	print $PROG_MODULES[$i]."\n";
}
print "\n";



our(@DECL_ROUTINES) = BackupFindDeclRoutines($BACKUP_FOLDER,@PROG_MODULES);
# %VERIFIED_ROUTINES does nothing, but will tag all routines containing /^!\s*Verified/. These will be outlined in the final graph as OK.
our(%VERIFIED_ROUTINES) = ();
print 'Found procedures:'."\n";
foreach $i (0..$#DECL_ROUTINES) {
	print $i.':'.$DECL_ROUTINES[$i]."\n";
}
print "\n";



our(@CHK_ROUTINES);
our(@CONNECTIONS);
our(@WARNING_LATEBINDING);
our(%PROCESSED_ROUTINES);
our(%UNUSED_ROUTINES);
print 'Reading routines...'."\n";
BackupFindRoutineCalls($BACKUP_FOLDER);



print "\n".'Remove duplicate connections'."\n";
RemoveDuplicateEdges();



print "\n".'Generating GraphML file'."\n";
generate_graphml($BACKUP_FOLDER);



if (scalar %VERIFIED_ROUTINES) {
	print "\n".'Generating "Verified"-list'."\n\n";
	open(FILE,'>'.$BACKUP_FOLDER.'_verified.log');
	foreach (@DECL_ROUTINES) {
		my(@decl_info) = split(/;/,$_);
		if ($VERIFIED_ROUTINES{$decl_info[0].'/'.$decl_info[1].'/'.$decl_info[2]}) {
			print FILE '1;';
		} else {
			print FILE '0;';
		}
		print FILE $decl_info[0].';'.$decl_info[1].';'.$decl_info[2].';';
		print FILE "\n";
	}
	close(FILE);
}



print 'Procedures containing possible unadressed late-bind calls:'."\n";
foreach $i (0..$#WARNING_LATEBINDING) {
	print '  '.$WARNING_LATEBINDING[$i]."\n";
}
if ($#WARNING_LATEBINDING < 0) {
	print '<None found>'."\n";
} else {
	print "\n".'To include late-bind calls into exec chart, use'."\n";
	print 'the following comment anywhere in the late-bind routine:'."\n";
	print '  ! Rapid2Graph [Routine1,Routine2,Routine3,...]'."\n";
	print 'or you can specify LOCAL declared routine out of scope like this:'."\n";
	print '  ! Rapid2Graph [SomeModule.mod:Routine1,SomeOtherModule.mod:Routine2,Routine3,...]'."\n";
}



print "\n".$APP_NAME.' '.$APP_REV."\n";
print 'By '.$APP_AUTH.' - '.$APP_WEB."\n";



print "\n".'Done'."\n";
<STDIN>;



exit;



sub RemoveDuplicateEdges {
	print '  Size:'.$#CONNECTIONS."\n";
	my($i) = 0;
	my($j) = 0;
	while ($i<$#CONNECTIONS) {
		$j = $i + 1;
		while ($j<=$#CONNECTIONS) {
			if ($CONNECTIONS[$i] eq $CONNECTIONS[$j]) {
				splice(@CONNECTIONS,$j,1);
			} else {
				$j++;
			}
		}
		$i++;
	}
	print '  New size:'.$#CONNECTIONS."\n";
}



sub BackupFindRoutineCalls {
	my($folder) = @_;
	my($i,$j,$task,$task_name,$task_entry,$list_task,$decl_file,$decl_all,$decl_local,$decl_type,$decl_name);
	
	# Start with Main() (or task entry point)
	foreach $i (0..$#TASK_LIST) {
		($task,$task_name,$task_entry) = split(/;/,$TASK_LIST[$i]);
		foreach $j (0..$#DECL_ROUTINES) {
			($list_task,$decl_file,$decl_all,$decl_local,$decl_type,$decl_name) = split(/;/,$DECL_ROUTINES[$j]);
			if (($task eq $list_task) && (lc($task_entry) eq lc($decl_name)) && ($decl_local eq '') && (uc($decl_type) eq 'PROC')) {
				Add_Connections($folder,$j);
			}
		}
	}
	
	# Also perform a "start" with all defined event-routines.
	my($eventroutine, $eventaction, $eventtask, $taskn, $taskname, $alltask);
	foreach (@EVENT_ROUTINE_LIST) {
		($eventroutine, $eventaction, $eventtask) = split(/;/, $_);
		foreach (@TASK_LIST) {
			($taskn, $taskname) = split(/;/, $_);
			if ($taskname eq $eventtask) {
				last;
			}
		}
		
		foreach $j (0..$#DECL_ROUTINES) {
			($list_task, $decl_file, $decl_all, $decl_local, $decl_type, $decl_name) = split(/;/,$DECL_ROUTINES[$j]);
			if (($taskn eq $list_task) && (lc($eventroutine) eq lc($decl_name)) && ($decl_local eq '') && (uc($decl_type) eq 'PROC')) {
				Add_Connections($folder,$j);
			}
		}
	}
	
	# Unused routines will also be traversed.
	# $PROCESSED_ROUTINES{$key} = $value : [$keys=index-@DECL_ROUTINES, $value=1]
	# @DECL_ROUTINES : <$from_task,$from_file,$from_all,$from_local,$from_type,$from_name>
	# First iteration tags all unused routines, we then process these and preserve the tags for
	# graphml formatting.
	foreach $j (0..$#DECL_ROUTINES) {
		if ($PROCESSED_ROUTINES{$j}) {
			# Do nothing
		} else {
			# Tag as non-used and add-connections
			$UNUSED_ROUTINES{$j} = 1;
		}			
	}
	foreach $j (0..$#DECL_ROUTINES) {
		if ($PROCESSED_ROUTINES{$j}) {
			# Do nothing
		} else {
			# Tag as non-used and add-connections
			Add_Connections($folder,$j);
		}			
	}
	
}



sub Add_Connections {
	my($folder,$i) = @_;

	my($from_task,$from_file,$from_all,$from_local,$from_type,$from_name) = split(/;/,$DECL_ROUTINES[$i]);

	# If this routine has been processed, early exit
	if ($PROCESSED_ROUTINES{$i}) {
		# Allready done
		#print '[Allready done:'.$i.']';
		return;
	}
	$PROCESSED_ROUTINES{$i} = 1;
	
	my(@PROCESSED_ROUTINES_keys) = keys %PROCESSED_ROUTINES;
	print $#PROCESSED_ROUTINES_keys.'/'.$#DECL_ROUTINES.' ';
	if ($#DECL_ROUTINES != 0) {
		print int($#PROCESSED_ROUTINES_keys / $#DECL_ROUTINES * 100).'% ';
	}
	print $from_file.', '.$from_all."\n";

	my($line);
	my($procedure_data) = '';
	
	# Read until we find the correct procedure declaration
	my($m) = 0;
	while ($m <= $#{$FILEDATA{$folder.$from_file}}) {
		$line = ${$FILEDATA{$folder.$from_file}}[$m];
		$m++;
		if ($line =~ /^[\s\t]*\Q$from_all\E[^\w\d_]/) {
			last;
		}
	}
	# Read routine
	my($latebinding_found) = 0;
	my($latebinding_addressed) = 0;
	my($j,$k,$to_task,$to_file,$to_all,$to_local,$to_type,$to_name,@routine_array);
	while ($m <= $#{$FILEDATA{$folder.$from_file}}) {
		$line = ${$FILEDATA{$folder.$from_file}}[$m];
		$m++;

		if ($line =~ /^[\t\s]*!\s*Verified/i) {
			$VERIFIED_ROUTINES{$from_task.'/'.$from_file.'/'.$from_all} = 1;
		}
		if (($line =~ /^[\t\s]*\%.+\%.*;/) || ($line =~ /([^\w\d_]|^)CallByVar[^\w\d_]/)) {
			$latebinding_found = 1;
		}
		if ($line =~ /!\s+Rapid2Graph\s+\[(.+)\]/) {
			$latebinding_addressed = 1;
			@routine_array = split(/,/,$1);
			foreach $k (0..$#routine_array) {

				CheckConnectionMatch($routine_array[$k],$from_task,$from_file,$folder,$i);
				
			}
		}
		
		# Check for MoveLJCSync late bind before we remove strings and other junk
		if ($line =~ /Move(L|J|C)Sync.*"(.+?)";/i) {
			CheckConnectionMatch($2,$from_task,$from_file,$folder,$i);
		} elsif ($line =~ /Move(L|J|C)Sync\W/i) {
			# Likely a latebindcall
			$latebinding_found = 1;
		}

		# Cleanup line of code
		# declared text
		$line =~ s/(\".*?\")//g;
		# Remove comments
		$line =~ s/!.*$//;
		# Remove startjunk
		$line =~ s/^[\s\t]*//;
		# Remove endjunk
		$line =~ s/[\s\t\r\n]*$//;
		# Shorten all multispace to singlespace
		$line =~ s/\s+/ /g;
		
		# If empty line trynext
		if ($line eq '') {
			next;
		}
		
		# Break loop if we find end of procedure
		if ($line =~ /^[\s\t]*(ERROR|UNDO|ENDPROC|ENDFUNC|ENDTRAP)([^\w\d_]|$)/i) {
			last;
		} else {
			$procedure_data .= $line."\n";
		}
	}

    # First check for any local matches
    my(%LOCAL_MATCHES);
    grep {
        ($to_task,$to_file,$to_all,$to_local,$to_type,$to_name) = split(/;/,$DECL_ROUTINES[$_]);
        $to_task eq $from_task && $to_file eq $from_file &&
		$procedure_data =~ /([^\w\d_]|^)\Q$to_name\E[^\w\d_]/mi &&
		($LOCAL_MATCHES{$to_name} = 1) &&
		(push(@CONNECTIONS, "$i;$_"), Add_Connections($folder, $_));
    } (0..$#DECL_ROUTINES);

    # If no local matches, search for global matches
    grep {
        ($to_task,$to_file,$to_all,$to_local,$to_type,$to_name) = split(/;/,$DECL_ROUTINES[$_]);
        $to_task eq $from_task &&
		(!$to_local || $to_file eq $from_file) &&
		!defined($LOCAL_MATCHES{$to_name}) &&
		$procedure_data =~ /([^\w\d_]|^)\Q$to_name\E[^\w\d_]/mi &&
		(push(@CONNECTIONS, "$i;$_"), Add_Connections($folder, $_));
    } (0..$#DECL_ROUTINES);
	
	if (($latebinding_found == 1) && ($latebinding_addressed == 0)) {
		push(@WARNING_LATEBINDING,$from_file.'/'.$from_name);
	}
	
	# For debugging. Will output specified routine content to out2.log
	if ($from_name eq 'ChangeGun') {
		open(FILE,'>out3.log');
		print FILE $procedure_data;
		close(FILE);
	}
	
}



sub CheckConnectionMatch {
    my($text, $from_task, $from_file, $folder, $i) = @_;
    my($to_task, $to_file, $to_all, $to_local, $to_type, $to_name);

    # Remove quotes from line if detected
    $text =~ s/"[^"]*"//g;
	
	# Remote ProCall to LOCAL declared?
	if ($text =~ /([\w\d_\.]+)\:([\w\d_]+)/) {
		my($remote_module) = $1;
		my($remote_procedure) = $2;
		
		my(@remote_matches) = grep {
			($to_task,$to_file,$to_all,$to_local,$to_type,$to_name) = split(/;/,$DECL_ROUTINES[$_]);
			$to_task eq $from_task &&
			(($to_file eq '/RAPID/'.$from_task.'/PROGMOD/'.$remote_module) || ($to_file eq '/RAPID/'.$from_task.'/SYSMOD/'.$remote_module)) &&
			$remote_procedure eq $to_name
		} (0..$#DECL_ROUTINES);
		
		#print '  DEBUG:'.$text.',/RAPID/'.$from_task.'/(PROGMOD|SYSMOD)/'.$remote_module.','.$remote_procedure.' Matches:'.$#remote_matches."\n";
		#foreach (@DECL_ROUTINES) {
		#	($to_task,$to_file,$to_all,$to_local,$to_type,$to_name) = split(/;/,$_);
		#	print '  '.$to_task.'='.$from_task.' && '.$to_file.'=~/RAPID/'.$from_task.'/(PROGMOD|SYSMOD)/'.$remote_module.' && '.$remote_procedure.'='.$to_name;
		#	if ($to_task eq $from_task &&
		#		$to_file =~ /\/RAPID\/$from_task\/(PROGMOD|SYSMOD)\/$remote_module/ &&
		#		$remote_procedure eq $to_name) {
		#		print ' MATCH';
		#	} else {
		#		print ' no match';
		#	}
		#	print "\n";
		#}
		
		# Match?
		if (@remote_matches) {
			push(@CONNECTIONS,$i.';'.$remote_matches[0]);
			Add_Connections($folder,$remote_matches[0]);
			return;
		}
	}


    # First check for any local matches
    my(@local_matches) = grep {
        ($to_task,$to_file,$to_all,$to_local,$to_type,$to_name) = split(/;/,$DECL_ROUTINES[$_]);
        $to_task eq $from_task &&
		$to_file eq $from_file &&
		$text eq $to_name
	} (0..$#DECL_ROUTINES);
	
	# Match?
	if (@local_matches) {
		push(@CONNECTIONS,$i.';'.$local_matches[0]);
		Add_Connections($folder,$local_matches[0]);
		return;
	}

    # If no local matches, search for global matches
    my(@global_matches) = grep {
        ($to_task,$to_file,$to_all,$to_local,$to_type,$to_name) = split(/;/,$DECL_ROUTINES[$_]);
        $to_task eq $from_task &&
		(!$to_local || $to_file eq $from_file) &&
		$text eq $to_name
    } (0..$#DECL_ROUTINES);

	# Match?
	if (@global_matches) {
		push(@CONNECTIONS,$i.';'.$global_matches[0]);
		Add_Connections($folder,$global_matches[0]);
		return;
	}
	
    # No matches
}



sub BackupFindDeclRoutines {
	my($folder,@PROG_MODULES) = @_;
	my($ignored);
	my(@DECL_ROUTINES);
	my($i,$line,$FILE,$decl_all,$decl_local,$decl_type,$decl_name,$list_task,$list_file);
	foreach $i (0..$#PROG_MODULES) {
		($list_task,$list_file) = split(/;/,$PROG_MODULES[$i]);

		$ignored = 0;
		foreach $line (@{$FILEDATA{$folder.$list_file}}) {
			if ($line =~ /!\s*Rapid2Graph\s+Ignore/i) {
				# Everything after this point should be ignored, so we add a suffix to differentiate
				$ignored = 1;
			}
			$decl_all = '';
			$decl_local = '';
			$decl_type = '';
			$decl_name = '';
			#if ($line =~ /^[\s\t]*(((LOCAL)\s+)?(PROC|FUNC\s+[\w\d_]+|TRAP)\s+([\w\d_]+))/i) {
			if ($line =~ /^[\s\t]*(((LOCAL)\s+)?(PROC|FUNC\s+[\w\d_]+|TRAP)\s+([^\(]+))(\(|\n|\r|$)/i) {
				
				$decl_all = $1 if ($1);
				$decl_local = $3 if ($3);
				$decl_type = $4 if ($4);
				$decl_name = $5 if ($5);
				$decl_all =~ s/\s+/ /g;
				$decl_type =~ s/\s+/ /g;
				if ($ignored) {
					$decl_all .= '_(Ignored)';
					$decl_name .= '_(Ignored)';
				}
				
				# Remove trailing junk
				chomp($decl_all);
				chomp($decl_name);
				$decl_all =~ s/[\t\s\r\n]+$//g;
				$decl_name =~ s/[\t\s\r\n]+$//g;
				
				push(@DECL_ROUTINES,$list_task.';'.$list_file.';'.$decl_all.';'.$decl_local.';'.$decl_type.';'.$decl_name);			
			}
		}
	}
	return(@DECL_ROUTINES);
}



sub BackupFindProgModules {
	my($folder) = @_;
	my($i,$de,$DIR,$list_task,$list_task_name,$list_task_entry,$FILE,$line);
	foreach $i (0..$#TASK_LIST) {
		($list_task,$list_task_name,$list_task_entry) = split(/;/,$TASK_LIST[$i]);
		opendir($DIR,$folder.'/RAPID/'.$list_task.'/PROGMOD');
		foreach $de (readdir($DIR)) {
			if ($de =~ /\.mod(x?)/i) {
				push(@PROG_MODULES,$list_task.';/RAPID/'.$list_task.'/PROGMOD/'.$de);
				
				open($FILE,'<'.$folder.'/RAPID/'.$list_task.'/PROGMOD/'.$de);
				while ($line = <$FILE>) {
					push(@{$FILEDATA{$folder.'/RAPID/'.$list_task.'/PROGMOD/'.$de}},$line);
				}
				close($FILE);
			}
		}
		closedir($DIR);
		opendir($DIR,$folder.'/RAPID/'.$list_task.'/SYSMOD');
		foreach $de (readdir($DIR)) {
			if ($de =~ /\.sys(x?)/i) {
				push(@PROG_MODULES,$list_task.';/RAPID/'.$list_task.'/SYSMOD/'.$de);

				open($FILE,'<'.$folder.'/RAPID/'.$list_task.'/SYSMOD/'.$de);
				while ($line = <$FILE>) {
					push(@{$FILEDATA{$folder.'/RAPID/'.$list_task.'/SYSMOD/'.$de}},$line);
				}
				close($FILE);
			}
		}
		closedir($DIR);
	}
	return(@PROG_MODULES);
}



sub BackupFindTaskEntryPoints {
	my($folder) = @_;
	my($FILE,$de,$line,$task_name,$task_entry,$list_task,$list_task_name);
	foreach $i (0..$#TASK_LIST) {
		($list_task,$list_task_name) = split(/;/,$TASK_LIST[$i]);
		$TASK_LIST[$i] = $list_task.';'.$list_task_name.';Main';
	}
	open($FILE,'<'.$folder.'/SYSPAR/SYS.cfg');
	while ($line = <$FILE>) {
		if ($line =~ /^CAB_TASKS:/) {
			last;
		}
	}
	while ($line = <$FILE>) {
		chop($line);
		if ($line =~ /^#/) {
			last;
		} else {
			while ($line =~ /\\$/) {
				chop($line);
				$line .= <$FILE>;
				chop($line);
			}
			if ($line =~ /-Name\s+"([\w\d_]+)".*-Entry\s+"([\w\d_]+)"/) {
				$task_name = $1;
				$task_entry = $2;
				foreach $i (0..$#TASK_LIST) {
					($list_task,$list_task_name) = split(/;/,$TASK_LIST[$i]);
					if ($task_name eq $list_task_name) {
						$TASK_LIST[$i] = $list_task.';'.$list_task_name.';'.$task_entry;
						last;
					}
				}
			}
		}
	}
	close($FILE);
	return;
}



sub BackupFindEventRoutines {
	my($folder) = @_;
	my($FILE, $line, $event_routine, $event_action, $event_task, $event_alltask, $taskn, $taskname);
	open($FILE,'<'.$folder.'/SYSPAR/SYS.cfg');
	while ($line = <$FILE>) {
		if ($line =~ /^CAB_EXEC_HOOKS:/) {
			last;
		}
	}
	while ($line = <$FILE>) {
		chop($line);
		if ($line =~ /^#/) {
			last;
		} else {
			while ($line =~ /\\$/) {
				chop($line);
				$line .= <$FILE>;
				chop($line);
			}
			$event_alltask = '';
			if ($line =~ /-Routine\s+"([\w\d_]+)".*-Shelf\s+"([\w\d_]+)".*-Task\s+"([\w\d_]+)"(\s+-AllTask)?/) {
				$event_routine = $1;
				$event_action = $2;
				$event_task = $3;
				if (defined($4)) {
					$event_alltask = 'ALL';
					foreach (@TASK_LIST) {
						($taskn, $taskname) = split(/;/, $_);
						push(@EVENT_ROUTINE_LIST, $event_routine.';'.$event_action.';'.$taskname);
					}
				} else {
					push(@EVENT_ROUTINE_LIST, $event_routine.';'.$event_action.';'.$event_task);
				}
			}
		}
	}
	close($FILE);
}



sub BackupFindTaskList {
	my($folder) = @_;
	my(@list) = ();
	my($FILE,$line,);
	open($FILE,'<'.$folder.'/BACKINFO/backinfo.txt');
	while ($line = <$FILE>) {

		# Old syntax
		# >>TASK0: (MAIN)
		
		# New syntax
		# >>TASK0: (MAIN,<name>)

		if ($line =~ />>(TASK\d+):\s\(([\w\d_]+)/) {
			push(@list,$1.';'.$2);			
		}
	}
	close($FILE);
	return(@list);
}



sub BackupFindMostRecent {
	my($folder) = @_;
	my($backupfolder_latest) = 'Not found';
	$BACKUP_TIME = 0;
	my($DIR,$FILE,$line,$de,$current_time,$current_id,$products_id);
	opendir($DIR,'.');
	foreach $de (readdir($DIR)) {
		if (-d ($folder.'/'.$de)) {
			if (-e $folder.'/'.$de.'/BACKINFO/backinfo.txt') {
				$current_time = 0;
				$current_id = 0;
				$products_id = 0;
				open($FILE,'<'.$folder.'/'.$de.'/BACKINFO/backinfo.txt');
				while ($line = <$FILE>) {
					if ($line =~ /(\d\d|\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)/) {
						$current_time = timelocal($6, $5, $4, $3, ($2-1), $1);
					} elsif ($line =~ /^>>SYSTEM_ID:/) {
						$current_id = <$FILE>;
						chop($current_id);
					} elsif ($line =~ /^>>PRODUCTS_ID:/) {
						$products_id = <$FILE>;
						chop($products_id);
					}
					if ($current_time && $current_id && $products_id) {
						last;
					}
				}
				close($FILE);
				print '    '.$folder.'/'.$de.' '.$current_time;
				if ($current_time > $BACKUP_TIME) {
					$BACKUP_TIME = $current_time;
					$BACKUP_ID = $current_id;
					$BACKUP_RW = $products_id;
					$backupfolder_latest = $folder.'/'.$de;
					print ' *';
				}
				print "\n";
			}
		}
	}
	closedir($DIR);
	return($backupfolder_latest);
}



##### For generating graphml filefield



sub generate_graphml {
	my($folder) = @_;

	open(GRAPHML2, '>'.$folder.'_singlenode.graphml') or die('Unable to open ['.$folder.'_singlenode.graphml]');
	my($time_backup) = FormatTime($BACKUP_TIME);
	my($time_generated) = FormatTime(time());
	print GRAPHML2 <<END;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns" xmlns:java="http://www.yworks.com/xml/yfiles-common/1.0/java" xmlns:sys="http://www.yworks.com/xml/yfiles-common/markup/primitives/2.0" xmlns:x="http://www.yworks.com/xml/yfiles-common/markup/2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:y="http://www.yworks.com/xml/graphml" xmlns:yed="http://www.yworks.com/xml/yed/3" xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://www.yworks.com/xml/schema/graphml/1.1/ygraphml.xsd">
	<key for="node" id="d5" yfiles.type="nodegraphics"/>
	<key for="node" id="d6" yfiles.type="nodegraphics"/>
	<key for="edge" id="d10" yfiles.type="edgegraphics"/>
	<key for="graph" id="user" attr.name="User" attr.type="string"/>
	<key for="graph" id="user_machine" attr.name="User machine" attr.type="string"/>
	<key for="graph" id="generator" attr.name="Generator" attr.type="string"/>
	<key for="graph" id="generator_rev" attr.name="Generator revision" attr.type="string"/>
	<key for="graph" id="generated_time" attr.name="Generated time" attr.type="string"/>
	<key for="graph" id="author" attr.name="Author" attr.type="string"/>
	<key for="graph" id="author_web" attr.name="Author www" attr.type="string"/>
	<key for="graph" id="robot_id" attr.name="Robot ID" attr.type="string"/>
	<key for="graph" id="backup_robotware" attr.name="Backup robotware" attr.type="string"/>
	<key for="graph" id="backup_time" attr.name="Backup time" attr.type="string"/>
	<graph edgedefault="directed" id="G">
		<data key="user">$APP_USER</data>
		<data key="user_machine">$APP_USER_MACHINE</data>
		<data key="generator">$APP_NAME</data>
		<data key="generator_rev">$APP_REV</data>
		<data key="generated_time">$time_generated</data>
		<data key="author">$APP_AUTH</data>
		<data key="author_web" href="$APP_WEB">$APP_WEB</data>
		<data key="robot_id">$BACKUP_ID</data>
		<data key="backup_robotware">$BACKUP_RW</data>
		<data key="backup_time">$time_backup</data>

END

	my($i,$j,$list_task,$decl_file,$decl_all,$decl_local,$decl_type,$decl_name,$from,$to);
	my($task,$task_name,$task_entry);
	my($id_i) = $#DECL_ROUTINES + 1;
	my(%modules,@module_list);

	# Grouping tasks
	# Generating nodes
	
	foreach $i (0..$#TASK_LIST) {
		($task,$task_name,$task_entry) = split(/;/,$TASK_LIST[$i]);
		print GRAPHML2 <<END;
		<!-- GROUP TASK $task, $task_name -->
		<node id="n$id_i" yfiles.foldertype="group">
			<data key="d5">
				<y:ProxyAutoBoundsNode>
					<y:Realizers active="0">
					<y:GroupNode>
					<y:Fill hasColor="false" transparent="false"/>
					<y:BorderStyle color="#000000" type="dashed_dotted" width="2.0"/>
					<y:NodeLabel alignment="right" autoSizePolicy="node_width" backgroundColor="#FF9900" fontSize="30" fontStyle="bold" textColor="#000000" visible="true" modelName="internal" modelPosition="tr">$task, $task_name</y:NodeLabel>
					<y:Shape type="roundrectangle"/>
					<y:State closed="false" closedHeight="50.0" closedWidth="50.0" innerGraphDisplayEnabled="false"/>
				</y:GroupNode>
				</y:Realizers>
				</y:ProxyAutoBoundsNode>
			</data>
			<graph edgedefault="directed" id="n$id_i:">

END

		$id_i++;
		
		# Generate list of modules
		%modules = ();
		foreach $j (0..$#DECL_ROUTINES) {
			($list_task,$decl_file,$decl_all,$decl_local,$decl_type,$decl_name) = split(/;/,$DECL_ROUTINES[$j]);
		
			if ($list_task ne $task) {
				next;
			}
			
			$modules{$decl_file} = 1;
		}
		@module_list = keys %modules;
		
		my($value_module);
		foreach $j (0..$#module_list) {
			$value_module = $module_list[$j];
			if ($value_module =~ /linkedm.sys$/i) {
				# ABB internal stuff, ignore
				next;
			}
			$value_module =~ s/[^a-z0-9_\.\/]/_/gi;
			print GRAPHML2 <<END;
				<!-- GROUP MODULE $value_module -->
				<node id="n$id_i" yfiles.foldertype="group">
					<data key="d5">
						<y:ProxyAutoBoundsNode>
							<y:Realizers active="0">
							<y:GroupNode>
							<y:Fill hasColor="false" transparent="false"/>
							<y:BorderStyle color="#000000" type="dashed_dotted" width="1.0"/>
							<y:NodeLabel alignment="right" autoSizePolicy="node_width" backgroundColor="#AAAAFF" fontStyle="bold" textColor="#000000" visible="true" modelName="internal" modelPosition="tr">$value_module</y:NodeLabel>
							<y:Shape type="roundrectangle"/>
							<y:State closed="false" closedHeight="50.0" closedWidth="50.0" innerGraphDisplayEnabled="false"/>
						</y:GroupNode>
						</y:Realizers>
						</y:ProxyAutoBoundsNode>
					</data>
					<graph edgedefault="directed" id="n$id_i:">

END

			$id_i++;

			foreach $i (0..$#DECL_ROUTINES) {
				($list_task,$decl_file,$decl_all,$decl_local,$decl_type,$decl_name) = split(/;/,$DECL_ROUTINES[$i]);
			
				if ($list_task ne $task) {
					next;
				}
			
				if ($decl_file ne $module_list[$j]) {
					next;
				}

				if (lc($task_entry) eq lc($decl_name)) {
					#print GRAPHML2 NodeGraphmlMain($i,$decl_all."\n".$decl_file);
					print GRAPHML2 NodeGraphmlMain($i,$decl_all,$list_task.'/'.$decl_file.'/'.$decl_all);
				} elsif ($decl_type =~ /^FUNC/i) {
					#print GRAPHML2 NodeGraphmlFunc($i,$decl_all."\n".$decl_file);
					print GRAPHML2 NodeGraphmlFunc($i,$decl_all,$list_task.'/'.$decl_file.'/'.$decl_all);
				} elsif ($decl_type =~ /^TRAP/i) {
					#print GRAPHML2 NodeGraphmlTrap($i,$decl_all."\n".$decl_file);
					print GRAPHML2 NodeGraphmlTrap($i,$decl_all,$list_task.'/'.$decl_file.'/'.$decl_all);
				} else {
					#print GRAPHML2 NodeGraphmlProc($i,$decl_all."\n".$decl_file);
					print GRAPHML2 NodeGraphmlProc($i,$decl_all,$list_task.'/'.$decl_file.'/'.$decl_all,$decl_name,$task_name);
				}
			}

			print GRAPHML2 <<END;
					<!-- /GROUP MODULE $value_module -->
					</graph>
				</node>

END

		}

		print GRAPHML2 <<END;
			<!-- /GROUP $task, $task_name -->
			</graph>
		</node>
END

	}
	
	# Generate edges
	foreach $i (0..$#CONNECTIONS) {
		($from,$to) = split(/;/,$CONNECTIONS[$i]);
		
		print GRAPHML2 NodeGraphmlEdge($id_i,$from,$to);
		
		$id_i++;
	}
	
	print GRAPHML2 <<END;
		<!-- GROUP LEGEND -->
		<node id="n$id_i" yfiles.foldertype="group">
			<data key="d5">
				<y:ProxyAutoBoundsNode>
					<y:Realizers active="0">
					<y:GroupNode>
					<y:Fill hasColor="false" transparent="false"/>
					<y:BorderStyle color="#000000" type="dashed_dotted" width="2.0"/>
					<y:NodeLabel alignment="right" autoSizePolicy="node_width" backgroundColor="#FF9900" fontSize="30" fontStyle="bold" textColor="#000000" visible="true" modelName="internal" modelPosition="tr">LEGEND / TASK GROUP</y:NodeLabel>
					<y:Shape type="roundrectangle"/>
					<y:State closed="false" closedHeight="50.0" closedWidth="50.0" innerGraphDisplayEnabled="false"/>
				</y:GroupNode>
				</y:Realizers>
				</y:ProxyAutoBoundsNode>
			</data>
			<graph edgedefault="directed" id="n$id_i:">
END
	$id_i++;
	print GRAPHML2 <<END;
				<!-- GROUP LEGEND TASK -->
				<node id="n$id_i" yfiles.foldertype="group">
					<data key="d5">
						<y:ProxyAutoBoundsNode>
							<y:Realizers active="0">
							<y:GroupNode>
							<y:Fill hasColor="false" transparent="false"/>
							<y:BorderStyle color="#000000" type="dashed_dotted" width="1.0"/>
							<y:NodeLabel alignment="right" autoSizePolicy="node_width" backgroundColor="#AAAAFF" fontStyle="bold" textColor="#000000" visible="true" modelName="internal" modelPosition="tr">MODULE</y:NodeLabel>
							<y:Shape type="roundrectangle"/>
							<y:State closed="false" closedHeight="50.0" closedWidth="50.0" innerGraphDisplayEnabled="false"/>
						</y:GroupNode>
						</y:Realizers>
						</y:ProxyAutoBoundsNode>
					</data>
					<graph edgedefault="directed" id="n$id_i:">
END

	$id_i++;
	print GRAPHML2 <<END;
    <node id="n$id_i">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          <y:Fill color="#66FFFF" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" textColor="#000000" visible="true">Task Entry Point</y:NodeLabel>
          <y:Shape type="fatarrow"/>
        </y:ShapeNode>
      </data>
    </node>
END

	$id_i++;
	print GRAPHML2 <<END;
    <node id="n$id_i">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          <y:Fill color="#EEEEFF" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" textColor="#000000" visible="true">Procedure</y:NodeLabel>
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
END
	
	$id_i++;
	print GRAPHML2 <<END;
    <node id="n$id_i">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          <y:Fill color="#FFCC99" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" textColor="#000000" visible="true">Function</y:NodeLabel>
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
END

	$id_i++;
	print GRAPHML2 <<END;
    <node id="n$id_i">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          <y:Fill color="#FF9999" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" textColor="#000000" visible="true">Trap</y:NodeLabel>
          <y:Shape type="parallelogram"/>
        </y:ShapeNode>
      </data>
    </node>
END
			
	$id_i++;
	print GRAPHML2 <<END;
    <node id="n$id_i">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          <y:Fill color="#DDFFDD" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" textColor="#000000" visible="true">Event Routine</y:NodeLabel>
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
END

	print GRAPHML2 <<END;
					<!-- /MODULE GROUP -->
					</graph>
				</node>

			
			<!-- /LEGEND TASK GROUP -->
			</graph>
		</node>

END

	print GRAPHML2 <<END;
	</graph>
</graphml>

END
	close(GRAPHML2);
}



sub NodeGraphmlMain {
	my($id,$text,$verified_text) = @_;

	my($borderstyle) = '<y:BorderStyle color="#000000" type="line" width="1.0"/>';

	if ($VERIFIED_ROUTINES{$verified_text}) {
		# Found tag for manual OK
		$borderstyle = '<y:BorderStyle color="#00cc00" type="line" width="2.0"/>';
	}

	my($res) = <<END;
	<!-- NODE
$text
	-->
    <node id="n$id">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          <y:Fill color="#66FFFF" color2="#FFFFFF" transparent="false"/>
          $borderstyle
          <y:NodeLabel alignment="center" textColor="#000000" visible="true">$text</y:NodeLabel>
          <y:Shape type="fatarrow"/>
        </y:ShapeNode>
      </data>
    </node>
	
END

	return($res);
}



sub NodeGraphmlProc {
	my($id,$text,$verified_text,$decl_name,$decl_task) = @_;
	
	$text =~ s/[^a-z0-9_\.\/\s]/_/gi;

	my($nodelabel) = '<y:NodeLabel alignment="center" textColor="#000000" visible="true">'.$text.'</y:NodeLabel>';
	my($borderstyle) = '<y:BorderStyle color="#000000" type="line" width="1.0"/>';
	my($fill) = '<y:Fill color="#EEEEFF" color2="#FFFFFF" transparent="false"/>';
	
	if (!($UNUSED_ROUTINES{$id})) {
		# Keep values
		if ($VERIFIED_ROUTINES{$verified_text}) {
			# Found tag for manual OK
			$borderstyle = '<y:BorderStyle color="#00cc00" type="line" width="2.0"/>';
		}
	} else {
		# Change to 
		$fill = '<y:Fill hasColor="false" transparent="false"/>';
		$borderstyle = '<y:BorderStyle color="#888888" type="dashed" width="1.0"/>';
		$nodelabel = '<y:NodeLabel alignment="center" textColor="#888888" visible="true">'.$text.'</y:NodeLabel>';
		if ($text =~ /_(_|\()Ignored(_|\()$/i) {
			return('') if ($CFG_HIDE_IGNORED_NODES);
			$borderstyle = '<y:BorderStyle color="#cc0000" type="dashed" width="2.0"/>';
		}
	}

	my($eventroutine, $eventaction, $eventtaskn);
	foreach (@EVENT_ROUTINE_LIST) {
		($eventroutine, $eventaction, $eventtaskn) = split(/;/, $_);
		if ((lc($eventroutine) eq lc($decl_name)) && ($eventtaskn eq $decl_task)) {
			# Event routine so different style
			$fill = '<y:Fill color="#DDFFDD" color2="#FFFFFF" transparent="false"/>';
			$borderstyle = '<y:BorderStyle color="#000000" type="line" width="1.0"/>';
			$nodelabel = '<y:NodeLabel alignment="center" textColor="#000000" visible="true">'.$text."\n".'Event: '.$eventaction.'</y:NodeLabel>';
			last;
		}
	}

	my($res) = <<END;
	<!-- NODE
$text
	-->
    <node id="n$id">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          $fill
          $borderstyle
          $nodelabel
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
	
END

	return($res);
}



sub NodeGraphmlFunc {
	my($id,$text,$verified_text) = @_;

	$text =~ s/[^a-z0-9_\.\/\s]/_/gi;

	my($nodelabel) = '<y:NodeLabel alignment="center" textColor="#000000" visible="true">'.$text.'</y:NodeLabel>';
	my($borderstyle) = '<y:BorderStyle color="#000000" type="line" width="1.0"/>';
	my($fill) = '<y:Fill color="#FFCC99" color2="#FFFFFF" transparent="false"/>';

	if (!($UNUSED_ROUTINES{$id})) {
		# Keep values
		if ($VERIFIED_ROUTINES{$verified_text}) {
			# Found tag for manual OK
			$borderstyle = '<y:BorderStyle color="#00cc00" type="line" width="2.0"/>';
		}
	} else {
		# Change to 
		$fill = '<y:Fill hasColor="false" transparent="false"/>';
		$borderstyle = '<y:BorderStyle color="#888888" type="dashed" width="1.0"/>';
		$nodelabel = '<y:NodeLabel alignment="center" textColor="#888888" visible="true">'.$text.'</y:NodeLabel>';
		if ($text =~ /_(_|\()Ignored(_|\()$/i) {
			return('') if ($CFG_HIDE_IGNORED_NODES);
			$borderstyle = '<y:BorderStyle color="#cc0000" type="dashed" width="2.0"/>';
		}
	}

	my($res) = <<END;
	<!-- NODE
$text
	-->
    <node id="n$id">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          $fill
          $borderstyle
          $nodelabel
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
	
END

	return($res);
}



sub NodeGraphmlTrap {
	my($id,$text,$verified_text) = @_;

	$text =~ s/[^a-z0-9_\.\/\s]/_/gi;

	my($nodelabel) = '<y:NodeLabel alignment="center" textColor="#000000" visible="true">'.$text.'</y:NodeLabel>';
	my($borderstyle) = '<y:BorderStyle color="#000000" type="line" width="1.0"/>';
	my($fill) = '<y:Fill color="#FF9999" color2="#FFFFFF" transparent="false"/>';

	if (!($UNUSED_ROUTINES{$id})) {
		# Keep values
		if ($VERIFIED_ROUTINES{$verified_text}) {
			# Found tag for manual OK
			$borderstyle = '<y:BorderStyle color="#00cc00" type="line" width="2.0"/>';
		}
	} else {
		# Change to 
		$fill = '<y:Fill hasColor="false" transparent="false"/>';
		$borderstyle = '<y:BorderStyle color="#888888" type="dashed" width="1.0"/>';
		$nodelabel = '<y:NodeLabel alignment="center" textColor="#888888" visible="true">'.$text.'</y:NodeLabel>';
		if ($text =~ /_(_|\()Ignored(_|\()$/i) {
			return('') if ($CFG_HIDE_IGNORED_NODES);
			$borderstyle = '<y:BorderStyle color="#cc0000" type="dashed" width="2.0"/>';
		}
	}

	my($res) = <<END;
	<!-- NODE
$text
	-->
    <node id="n$id">
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="250.0"/>
          $fill
          $borderstyle
          $nodelabel
          <y:Shape type="parallelogram"/>
        </y:ShapeNode>
      </data>
    </node>
	
END

	return($res);
}



sub NodeGraphmlEdge {
	my($id,$from,$to) = @_;
	
	my($rgb_r) = 0;
	my($rgb_g) = 0;
	my($rgb_b) = 0;
	while ((($rgb_r+$rgb_g+$rgb_b)>400) || (($rgb_r < 190) && ($rgb_g < 190) && ($rgb_b < 190))) {
		$rgb_r = int(rand(255));
		$rgb_g = int(rand(255));
		$rgb_b = int(rand(255));
	}
	
	my($color) = '#'.sprintf("%02X", $rgb_r).sprintf("%02X", $rgb_g).sprintf("%02X", $rgb_b);

	my($res) = <<END;
    <edge id="e$id" source="n$from" target="n$to">
      <data key="d10">
        <y:PolyLineEdge>
          <y:LineStyle color="$color" type="line" width="1.0"/>
          <y:Arrows source="none" target="standard"/>
          <y:BendStyle smoothed="true"/>
        </y:PolyLineEdge>
      </data>
    </edge>
	
END

	return($res);
}



sub CheckEdgeConnected {
	my($id) = @_;
	my($from,$to);

	foreach $i (0..$#CONNECTIONS) {
		($from,$to) = split(/;/,$CONNECTIONS[$i]);
		
		if (($from == $id) || ($to == $id)) {
			return 1;
		}
		
	}
	return 0;
	
}



sub FormatTime {
	my($stime) = @_;
	my(@timedata) = localtime($stime);
	my($res) = ($timedata[5] + 1900).'-';
	if ($timedata[4] < 9) { $res .= '0'; }
	$res .= ($timedata[4] + 1).'-';
	if ($timedata[3] < 10) { $res .= '0'; }
	$res .= $timedata[3].' ';
	if ($timedata[2] < 10) { $res .= '0'; }
	$res .= $timedata[2].':';
	if ($timedata[1] < 10) { $res .= '0'; }
	$res .= $timedata[1].':';
	if ($timedata[0] < 10) { $res .= '0'; }
	$res .= $timedata[0];
	return $res;
}


