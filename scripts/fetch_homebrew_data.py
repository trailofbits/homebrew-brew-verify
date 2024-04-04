#! python3
import subprocess
import json
import re

def get_formulae_list():
    result = subprocess.run(['brew', 'formulae'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.stderr:
        raise Exception(f"Error getting formulae list: {result.stderr}")
    return result.stdout.splitlines()

def get_formulae_data(formulae):
    if len(formulae) == 0:
        raise ValueError("Formula name is empty or invalid.")
    formulae = [f for f in formulae if len(f) > 0]
    command = ['brew', 'info', '--json', '--variations'] + formulae
    formula_data = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if formula_data.stderr:
        raise Exception(f"Error getting formula data for forumlae: {formula_data.stderr}")
    return formula_data.stdout

def extract_data(formula_content):
    data = json.loads(formula_content)
    output = []
    for formula in data:
        if formula['tap'] != 'homebrew/core':
            next
        entry = {'name': formula['full_name']}
        if 'bottle' in formula and 'stable' in formula['bottle']:
            if 'files' in formula['bottle']['stable']:
                files = formula['bottle']['stable']['files']
                entry['bottles'] = files
                output.append(entry)
    return output

def main():
    formulae = get_formulae_list()
    with open('homebrew_formulae.json', 'w') as f:
        try:
            print(f"Processing {len(formulae)} formulae...")
            content = get_formulae_data(formulae)
            data = extract_data(content)
            f.write(json.dumps(data)) 
            print(f"Succesfully got bottle data for {len(data)} formulae.")
        except Exception as e:
            print(f"Error processing formulae: {e}")

if __name__ == "__main__":
    main()
