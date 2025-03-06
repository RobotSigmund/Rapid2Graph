# Rapid2Graph

# Abstract

Read ABB Robot backup. Generate an execution chart parsed into yEd format .graphml . Procedures and functions are grouped into module-groups. Module-groups are grouped into Task-groups. PROC/FUNC/TRAP methods are colour coded.

Advantages:

* Educational. Sharing knowledge with new engineers.
* Testing. Visually highlighting for all parts of the program which calls any part other part.
* Cleanup. Minimalizes the codebase by highlighting unused code.

Example output:  
![2025-01-24-2](https://github.com/user-attachments/assets/bcfcdf64-6b5c-4581-9c90-f8c5c4f124eb)

yEd software specific advantages:

* Automatic layout
* Navigation by main graph or Task/Module/Method list.


# Usage

Copy the controller backup into the same folder as the script. Run the script.

Open .graphml files in yEd. Arrange chart by selecting Layer->Hierarchical or any other suitable layout style.

# Prerequisites

[strawberryperl.com](https://strawberryperl.com/)

[www.yworks.com/products/yed](https://www.yworks.com/products/yed)


# More info

### Late bind calls

The script cannot interpret late binding procedure calls. You can however define valid calls by inserting a comment after late bindings

Example:
```
! Late binding
%"Procedure"+NumToStr(giPlcCommand)%;

! Comment for this script to interpret:
! Rapid2Graph [Procedure1000,Procedure2000,Procedure3000,Procedure4000]
```

Check logfiles for found procedures (TaskProcs.log) and procedurecalls (TaskProcs.log).

### Exclude parts of the rapid code

Insert the following line anywhere in any program/system module and the remaining parts of that module will not be included into the resulting .graphml file.

```
! Rapid2Graph Ignore
```


