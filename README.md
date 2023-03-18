# Race of Focus
Based on [this](https://docs.google.com/presentation/d/11E9kX1oVYfMooTdD1GAJfwJtdPIQpYB3lJ7i5e83ZEw/edit#slide=id.g12d57307ead_0_0) slide. Determines the race the ad focuses on based on which candidates are mentioned. Requires entity linking data, as well as candidate and WMP entity file.

## Usage
Run the script `race_of_focus_140m.R`

## Requirements
The script uses R (4.2.2). The packages we used are described in `requirements_r.txt`.

## To-do
Remove 1.18m, merge text-only into main file as an argument.
