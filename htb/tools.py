# This script will 
# 1. Tools Installation:
# - The script will git clone the provided repositories into the tools directory.
# 2. Initial Nmap Scan:
# - The script will run an initial Nmap scan on the provided machine IP to determine open ports.
# - If the machine type was not provided by the user, the script will attempt to determine it from the Nmap scan results.

import os
import subprocess

# ... [Previous functions: get_user_input and setup_directory_structure]

def install_tools(base_dir):
    """Git clone the necessary tools into the tools directory."""
    tools_dir = os.path.join(base_dir, "tools")
    repos = [
        "https://github.com/carlospolop/PEASS-ng",
        "https://github.com/danielmiessler/SecLists",
        "https://github.com/cywf/aliases"
    ]
    
    for repo in repos:
        subprocess.run(["git", "clone", repo], cwd=tools_dir)

def initial_nmap_scan(machine_ip, base_dir):
    """Run an initial Nmap scan to determine open ports."""
    nmap_dir = os.path.join(base_dir, "nmap")
    output_file = os.path.join(nmap_dir, "initial_scan.txt")
    
    # Run the Nmap scan
    subprocess.run(["nmap", "-sC", "-sV", "-oN", output_file, machine_ip])

    # Parse the results to determine the machine type (if not provided)
    machine_type = "Unknown"
    with open(output_file, "r") as file:
        for line in file:
            if "Windows" in line:
                machine_type = "Windows"
                break
            elif "Linux" in line:
                machine_type = "Linux"
                break

    return machine_type

def main():
    handle, machine_name, machine_ip, machine_type = get_user_input()
    base_dir = setup_directory_structure(machine_name)
    print(f"Directory structure set up at: {base_dir}")

    install_tools(base_dir)
    print("Tools installed.")

    if not machine_type:
        machine_type = initial_nmap_scan(machine_ip, base_dir)
        print(f"Machine type determined as: {machine_type}")
    else:
        print(f"Machine type provided as: {machine_type}")

if __name__ == "__main__":
    main()
