#!c:/perl/bin/perl

#////////////////////////////////////////////////////////////////////////////////

# Rapid2Graph
# Rev. 2022-01-28
# SS/RN

# Tidsforbruk
# 2022-02-29 7.5t
# 2022-02-30 7.5t

#////////////////////////////////////////////////////////////////////////////////

use Time::Local;

# Define cmdline nobuffer
$| = 1;
$DEBUG = 1;

# Define GLOBAL variables
$BAK_FOLDER = '';

$BAK_INFO = ([]);
$TASK_INFO = ([]);
$TASK_MODS = ([]);
$TASK_ROUTINES = ([]);
$TASK_CALLS = ([]);

# Open file for writing.
#   Will write all procedures found in backup into this file
#   Format: <i>, <ProcedureName>, <RoutineType>, <RoutineLocal>, <Module>, <TASKn>
open(PROCS,'>procs.log');

# Find most recent backup FOLDER
find_most_recent_bak();

# Read information from BACKINFO/backinfo.txt
#   We want RobotID, Robotware and all TASK ids and modulenames.
read_bakinfo();

# Read all RAPID modules from each TASK. Find all PROC/TRAP/FUNC and their location.
read_taskinfo();

# Store all found procedures
#   Format: <TASKn>; <Module>; <ProcedureName>; <RoutineType>; <RoutineLocal>;
open(FILE,'>TaskProcs.log');
foreach $i (0..$#TASK_ROUTINES) {
	foreach $j (0..$#{$TASK_ROUTINES[$i]}) {
		#print $TASK_ROUTINES[$i][$j].';';
		print FILE $TASK_ROUTINES[$i][$j].';';
	}
	print FILE "\n";
	#print "\n";
}
close(FILE);

# Read every line of every module, try to find procedure/function -calls and map where they originate and to where they call
read_taskinfo_calls();
#foreach $i (0..$#TASK_ROUTINES) {
#	foreach $j (0..$#{$TASK_ROUTINES[$i]}) {
#		print $TASK_ROUTINES[$i][$j].';';
#	}
#	print "\n";
#}

# There may be multiples, no need to generate junk data
remove_duplicates();

# Store logfile containing all calls.
#   Format: <TASKn>; <Module>; <Procedure>; <ProcedureToCall>;
open(FILE,'>TaskCalls.log');
foreach $i (0..$#TASK_CALLS) {
	foreach $j (0..$#{$TASK_CALLS[$i]}) {
		#print $TASK_CALLS[$i][$j].';';
		print FILE $TASK_CALLS[$i][$j].';';
	}
	print FILE "\n";
	#print "\n";
}
close(FILE);

# Define global data related to out-files
$TGF_NODES_i = 1;
$TGF_NODES = '';
$TGF_LINKS = '';
$GRAPHML_NODES = '';
$GRAPHML_LINKS = '';
$GRAPHML2_NODES = '';
%GRAPHML2_NODEREF = ();
$GRAPHML2_LINKS = '';
$GRAPHML_EDGE_i = 1;

# Generate out-files
generate_tgf();

close(PROCS);

print <<EOM;

//////////////////////////////////////////////////////////////////////

Note!

If any late binding calls are used, these can not be determined without executing the Rapidprogram. However you can
add a comment on the following line to indicate any valid calls.

Ex.

CallByVar "CMD",giPlcCommand;
! Rapid2Graph [CMD_1000,CMD_1001,CMD_3000,CMD_4000,CMD_4100,CMD_9900]

//////////////////////////////////////////////////////////////////////

Rapid2Chart finnished successfully!
www.straumland.com

EOM

sleep(3);

# EXIT/FINNISHED
exit;

# ////////// ////////// ////////// ////////// ////////// ////////// ////////// //////////

sub generate_tgf {
	my($i,$parent_from);

	print '-Generating TGF file'."\n";
	
	$TGF_NODES_i = 1;

	foreach $i (0..$#TASK_INFO) {
		
		$TGF_NODES .= $TGF_NODES_i.' '.$TASK_INFO[$i][0].'('.$TASK_INFO[$i][1].')/Main'."\n";
		$GRAPHML_NODES = NodeGraphmlMain($TGF_NODES_i,$TASK_INFO[$i][0].'('.$TASK_INFO[$i][1].')/Main').$GRAPHML_NODES;
		$GRAPHML2_NODES = NodeGraphmlMain($TGF_NODES_i,$TASK_INFO[$i][0].'('.$TASK_INFO[$i][1].')/Main').$GRAPHML2_NODES;
		
		$parent_from = $TGF_NODES_i;
		$TGF_NODES_i++;
		#                  $parent,     $task,            $module,$routine
		generate_tgf_calls($parent_from,$TASK_INFO[$i][0],'',     'Main',0,'');
	}
	
	open(TGF, '>'.$BAK_INFO[0].'.tgf');
	print TGF $TGF_NODES;
	print TGF '#'."\n";
	print TGF $TGF_LINKS;
	close(TGF);

	open(GRAPHML, '>'.$BAK_INFO[0].'.graphml');
	open(GRAPHML2, '>'.$BAK_INFO[0].'_singlenode.graphml');
	
	print GRAPHML <<END;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns" xmlns:java="http://www.yworks.com/xml/yfiles-common/1.0/java" xmlns:sys="http://www.yworks.com/xml/yfiles-common/markup/primitives/2.0" xmlns:x="http://www.yworks.com/xml/yfiles-common/markup/2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:y="http://www.yworks.com/xml/graphml" xmlns:yed="http://www.yworks.com/xml/yed/3" xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://www.yworks.com/xml/schema/graphml/1.1/ygraphml.xsd">
  <!--Created by Rapid2Graph www.straumland.com-->
  <key attr.name="Description" attr.type="string" for="graph" id="d0"/>
  <key for="port" id="d1" yfiles.type="portgraphics"/>
  <key for="port" id="d2" yfiles.type="portgeometry"/>
  <key for="port" id="d3" yfiles.type="portuserdata"/>
  <key attr.name="url" attr.type="string" for="node" id="d4"/>
  <key attr.name="description" attr.type="string" for="node" id="d5"/>
  <key for="node" id="d6" yfiles.type="nodegraphics"/>
  <key for="graphml" id="d7" yfiles.type="resources"/>
  <key attr.name="url" attr.type="string" for="edge" id="d8"/>
  <key attr.name="description" attr.type="string" for="edge" id="d9"/>
  <key for="edge" id="d10" yfiles.type="edgegraphics"/>
  <graph edgedefault="directed" id="G">
    <data key="d0"/>
END
	print GRAPHML2 <<END;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns" xmlns:java="http://www.yworks.com/xml/yfiles-common/1.0/java" xmlns:sys="http://www.yworks.com/xml/yfiles-common/markup/primitives/2.0" xmlns:x="http://www.yworks.com/xml/yfiles-common/markup/2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:y="http://www.yworks.com/xml/graphml" xmlns:yed="http://www.yworks.com/xml/yed/3" xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://www.yworks.com/xml/schema/graphml/1.1/ygraphml.xsd">
  <!--Created by Rapid2Graph www.straumland.com-->
  <key attr.name="Description" attr.type="string" for="graph" id="d0"/>
  <key for="port" id="d1" yfiles.type="portgraphics"/>
  <key for="port" id="d2" yfiles.type="portgeometry"/>
  <key for="port" id="d3" yfiles.type="portuserdata"/>
  <key attr.name="url" attr.type="string" for="node" id="d4"/>
  <key attr.name="description" attr.type="string" for="node" id="d5"/>
  <key for="node" id="d6" yfiles.type="nodegraphics"/>
  <key for="graphml" id="d7" yfiles.type="resources"/>
  <key attr.name="url" attr.type="string" for="edge" id="d8"/>
  <key attr.name="description" attr.type="string" for="edge" id="d9"/>
  <key for="edge" id="d10" yfiles.type="edgegraphics"/>
  <graph edgedefault="directed" id="G">
    <data key="d0"/>
END
	
	print GRAPHML $GRAPHML_NODES;
	print GRAPHML $GRAPHML_LINKS;
	print GRAPHML2 $GRAPHML2_NODES;
	print GRAPHML2 $GRAPHML2_LINKS;
	
	print GRAPHML <<END;
  </graph>
  <data key="d7">
    <y:Resources/>
  </data>
</graphml>
END
	print GRAPHML2 <<END;
  </graph>
  <data key="d7">
    <y:Resources/>
  </data>
</graphml>
END
	
	close(GRAPHML);
	close(GRAPHML2);

}

sub generate_tgf_calls {
	my($parent_node,$task,$module_from,$routine_from,$trap_prevent_recursion,$endless_recursion_prevention) = @_;
	my($global,$local,$i,$j,$parent_to,$module_to,$routine_to_type);
	
	# If there are a local and a different global $routine_to, then we need to call the proper one.
	CALLS:foreach $i (0..$#TASK_CALLS) {
		
		$module_to = '';
		$routine_to_type = '';
		
		if ($task ne $TASK_CALLS[$i][0]) { next; }
		if (lc($routine_from) ne lc($TASK_CALLS[$i][2])) { next; }
		
		$routine_to = $TASK_CALLS[$i][3];
		
		if ($routine_to =~ /^\[/) {
			# Late binding call
			$TGF_NODES .= $TGF_NODES_i.' '.$module_to.'/'.$routine_to_type.' '.$routine_to."\n";
			$GRAPHML_NODES = NodeGraphmlLateB($TGF_NODES_i,$routine_to).$GRAPHML_NODES;
			$parent_to = $TGF_NODES_i;
			$TGF_LINKS .= $parent_node.' '.$parent_to.' '."\n";
			$GRAPHML_LINKS .= NodeGraphmlEdge($GRAPHML_EDGE_i,$parent_node,$parent_to);
			$GRAPHML_EDGE_i++;
			$TGF_NODES_i++;
			next CALLS;
		}
		
		$local = 0;
		$global = 0;
		foreach $j (0..$#TASK_ROUTINES) {
			# @TASK_ROUTINES = ( [$TASKn, $module, $routine, $type, $local] );
			if (($task eq $TASK_ROUTINES[$j][0]) && ($module_from eq $TASK_ROUTINES[$j][1]) && (lc($routine_to) eq lc($TASK_ROUTINES[$j][2])) && ($TASK_ROUTINES[$j][4])) {
				$module_to = $TASK_ROUTINES[$j][1];
				$routine_to_type = $TASK_ROUTINES[$j][3];
				$local = 1;	
				last;
			}
			if (($task eq $TASK_ROUTINES[$j][0]) && (lc($routine_to) eq lc($TASK_ROUTINES[$j][2]))) {
				$module_to = $TASK_ROUTINES[$j][1];
				$routine_to_type = $TASK_ROUTINES[$j][3];
				$global = 1;
			}
		}
		if (($local + $global) == 0) {
			print 'ERROR: ['.$task.'/'.$module_from.'/'.$routine_from.'] made a call to non-existant ['.$routine_to.']'."\n";
			#foreach $j (0..$#TASK_ROUTINES) {
			#	print '*'.$routine_to.', '.$TASK_ROUTINES[$j][0].'/'.$TASK_ROUTINES[$j][1].'/'.$TASK_ROUTINES[$j][2].':'.$TASK_ROUTINES[$j][4]."\n";
			#}
			#exit;
			next CALLS;
		}

		if ($endless_recursion_prevention =~ /$routine_to/i) {
			$recursion_warning = "\n".'WARNING: Endless recursion stopped';
		} else {
			$recursion_warning = '';
		}
		
		if ($DEBUG) { print '  '.$task.'/'.$module_from.'/'.$routine_from.' -> '.$module_to.'/'.$routine_to."\n"; }
		
		# Create node
		#   TGF
		$TGF_NODES .= $TGF_NODES_i.' '.$module_to.'/'.$routine_to_type.' '.$routine_to."\n";
		#   GRAPHML
		if (uc($routine_to_type) eq 'TRAP') {
			$GRAPHML_NODES = NodeGraphmlTrap($TGF_NODES_i,$routine_to_type.' '.$routine_to."\n".$module_to.$recursion_warning).$GRAPHML_NODES;
		} elsif ($routine_to_type =~ /^FUNC/i) {
			$GRAPHML_NODES = NodeGraphmlFunc($TGF_NODES_i,$routine_to_type.' '.$routine_to."\n".$module_to.$recursion_warning).$GRAPHML_NODES;
		} else {
			$GRAPHML_NODES = NodeGraphmlProc($TGF_NODES_i,$routine_to_type.' '.$routine_to."\n".$module_to.$recursion_warning).$GRAPHML_NODES;
		}
		$parent_to = $TGF_NODES_i;
		#   GRAPHML2
		if ($GRAPHML2_NODEREF{$task.'/'.$module_to.'/'.$routine_to_type.' '.$routine_to}) {
			$parent_to = $GRAPHML2_NODEREF{$task.'/'.$module_to.'/'.$routine_to_type.' '.$routine_to};
		} else {
			if (uc($routine_to_type) eq 'TRAP') {
				$GRAPHML2_NODES = NodeGraphmlTrap($TGF_NODES_i,$routine_to_type.' '.$routine_to."\n".$module_to.$recursion_warning).$GRAPHML2_NODES;
			} elsif ($routine_to_type =~ /^FUNC/i) {
				$GRAPHML2_NODES = NodeGraphmlFunc($TGF_NODES_i,$routine_to_type.' '.$routine_to."\n".$module_to.$recursion_warning).$GRAPHML2_NODES;
			} else {
				$GRAPHML2_NODES = NodeGraphmlProc($TGF_NODES_i,$routine_to_type.' '.$routine_to."\n".$module_to.$recursion_warning).$GRAPHML2_NODES;
			}
			$GRAPHML2_NODEREF{$task.'/'.$module_to.'/'.$routine_to_type.' '.$routine_to} = $parent_to;
		}
		
		
		# Create link
		#   TGF
		$TGF_LINKS .= $parent_node.' '.$parent_to.' '."\n";
		#   GRAPHML
		$GRAPHML_LINKS .= NodeGraphmlEdge($GRAPHML_EDGE_i,$parent_node,$parent_to);
		$GRAPHML_EDGE_i++;
		#   GRAPHML2
		if ($GRAPHML2_EDGEREF{$parent_node.';'.$parent_to}) {
			# Nop
		} else {
			$GRAPHML2_LINKS .= NodeGraphmlEdge($GRAPHML_EDGE_i,$parent_node,$parent_to);
			$GRAPHML2_EDGEREF{$parent_node.';'.$parent_to} = 1;
		}

		$TGF_NODES_i++;

		# Call to self will trigger infinite recursion, so we try to avoid it
		if (lc($routine_from) eq lc($routine_to)) { next; }
		
		# Prevent endless recursion
		if ($endless_recursion_prevention =~ /$routine_to/i) { next; }

		# Trap routines will not be traversed, only added.
		if (uc($routine_to_type) eq 'TRAP') {
			# Trap routines will traverse new trap routines
			if ($trap_prevent_recursion) { next; }
			generate_tgf_calls($parent_to,$task,$module_to,$routine_to,1,$endless_recursion_prevention.';'.$routine_to);
		} else {
			generate_tgf_calls($parent_to,$task,$module_to,$routine_to,$trap_prevent_recursion,$endless_recursion_prevention.';'.$routine_to);
		}

	}
}

sub NodeGraphmlMain {
	my($id,$text) = @_;

	my($text) = <<END;
    <node id="n$id">
      <data key="d4" xml:space="preserve"/>
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="300.0" x="-185.0" y="0.0"/>
          <y:Fill color="#66FFFF" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" raised="false" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" autoSizePolicy="content" fontFamily="Dialog" fontSize="12" fontStyle="plain" hasBackgroundColor="false" hasLineColor="false" height="18.701171875" horizontalTextPosition="center" iconTextGap="4" modelName="custom" textColor="#000000" verticalTextPosition="bottom" visible="true" width="36.671875" x="181.6640625" xml:space="preserve" y="5.6494140625">$text<y:LabelModel><y:SmartNodeLabelModel distance="4.0"/></y:LabelModel><y:ModelParameter><y:SmartNodeLabelModelParameter labelRatioX="0.0" labelRatioY="0.0" nodeRatioX="0.0" nodeRatioY="0.0" offsetX="0.0" offsetY="0.0" upX="0.0" upY="-1.0"/></y:ModelParameter></y:NodeLabel>
          <y:Shape type="fatarrow"/>
        </y:ShapeNode>
      </data>
    </node>
END

	return($text);
}

sub NodeGraphmlProc {
	my($id,$text) = @_;

	my($text) = <<END;
    <node id="n$id">
      <data key="d4" xml:space="preserve"/>
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="300.0" x="275.55428075226064" y="-55.15656605691234"/>
          <y:Fill hasColor="false" transparent="false"/>
          <y:BorderStyle color="#000000" raised="false" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" autoSizePolicy="content" fontFamily="Dialog" fontSize="12" fontStyle="plain" hasBackgroundColor="false" hasLineColor="false" height="18.701171875" horizontalTextPosition="center" iconTextGap="4" modelName="custom" textColor="#000000" verticalTextPosition="bottom" visible="true" width="38.669921875" x="180.6650390625" xml:space="preserve" y="5.6494140625">$text<y:LabelModel><y:SmartNodeLabelModel distance="4.0"/></y:LabelModel><y:ModelParameter><y:SmartNodeLabelModelParameter labelRatioX="0.0" labelRatioY="0.0" nodeRatioX="0.0" nodeRatioY="0.0" offsetX="0.0" offsetY="0.0" upX="0.0" upY="-1.0"/></y:ModelParameter></y:NodeLabel>
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
END

	return($text);
}

sub NodeGraphmlFunc {
	my($id,$text) = @_;

	my($text) = <<END;
    <node id="n$id">
      <data key="d4" xml:space="preserve"/>
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="300.0" x="275.55428075226064" y="-4.687458978060533"/>
          <y:Fill color="#FFCC99" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" raised="false" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" autoSizePolicy="content" fontFamily="Dialog" fontSize="12" fontStyle="plain" hasBackgroundColor="false" hasLineColor="false" height="18.701171875" horizontalTextPosition="center" iconTextGap="4" modelName="custom" textColor="#000000" verticalTextPosition="bottom" visible="true" width="37.328125" x="181.3359375" xml:space="preserve" y="5.6494140625">$text<y:LabelModel><y:SmartNodeLabelModel distance="4.0"/></y:LabelModel><y:ModelParameter><y:SmartNodeLabelModelParameter labelRatioX="0.0" labelRatioY="0.0" nodeRatioX="0.0" nodeRatioY="0.0" offsetX="0.0" offsetY="0.0" upX="0.0" upY="-1.0"/></y:ModelParameter></y:NodeLabel>
          <y:Shape type="rectangle"/>
        </y:ShapeNode>
      </data>
    </node>
END

	return($text);
}

sub NodeGraphmlTrap {
	my($id,$text) = @_;

	my($text) = <<END;
    <node id="n$id">
      <data key="d4" xml:space="preserve"/>
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="300.0" x="275.55428075226064" y="51.40717346358417"/>
          <y:Fill color="#FF9999" color2="#FFFFFF" transparent="false"/>
          <y:BorderStyle color="#000000" raised="false" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" autoSizePolicy="content" fontFamily="Dialog" fontSize="12" fontStyle="plain" hasBackgroundColor="false" hasLineColor="false" height="18.701171875" horizontalTextPosition="center" iconTextGap="4" modelName="custom" textColor="#000000" verticalTextPosition="bottom" visible="true" width="37.328125" x="181.3359375" xml:space="preserve" y="5.6494140625">$text<y:LabelModel><y:SmartNodeLabelModel distance="4.0"/></y:LabelModel><y:ModelParameter><y:SmartNodeLabelModelParameter labelRatioX="0.0" labelRatioY="0.0" nodeRatioX="0.0" nodeRatioY="0.0" offsetX="0.0" offsetY="0.0" upX="0.0" upY="-1.0"/></y:ModelParameter></y:NodeLabel>
          <y:Shape type="parallelogram"/>
        </y:ShapeNode>
      </data>
    </node>
END

	return($text);
}

sub NodeGraphmlLateB {
	my($id,$text) = @_;

	my($text) = <<END;
    <node id="n$id">
      <data key="d4" xml:space="preserve"/>
      <data key="d6">
        <y:ShapeNode>
          <y:Geometry height="30.0" width="300.0" x="275.55428075226064" y="107.50180590522888"/>
          <y:Fill color="#00CCFF" transparent="false"/>
          <y:BorderStyle color="#000000" raised="false" type="line" width="1.0"/>
          <y:NodeLabel alignment="center" autoSizePolicy="content" fontFamily="Dialog" fontSize="12" fontStyle="plain" hasBackgroundColor="false" hasLineColor="false" height="18.701171875" horizontalTextPosition="center" iconTextGap="4" modelName="custom" textColor="#000000" verticalTextPosition="bottom" visible="true" width="51.373046875" x="174.3134765625" xml:space="preserve" y="5.6494140625">$text<y:LabelModel><y:SmartNodeLabelModel distance="4.0"/></y:LabelModel><y:ModelParameter><y:SmartNodeLabelModelParameter labelRatioX="0.0" labelRatioY="0.0" nodeRatioX="0.0" nodeRatioY="0.0" offsetX="0.0" offsetY="0.0" upX="0.0" upY="-1.0"/></y:ModelParameter></y:NodeLabel>
          <y:Shape type="hexagon"/>
        </y:ShapeNode>
      </data>
    </node>
END

	return($text);
}

sub NodeGraphmlEdge {
	my($id,$from,$to) = @_;

	my($text) = <<END;
    <edge id="e$id" source="n$from" target="n$to">
      <data key="d8" xml:space="preserve"/>
      <data key="d10">
        <y:PolyLineEdge>
          <y:Path sx="0.0" sy="0.0" tx="0.0" ty="0.0"/>
          <y:LineStyle color="#000000" type="line" width="1.0"/>
          <y:Arrows source="none" target="standard"/>
          <y:EdgeLabel alignment="center" configuration="AutoFlippingLabel" distance="2.0" fontFamily="Dialog" fontSize="12" fontStyle="plain" hasBackgroundColor="false" hasLineColor="false" hasText="false" height="4.0" horizontalTextPosition="center" iconTextGap="4" modelName="custom" preferredPlacement="anywhere" ratio="0.5" textColor="#000000" verticalTextPosition="bottom" visible="true" width="4.0" x="145.70617097973764" y="10.524897219965284">
            <y:LabelModel>
              <y:SmartEdgeLabelModel autoRotationEnabled="false" defaultAngle="0.0" defaultDistance="10.0"/>
            </y:LabelModel>
            <y:ModelParameter>
              <y:SmartEdgeLabelModelParameter angle="0.0" distance="30.0" distanceToCenter="true" position="right" ratio="0.5" segment="0"/>
            </y:ModelParameter>
            <y:PreferredPlacementDescriptor angle="0.0" angleOffsetOnRightSide="0" angleReference="absolute" angleRotationOnRightSide="co" distance="-1.0" frozen="true" placement="anywhere" side="anywhere" sideReference="relative_to_edge_flow"/>
          </y:EdgeLabel>
          <y:BendStyle smoothed="true"/>
        </y:PolyLineEdge>
      </data>
    </edge>
END

	return($text);
}

sub remove_duplicates() {
	my($i) = 0;
	my($j);
	print '-Removing duplicate routine calls...'."\n";
	while ($i < $#TASK_CALLS) {
		$j = $i+1;
		while ($j <= $#TASK_CALLS) {
			if (($TASK_CALLS[$i][0] eq $TASK_CALLS[$j][0])
				&& ($TASK_CALLS[$i][1] eq $TASK_CALLS[$j][1])
				&& ($TASK_CALLS[$i][2] eq $TASK_CALLS[$j][2])
				&& ($TASK_CALLS[$i][3] eq $TASK_CALLS[$j][3])) {
				# Identical, splice $j entry
				
				splice(@TASK_CALLS,$j,1);
			} else {
				$j++;
			}			
		}
		$i++;
	}
}

sub FileReadLine {
	my($HANDLE,$alt) = @_;
	my($line);

	if ($alt) {
		$line = $alt;
	} elsif ($line = <$HANDLE>) {
		$FILELINE++;
	} else {
		return '';
	}
		
	# Clear trailing comments
	$line =~ s/(.*?(\".*?;.*?\")*.*?;)(.*?!.*)/$1/;
	# Clear prefix or suffix junk
	$line =~ s/(^[\s\t]*|[\s\t\n\r]*$)//gi;
	# Clear all double spaces
	$line =~ s/\s\s/\s/g;
	# Empty line? Just read the next one
	if ($line =~ /^[\s\t\n\r]*$/i) {
		return(FileReadLine($HANDLE));
	}
	# Comment? Read the next one
	if ($line =~ /^[\s\t]*\!/i) {
		return(FileReadLine($HANDLE));
	}
	
	# If multiline stitch together
	if ($line =~ /^[\s\t]*(MODULE|ENDMODULE|ENDPROC|ENDFUNC|ENDTRAP|RECORD|ENDRECORD|ENDIF|ENDWHILE|ENDFOR|(LOCAL\s)?TRAP|ERROR|ENDTEST|ELSE)/i) {
		# Not multiline
	} elsif ($line =~ /^[\s\t]*((LOCAL\s)?PROC|(LOCAL\s)?FUNC)/i) {
		# Should end with ')'
		if ($line !~ /\)$/i) {
			$line .= FileReadLine($HANDLE);
		}
	} elsif ($line =~ /^(CASE|DEFAULT)/i) {
		# Should end with ':'
		if ($line !~ /\:$/) {
			$line .= FileReadLine($HANDLE);
		}
	} elsif ($line =~ /^(WHILE|FOR)/i) {
		# Should end with 'DO'
		if ($line !~ /DO$/i) {
			$line .= FileReadLine($HANDLE);
		}
	} elsif ($line =~ /^IF/i) {
		# Should end with 'THEN' OR ';'
		if ($line !~ /(THEN|\;)$/i) {
			$line .= FileReadLine($HANDLE);
		}
	} else {
		# Should end with ';'
		if ($line !~ /\;$/i) {
			$line .= FileReadLine($HANDLE);
		}
	}

	return($line);	
}

sub read_taskinfo_calls {
	my($line,$line2,$line3,$i,$j,$callname);
	my($PROC_INFO_LOCAL) = '';
	my($PROC_INFO_TYPE) = '';
	my($PROC_INFO_NAME) = '';
	my($calls_i) = 0;
	my($nextline) = '';
	my($nextline2) = '';
	
	print '-Reading task modules, finding subroutine-calls'."\n";
	
	open(LATE,'>LateBinds.log');

	foreach $i (0..$#TASK_INFO) {
		
		print '  '.$TASK_INFO[$i][0].'-'.$TASK_INFO[$i][1]."\n";
		foreach $j (0..$#{$TASK_MODS[$i]}) {
			print '    '.$TASK_MODS[$i][$j]."\n";
			open($MOD,'<'.$BAK_FOLDER.'/RAPID/'.$TASK_INFO[$i][0].'/'.$TASK_MODS[$i][$j]) or die('Cant open ['.$BAK_FOLDER.'/RAPID/'.$TASK_INFO[$i][0].'/'.$TASK_MODS[$i][$j].']');
			$FILELINE = 0;
			$line = FileReadLine($MOD);
			while ($line) {
				
				$nextline = '';
				
				# Start of a routine?
				if ($line =~ /^((LOCAL)\s+)?(PROC|FUNC\s+[\w\d_]+|TRAP)\s+([\w\d_]+)/i) {
					$PROC_INFO_LOCAL = $2;
					$PROC_INFO_TYPE = $3;
					$PROC_INFO_NAME = $4;

				# End of a routine
				} elsif ($line =~ /^(ENDPROC|ENDFUNC|ENDTRAP|ERROR|UNDO)/i) {
					$PROC_INFO_LOCAL = '';
					$PROC_INFO_TYPE = '';
					$PROC_INFO_NAME = '';

				# In a routine?
				} elsif ($PROC_INFO_NAME) {
					
					# Remove any COMPACT IF
					if ($line =~ /^IF\s/i) {
						if ($line =~ /THEN$/i) {
						} else {
						
							$line =~ s/\s*([\,\+\-\=\:\\\/\*])\s*/$1/g;

							# Backtrack from string-end until we find space-char outside parenthesis brackets and outside string-brackets
							$location_var = length($line);
							$parenthesis = 0;
							$string_ = 0;
							while ($location_var>0) {
								if ($string_ == 1) {
									if (substr($line,($location_var),1) eq '"') {
										$string_=0;
									}
									$location_var--;
								} else {
									if (substr($line,($location_var),1) eq '"') {
										$string_=1;
										$location_var--;
									} elsif (substr($line,($location_var),1) eq ')') {
										$parenthesis++;
										$location_var--;
									} elsif (substr($line,($location_var),1) eq '(') {
										$parenthesis--;
										$location_var--;
									} else {
										if (($parenthesis <= 0) && (substr($line,($location_var-1),2) =~ /\s\w/)) {
											last;
										}
										$location_var--;
									}
								}
							}
							# This MAY be correct, but the true instruction may also be earlier, so we look for \s[\w\d]+\s
							$location_var2 = $location_var-2;
							while ($location_var2>0) {
								if (substr($line,($location_var2),1) =~ /[\w\d]/) {
									# All ok
								} else {
									# Not instruction, break loop and we keep $location_var
									last;
								}
								if (substr($line,($location_var2-1),2) =~ /\s\w/) {
									# True instruction, update $location_var and break loop
									$location_var = $location_var2;
									last;
								}
								$location_var2--;
							}
							if ($location_var2 == 0) {
								$location_var = $location_var2;
							}
							$line = substr($line,$location_var,length($line)-$location_var);
						
						}					
					}
					

					# Routine Call Late binding
					if ($line =~ /^\%(.+)\%/) {
						$call_var = $1;
						
						$nextline = <$MOD>;
						if ($call_var =~ /^"([^"]*)"$/) {

							#print '[Looks like pure string]'."\n";
							# TASKn
							$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
							# Module
							$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
							# Routine from
							$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
							# Routine name
							$call_var =~ s/(^"|"$)//g;
							$TASK_CALLS[$calls_i][3] = $call_var;
							
							print '      Late binding: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
							print LATE 'Line '.$FILELINE.':'.$TASK_CALLS[$calls_i][0].'/'.$TASK_CALLS[$calls_i][1]."\n";
							$calls_i++;
							
						} else {

							print '[Probably VAR dependency]'."\n";

							if ($nextline =~ /!\s*Rapid2Graph\s*\[(.*)\]/) {
								$nextline2 = $1;
								$nextline2 =~ s/\s//g;
								foreach $latecall (split(/,/,$nextline2)) {
									# TASKn
									$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
									# Module
									$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
									# Routine from
									$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
									# Routine name
									$TASK_CALLS[$calls_i][3] = $latecall;
									print '      Late binding: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
									$calls_i++;
								}
								
							} else {
								#print '[No match on comment]'."\n";
								# TASKn
								$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
								# Module
								$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
								# Routine from
								$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
								# Routine name
								$TASK_CALLS[$calls_i][3] = '[string '.$1.']';
								
								print '      Late binding: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
								print LATE 'Line '.$FILELINE.':'.$TASK_CALLS[$calls_i][0].'/'.$TASK_CALLS[$calls_i][1]."\n";
								$calls_i++;
							}							

						}
						
					# Routine CallByVar
					} elsif ($line =~ /^CallByVar\s+([\w\d_\"+]+\s*,\s*\s*[\w\d_]+)/i) {
						$call_var = $1;
						$call_var =~ s/\s//g;

						$nextline = <$MOD>;
						
						if ($nextline =~ /!\s*Rapid2Graph\s*\[(.*)\]/) {
							$nextline2 = $1;
							$nextline2 =~ s/\s//g;
							foreach $latecall (split(/,/,$nextline2)) {
								# TASKn
								$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
								# Module
								$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
								# Routine from
								$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
								# Routine name
								$TASK_CALLS[$calls_i][3] = $latecall;
								print '      CallByVar: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
								$calls_i++;
							}
						} else {
							# TASKn
							$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
							# Module
							$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
							# Routine from
							$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
							# Routine name
							$TASK_CALLS[$calls_i][3] = '[string '.$call_var.']';
							print '      CallByVar: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
							print LATE 'Line '.$FILELINE.':'.$TASK_CALLS[$calls_i][0].'/'.$TASK_CALLS[$calls_i][1]."\n";
							$calls_i++;
						}

					# Routine MoveJ/LSync
					} elsif ($line =~ /^Move(J|L)Sync.*?([\w\d_\"]+)\s*;$/i) {
						$call_var = $2;
						
						if ($call_var =~ /^"(.*?".*)"$/) {
							
							# TASKn
							$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
							# Module
							$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
							# Routine from
							$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
							# Routine name
							$TASK_CALLS[$calls_i][3] = $call_var;
							
							print '      MoveXSync: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
							$calls_i++;

						} else {
							# TASKn
							$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
							# Module
							$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
							# Routine from
							$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
							# Routine name
							$call_var =~ s/(^"|"$)//g;
							$TASK_CALLS[$calls_i][3] = $call_var;
							print '      MoveXSync: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
							$calls_i++;

						}

					# Interrupt
					} elsif ($line =~ /^CONNECT.*?([\w\d_]+)\s*;$/i) {
						# TASKn
						$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
						# Module
						$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
						# Routine from
						$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
						# Routine name
						$TASK_CALLS[$calls_i][3] = $1;
						print '      TRAP: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
						$calls_i++;
					
					}

					# Function-call, separate IF, since it can trigger even though something else triggers
					if ($line =~ /(([\w\d_]+)\s*\()/i) {
						
						# Remove strings, to be sure no callregexps are triggered.
						$line =~ s/"[^"]*"/""/g;
						
						while ($line =~ /(([\w\d_]+)\s*\()/i) {

							$callname = $2;
							$func_to_be_removed = $1;
							
							if (CallInScope($TASK_INFO[$i][0],$TASK_MODS[$i][$j],$callname)) {

								#print '['.$line.']['.$callname.']['.$func_to_be_removed.']'."\n";

								# TASKn
								$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
								# Module
								$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
								# Routine from
								$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
								# Routine name
								$TASK_CALLS[$calls_i][3] = $callname;
								print '      FUNC: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
								$calls_i++;
							}							
							
							# Remove entry and retry, so all functioncalls are picked up
							$line =~ s/\Q$func_to_be_removed\E/DummyFunc/gi;
						}
						
					}

					# Once everything else has been checked, we can see if its a regular routine-call
					if ($line =~ /(^[\w\d]+)\s?(\:\=)?/i) {
						$callname = $1;
						$temp = $2;
						if ($temp eq ':=') {
							# Variable setting, nop
						} else {
							if (CallInScope($TASK_INFO[$i][0],$TASK_MODS[$i][$j],$callname)) {
								# TASKn
								$TASK_CALLS[$calls_i][0] = $TASK_INFO[$i][0];
								# Module
								$TASK_CALLS[$calls_i][1] = $TASK_MODS[$i][$j];
								# Routine from
								$TASK_CALLS[$calls_i][2] = $PROC_INFO_NAME;
								# Routine name
								$TASK_CALLS[$calls_i][3] = $callname;
								print '      PROC: '.$TASK_CALLS[$calls_i][0].','.$TASK_CALLS[$calls_i][1].','.$TASK_CALLS[$calls_i][2],',',$TASK_CALLS[$calls_i][3]."\n";
								$calls_i++;
							}
						}
					}

				}
				
				if ($nextline ne '') {
					$line = FileReadLine($MOD,$nextline);
				} else {
					$line = FileReadLine($MOD);
				}
			}
			close($MOD);
		}
		
	}
	close(LATE);
}

sub CallInScope {
	my($task,$module,$routine) = @_;
	foreach $i (0..$#TASK_ROUTINES) {
		if (($task eq $TASK_ROUTINES[$i][0]) && ($routine eq $TASK_ROUTINES[$i][2])) {
			if ($TASK_ROUTINES[$i][4] eq 'LOCAL') {
				if ($module eq $TASK_ROUTINES[$i][1]) {
					return 1;
				} else {
					return 0;
				}
			} else {
				return 1;
			}
		}
	}
	return 0;
}

sub read_taskinfo {
	my($line,$line2,$line3,$i,$j);
	my($PROC_INFO_LOCAL) = '';
	my($PROC_INFO_TYPE) = '';
	my($PROC_INFO_NAME) = '';
	my($procs_i) = 0;

	print '-Reading task modules, finding all routines...'."\n";

	foreach $i (0..$#TASK_INFO) {
		
		print '  '.$TASK_INFO[$i][0].'-'.$TASK_INFO[$i][1]."\n";
		foreach $j (0..$#{$TASK_MODS[$i]}) {
			print '    '.$TASK_MODS[$i][$j]."\n";
			open($MOD,'<'.$BAK_FOLDER.'/RAPID/'.$TASK_INFO[$i][0].'/'.$TASK_MODS[$i][$j]) or die('Cant open ['.$BAK_FOLDER.'/RAPID/'.$TASK_INFO[$i][0].'/'.$TASK_MODS[$i][$j].']');
			while ($line = FileReadLine($MOD)) {
				
				# Start of a routine?
				if ($line =~ /^((LOCAL)\s+)?(PROC|FUNC\s+[\w\d_]+|TRAP)\s+([\w\d_æøå]+)/i) {
					$PROC_INFO_LOCAL = $2;
					$PROC_INFO_TYPE = $3;
					$PROC_INFO_NAME = $4;
					print '      ';
					if ($PROC_INFO_LOCAL) {
						print $PROC_INFO_LOCAL.' ';
					}
					print $PROC_INFO_TYPE.' '.$PROC_INFO_NAME."\n";
					
					# TASKn
					$TASK_ROUTINES[$procs_i][0] = $TASK_INFO[$i][0];
					# Module
					$TASK_ROUTINES[$procs_i][1] = $TASK_MODS[$i][$j];
					# Routine name
					$TASK_ROUTINES[$procs_i][2] = $PROC_INFO_NAME;
					# Routine type
					$TASK_ROUTINES[$procs_i][3] = $PROC_INFO_TYPE;
					# Routine local
					$TASK_ROUTINES[$procs_i][4] = $PROC_INFO_LOCAL;
					
					print PROCS $procs_i.', '.$TASK_ROUTINES[$procs_i][2].', '.$TASK_ROUTINES[$procs_i][3].', '.$TASK_ROUTINES[$procs_i][4].', '.$TASK_ROUTINES[$procs_i][1].', '.$TASK_ROUTINES[$procs_i][0]."\n";

					$procs_i++;
					
				}
			}
			close($MOD);
			#exit;
		}
		
	}
	print 'done'."\n";
}

sub read_bakinfo {
	
	# Will read backupinfo into arrays
	
	# @BAK_INFO[]
	# RobotID
	# Robotware
	
	# @TASK_INFO[][]
	# TaskID,TaskName
	
	my($line,$line2,$task_mods_i);
	my($task_i) = 0;
	print '-Reading BACKINFO.TXT'."\n";
	
	open(BAK,'<'.$BAK_FOLDER.'/BACKINFO/backinfo.txt') or die('Cant open ['.$BAK_FOLDER.'/BACKINFO/backinfo.txt]');
	while ($line = <BAK>) {
		chop($line);
		
		if ($line =~  /SYSTEM_ID:/) {
			$line2 = <BAK>;
			chop($line2);
			$BAK_INFO[0] = $line2;
			print '  ROB_ID: '.$BAK_INFO[0]."\n";
			
		} elsif ($line =~ /PRODUCTS_ID:/) {
			$line2 = <BAK>;
			chop($line2);
			$BAK_INFO[1] = $line2;
			print '  ROB_RW: '.$BAK_INFO[1]."\n";
			
		} elsif ($line =~ /^\>\>(TASK\d+)\:\s\(([\w\d_]*),/) {
			# TASKn
			$TASK_INFO[$task_i][0] = $1;
			
			# Name
			$TASK_INFO[$task_i][1] = $2;
			
			print '  '.$TASK_INFO[$task_i][0].'/'.$TASK_INFO[$task_i][1]."\n";
			
			# Task-modules
			$task_mods_i = 0;
			while ($line2 = <BAK>) {

				if ($line2 =~ /(^[\w\d\/\\\._]+)/) {
					$TASK_MODS[$task_i][$task_mods_i] = $1;
					print '    ['.$TASK_MODS[$task_i][$task_mods_i].']'."\n";
					$task_mods_i++;
					
				} else {
					last;
					
				}
			}
			
			$task_i++;
			
		}			
			
	}
	close(BAK);	
}

sub find_most_recent_bak {
	my($bak_most_recent_time) = 0;
	my($de,$line);
	
	opendir(DIR,'.');
	foreach $de (readdir(DIR)) {
		if (-d './'.$de) {
			if (-e './'.$de.'/BACKINFO/backinfo.txt') {
				open(FILE,'<./'.$de.'/BACKINFO/backinfo.txt');
				while ($line = <FILE>) {
					if ($line =~ /^\#\s+(\d{2,4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
						$bak_time = timelocal($6,$5,$4,$3,($2 - 1),$1);
						if ($bak_time > $bak_most_recent_time) {
							$bak_most_recent_time = $bak_time;
							$BAK_FOLDER = './'.$de;
						}
						last;
					}
				}
				close(FILE);
			}
		}
	}
	closedir(DIR);
	
	if ($bak_most_recent_time <= 0) {
		print "\n\n".'ERROR, found no valid backup...'."\n\n";
		sleep(3);
		exit;
	}
	
}
















