import subprocess
import json
import re

def get_formulae_list():
    result = subprocess.run(['brew', 'formulae'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.stderr:
        raise Exception(f"Error getting formulae list: {result.stderr}")
    return result.stdout.splitlines()

# TODO(joesweeney): This should take in all the formulae.
def get_formula_data(formula):
    if not formula:
        raise ValueError("Formula name is empty or invalid.")
    formula_data = subprocess.run(['brew', 'info', '--json', '--variations', formula], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if formula_data.stderr:
        raise Exception(f"Error getting formula data for {formula}: {formula_data.stderr}")
    return formula_data.stdout

def extract_data(formula_content):
    data = json.loads(formula_content)
    assert(len(data) == 1)
    formula = data[0]
    output = {'name': formula['full_name']}
    # print(formula['bottle']['stable']['files'])
    # TODO(joesweeney): Check it is in homebrew core.
    if 'bottle' in formula and 'stable' in formula['bottle']:
        if 'files' in formula['bottle']['stable']:
            files = formula['bottle']['stable']['files']
            output['bottles'] = files
    return output

# TODO(joesweeney): Speed!
def main():
    formulae = get_formulae_list()
    with open('homebrew_formulae.jsonl', 'w') as f:
        for formula in formulae:
            try:
                print(f"Processing {formula}...")
                content = get_formula_data(formula)
                data = extract_data(content)
                data['name'] = formula
                f.write(json.dumps(data) + '\n')  # Write each formula's data as a new line in JSONL format
            except Exception as e:
                print(f"Error processing {formula}: {e}")

if __name__ == "__main__":
    main()
