
# Rapid2Graph

## Overview

Rapid2Graph is a tool for parsing ABB Robot backup files and generating execution charts in the **yEd** ``.graphml`` format. It visualizes the relationships between procedures, functions, and traps within ABB RAPID code, grouping them into Module Groups and Task Groups for clarity. Methods (``PROC``, ``FUNC``, ``TRAP``) are color-coded for easier analysis.

### Key Benefits

* **Educational** – Helps new engineers understand program structure.

* **Testing** – Provides a visual representation of procedure calls within the program.

* **Code Cleanup** – Identifies and highlights unused code, aiding in codebase optimization.

### Example Output

![2025-01-24-2](https://github.com/user-attachments/assets/bcfcdf64-6b5c-4581-9c90-f8c5c4f124eb)

## yEd Software Benefits

* Automatic layout generation

* Navigation via the main graph or structured lists (Task, Module, Method)

## Usage

1. Copy the controller backup into the same directory as the script.

2. Run the script.

3. Open the generated ``.graphml`` files in **yEd**.

4. Arrange the chart using **Layer → Hierarchical** or another suitable layout.

   * For fast and great result, use **BPMN-Layout** with a Left-to-Right style.

## Prerequisites

* **Perl**: [strawberryperl.com](https://strawberryperl.com/)

* **yEd Graph Editor**: [www.yworks.com/products/yed](https://www.yworks.com/products/yed)

## Additional Information

### Late-Bound Calls

The script does not automatically resolve **late-bound** procedure calls. However, you can define valid calls manually by adding a comment after the late binding statement.

Example:
```
! Late binding
%"Procedure"+NumToStr(giPlcCommand)%;

! Comment for script interpretation:
! Rapid2Graph [Procedure1000, Procedure2000, Procedure3000, Procedure4000]
```

Refer to the log files for details on detected procedures and calls:

* **TaskProcs.log** – Found procedures

* **TaskCalls.log** – Procedure call references

### Excluding Code Sections

To exclude specific sections of RAPID code from the ``.graphml`` output, insert the following comment anywhere in a program or system module. Any code **after** this line in the same module will be ignored.

```
! Rapid2Graph Ignore
```

For any issues or feature requests, feel free to contribute or open an issue in the repository.

