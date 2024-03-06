#! python3
import concurrent.futures
import subprocess
import json
import re

def brew_verify_command(formula_name):
    return ['brew', 'verify', formula_name]

# Define a function to run a subprocess
def run_subprocess(command):
    """Run the given command as a subprocess."""
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return (command[-1], result)

def is_unverified(formula):
    result = subprocess.run(['brew', 'verify', formula["name"]], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    # print(result.stdout)
    return result.returncode != 0 

def get_unverified_tarballs(formula):
    result = subprocess.run(['brew', 'verify', formula["name"]], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        tags = formula["bottles"].keys()
        cache_paths = []
        for tag in tags:
            tag_result = subprocess.run(['brew', 'verify', formula["name"], "--bottle-tag", tag], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) 
            if tag_result.returncode != 0:
                tar_gz_pattern = r'/[^\s]+\.tar\.gz'
                paths = re.findall(tar_gz_pattern, tag_result.stdout)
                if len(paths) > 0:
                    cache_paths.append(paths[0])
        return cache_paths
    return []

def get_all_unverified_bottles():
    with open("homebrew_formulae.json") as f:
        formulae = json.load(f)
        num_verified = 0
        commands = [brew_verify_command(f["name"]) for f in formulae]
        unverified = []
        with concurrent.futures.ProcessPoolExecutor() as executor:
            # Map each command to the executor
            future_to_command = {executor.submit(run_subprocess, cmd): cmd for cmd in commands}

            # Retrieve and print the results as they are completed
            for future in concurrent.futures.as_completed(future_to_command):
                command = future_to_command[future]
                try:
                    name, result = future.result()
                    if result.returncode != 0:
                        print(name)
                        unverified.append((name, result))
                except Exception as exc:
                    print(f'{command} generated an exception: {exc}')

        s = set(unverified)
        unverified_formula = [formula for formula in formulae if formula["name"] in s]
        with open("unverified_formulae.json", 'w') as json_file:
            json.dump(unverified_formula, json_file)

def filter_json():
    with open("homebrew_formulae.json") as f:
        formulae = json.load(f) 
        with open("unverified.txt") as unv:

            unverified = set((line.strip() for line in unv.readlines()))
            filtered = [formula for formula in formulae if formula["name"] in unverified]
            with open("unverified_formulae.json", "w") as out:
                json.dump(filtered, out) 
            print(f"total formulae: {len(formulae)}")
            print(f"unsigned formulae: {len(filtered)}")


if __name__ == "__main__":
    # get_all_unverified_bottles()
    filter_json()