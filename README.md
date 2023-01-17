# Rapid_ExecChart

# Abstract

Read ABB Robot backup. Generate an execution chart parsed into yEd format .graphml .

# Usage

Copy the controller backup into the same folder as the script. Run the script.

# Prerequisites

https://strawberryperl.com/

# More info

The script cannot interpret late binding procedure calls. You can however define valid calls by inserting a comment after late bindings

Example:
```
! Late binding
%"Procedure"+NumToStr(giPlcCommand)%;

! Comment for this script to interpret:
! Rapid2Graph [Procedure1000,Procedure2000,Procedure3000,Procedure4000]
```

# Shortcomings

Consider this script as work in progress and quite a big mess. However as a proof of concept it works.

The biggest issue is CompactIf instructions. Egde cases will probably not be interpreted correctly. Currently CompactIf will be interpreted as follows, which works well in most cases.

```
! Line starting with IF.
IF CodeLine =~ /^IF/

  ! Line does not end with THEN.
  IF CodeLine !~ /THEN$/
  
    ! Remove spaces before and after operators.
    CodeLine =~ s/\s*([\,\+\-\=\:\\\/\*])\s*/$1/g;
    
      ! Backtrack from string-end, find space char outside parenthesis and outside string brackets.
      ProcCall = SubStr(CodeLine,RevSearchSpace(CodeLine));
      
        ! This MAY be incorrect in edge cases, so we backtrack further to see if we find /\s[\w\d]+\s/
        ProcCall = SubStr(CodeLine,RevSearchWord(CodeLine));
```
