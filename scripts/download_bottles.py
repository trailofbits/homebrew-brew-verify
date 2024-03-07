import argparse
import os
import subprocess
import re

def main(args):
    try:
        with open(args.line_state_file) as line_state:
            start_line = int(line_state.readline().strip())
    except FileNotFoundError:
        start_line = 0
    end_line = start_line + args.num_lines
    
    with open(args.bottle_tag_file, "r") as file:
        lines = file.readlines()[start_line:end_line]  # Adjust for zero-based indexing
    
    successful = 0
    containing_folder = None
    for line in lines:
        arg1, arg2 = line.strip().split()  # Assuming each line has exactly two arguments
        cmd = f"brew verify {arg1} --bottle-tag {arg2}"
        
        try:
            result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
            matches = re.findall(r'\S+\.tar\.gz', result.stdout)
            if matches:
                successful += 1
                folder = os.path.dirname(matches[0])
                if containing_folder is None:
                    containing_folder = folder
                # print(matches[0])
        except subprocess.CalledProcessError:
            pass
    if containing_folder is not None:
        print(f"artifact_path={containing_folder}/*.tar.gz")
    with open(args.line_state_file, 'w+') as line_state:
        if successful > 0:
            line_state.write(f"{end_line}")
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract .tar.gz paths from command output.")
    parser.add_argument("--line_state_file", type=str, default="scripts/line_number.txt", help="The file to read the starting line from and write the new ending line.")
    parser.add_argument("--num_lines", type=int, default=10, help="The number of lines to process.")
    parser.add_argument("--bottle_tag_file", type=str, default="scripts/tags_to_sign.txt", help="The file to read the bottles and tags from.")
    
    args = parser.parse_args()
    
    main(args)
